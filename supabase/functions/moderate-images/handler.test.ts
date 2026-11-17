import { handler, type Claim } from "./handler.ts";
import { safeSearchVerdict, visionScreener } from "./provider.ts";
function assert(value: unknown, message = "assertion failed"): asserts value { if (!value) throw Error(message); }
const uuid = () => crypto.randomUUID();
const item = (): Claim => ({ objectID: uuid(), generation: uuid(), leaseID: uuid(), bucket: "social-photos", path: uuid() + "/" + uuid() + ".jpg", bytes: 4 });
const jpeg = new Uint8Array([255, 216, 255, 217]);
function fixture(options: { configured?: boolean; authorized?: boolean; outcome?: "approved" | "review" | "rejected" | "unavailable"; claims?: Claim[]; bytes?: Uint8Array; failFinish?: boolean } = {}) {
  const seen: { claims: number; downloads: number; calls: number; finishes: unknown[] } = { claims: 0, downloads: 0, calls: 0, finishes: [] };
  return {
    seen,
    run: handler({
      configured: options.configured ?? true,
      authorize: async token => token === "worker-fixture" && (options.authorized ?? true),
      claim: async () => { seen.claims++; return options.claims ?? [item()]; },
      download: async () => { seen.downloads++; return options.bytes ?? jpeg; },
      finish: async (claim, outcome, hash) => { if (options.failFinish) throw Error("private credentials"); seen.finishes.push({ claim, outcome, hash }); return true; },
      screener: { screen: async () => { seen.calls++; return options.outcome ?? "approved"; } },
    }),
  };
}
const request = (token = "worker-fixture", method = "POST", body?: string) =>
 new Request("https://fixture/moderate-images", { method, headers: { authorization: "Bearer " + token }, ...(body ? { body } : {}) });

Deno.test("worker accepts only server authorization and empty POST", async () => {
  for (const req of [new Request("https://fixture"), request("user-fixture")]) {
    const f = fixture(); assert((await f.run(req)).status === 401 && f.seen.claims === 0);
  }
  for (const req of [request("worker-fixture", "GET"), request("worker-fixture", "POST", "{}")]) {
    const f = fixture(); assert([400, 405].includes((await f.run(req)).status) && f.seen.claims === 0);
  }
});
Deno.test("an empty transmitted body is accepted without caller-selected options", async () => {
  const f = fixture({ claims: [] });
  const req = new Request("https://fixture", { method: "POST", headers: { authorization: "Bearer worker-fixture" }, body: "" });
  assert((await f.run(req)).status === 200);
});
Deno.test("disabled provider leaves database work unclaimed", async () => {
  const f = fixture({ configured: false }); assert((await f.run(request())).status === 503 && !f.seen.claims);
});
Deno.test("unknown or private cooking paths never reach downloader", async () => {
  const bad = [
    { ...item(), bucket: "cooking-photos" }, { ...item(), path: "../private.jpg" },
    { ...item(), bytes: 2097153 }, { ...item(), generation: "not-a-uuid" },
  ];
  for (const claim of bad) {
    const f = fixture({ claims: [claim as Claim] });
    assert((await f.run(request())).status === 503 && !f.seen.downloads);
  }
});
Deno.test("bounded worker hashes exact original bytes and stores one verdict", async () => {
  const f = fixture(); assert((await f.run(request())).status === 200 && f.seen.calls === 1);
  const final = f.seen.finishes[0] as { hash: string; outcome: string };
  assert(final.hash.length === 64 && final.outcome === "approved");
});
Deno.test("provider uncertainty and rejection remain distinct", async () => {
  for (const outcome of ["review", "rejected"] as const) {
    const f = fixture({ outcome }); assert((await f.run(request())).status === 200);
    assert((f.seen.finishes[0] as { outcome: string }).outcome === outcome);
  }
});
Deno.test("quota cooldown stops batch with no retry or remaining downloads", async () => {
  const f = fixture({ outcome: "unavailable", claims: [item(), item(), item()] });
  assert((await f.run(request())).status === 503 && f.seen.calls === 1 && f.seen.downloads === 1);
});
Deno.test("corrupt or wrong-length image never reaches provider", async () => {
  for (const bytes of [new Uint8Array(4), new Uint8Array([255, 216])]) {
    const f = fixture({ bytes }); assert((await f.run(request())).status === 503 && !f.seen.calls);
  }
});
Deno.test("database failure never echoes credentials or image content", async () => {
  const f = fixture({ failFinish: true }); const response = await f.run(request());
  assert(response.status === 503 && !(await response.text()).includes("private credentials"));
});
function annotation(adult: string, violence = "VERY_UNLIKELY", racy = "VERY_UNLIKELY") {
  return { responses: [{ safeSearchAnnotation: { adult, violence, racy, medical: "VERY_LIKELY", spoof: "VERY_LIKELY" } }] };
}
Deno.test("SafeSearch classifies supported labels and keeps unknowns for human review", () => {
  assert(safeSearchVerdict(annotation("VERY_UNLIKELY")) === "approved");
  assert(safeSearchVerdict(annotation("POSSIBLE")) === "review");
  assert(safeSearchVerdict(annotation("LIKELY")) === "rejected");
  assert(safeSearchVerdict(annotation("VERY_UNLIKELY", "VERY_LIKELY")) === "rejected");
  assert(safeSearchVerdict(annotation("VERY_UNLIKELY", "UNLIKELY", "LIKELY")) === "review");
  assert(safeSearchVerdict(annotation("UNKNOWN")) === "review");
  assert(safeSearchVerdict(null) === "unavailable");
  assert(safeSearchVerdict({ responses: [{ error: {} }] }) === "unavailable");
});
Deno.test("adapter uses only SafeSearch, protected header and inline transient JPEG", async () => {
  let calls = 0;
  const mock: typeof fetch = async (input, init) => {
    calls++;
    assert(String(input) === "https://vision.googleapis.com/v1/images:annotate");
    assert((init!.headers as Record<string, string>)["x-goog-api-key"] === "fixture-key");
    const body = JSON.parse(init!.body as string);
    assert(body.requests[0].features[0].type === "SAFE_SEARCH_DETECTION" && body.requests[0].image.content === btoa(String.fromCharCode(...jpeg)));
    assert(!String(init!.body).includes("imageUri"));
    return Response.json(annotation("UNLIKELY"));
  };
  assert(await visionScreener("fixture-key", mock).screen(jpeg) === "approved" && calls === 1);
});
Deno.test("adapter quota, invalid response, oversize and network fail closed", async () => {
  for (const send of [
    async () => new Response("private provider error", { status: 429 }),
    async () => new Response("invalid json"),
    async () => new Response("x".repeat(32001)),
    async () => { throw Error("private network error"); },
  ]) assert(await visionScreener("fixture-key", send).screen(jpeg) === "unavailable");
  let calls = 0;
  assert(await visionScreener("", async () => { calls++; return Response.json({}); }).screen(jpeg) === "unavailable" && calls === 0);
});
