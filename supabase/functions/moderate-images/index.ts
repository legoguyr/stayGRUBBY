import { handler, type Claim } from "./handler.ts";
import { manualScreener } from "./provider.ts";

const url = Deno.env.get("SUPABASE_URL") ?? "";
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

async function rpc(name: string, body: Record<string, unknown>) {
  const response = await fetch(url + "/rest/v1/rpc/" + name, {
    method: "POST",
    headers: { apikey: service, Authorization: "Bearer " + service, "Content-Profile": "api", "Content-Type": "application/json" },
    body: JSON.stringify(body), signal: AbortSignal.timeout(8_000), redirect: "error",
  });
  if (!response.ok) throw Error("operation_unavailable");
  return await response.json();
}

Deno.serve(handler({
  configured: Boolean(service && url),
  authorize: async token => {
    // JWT gateway verification remains required. Only the configured server
    // credential is accepted after it, never an ordinary signed user session.
    const expected = new TextEncoder().encode(service);
    const actual = new TextEncoder().encode(token);
    if (!service || actual.length !== expected.length) return false;
    let difference = 0;
    for (let i = 0; i < expected.length; i++) difference |= expected[i] ^ actual[i];
    return difference === 0;
  },
  claim: async () => await rpc("claim_image_reviews", {}),
  download: async (item: Claim) => {
    const response = await fetch(url + "/storage/v1/object/authenticated/" + item.bucket + "/" + item.path, {
      headers: { apikey: service, Authorization: "Bearer " + service },
      signal: AbortSignal.timeout(8_000), redirect: "error",
    });
    if (!response.ok) throw Error("image_unavailable");
    const reader = response.body?.getReader();
    if (!reader) throw Error("image_unavailable");
    const bytes = new Uint8Array(Number(item.bytes));
    let length = 0;
    try {
      while (true) {
        const part = await reader.read();
        if (part.done) break;
        if (length + part.value.length > bytes.length) { await reader.cancel(); throw Error("image_size"); }
        bytes.set(part.value, length); length += part.value.length;
      }
    } finally { reader.releaseLock(); }
    if (length !== bytes.length) throw Error("image_size");
    return bytes;
  },
  finish: async (item, outcome, hash) => await rpc("finish_image_review", {
    object_id: item.objectID, generation: item.generation, lease_id: item.leaseID, outcome, sha256: hash,
  }) === true,
  screener: manualScreener(),
}));
