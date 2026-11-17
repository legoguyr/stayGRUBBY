import type { ImageScreener, Verdict } from "./provider.ts";

export interface Claim {
  objectID: string;
  generation: string;
  leaseID: string;
  bucket: "social-photos" | "recipe-photos" | "profile-photos";
  path: string;
  bytes: number;
}
interface Dependencies {
  configured: boolean;
  authorize(token: string): Promise<boolean>;
  claim(): Promise<Claim[]>;
  download(item: Claim): Promise<Uint8Array>;
  finish(item: Claim, outcome: Verdict, hash: string | null): Promise<boolean>;
  screener: ImageScreener;
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
function validClaim(item: Claim): boolean {
  return [item.objectID, item.generation, item.leaseID].every(value => uuid.test(value))
    && ["social-photos", "recipe-photos", "profile-photos"].includes(item.bucket)
    && /^[0-9a-f-]{36}\/[0-9a-f-]{36}\.jpg$/.test(item.path)
    && Number.isInteger(Number(item.bytes)) && Number(item.bytes) > 0 && Number(item.bytes) <= 2_097_152;
}
const respond = (status: number, code: string, processed = 0) =>
  Response.json({ code, processed }, { status, headers: { "Cache-Control": "no-store" } });

export function handler(d: Dependencies) {
  return async (request: Request): Promise<Response> => {
    const token = request.headers.get("authorization")?.match(/^Bearer (\S+)$/i)?.[1];
    try {
      if (!token || !await d.authorize(token)) return respond(401, "authentication_required");
      if (request.method !== "POST") return respond(405, "method_not_allowed");
      // The scheduler sends an empty POST. Callers cannot select images, accounts
      // or provider options and cannot use the worker as a private-photo proxy.
      if (request.body !== null) {
        const reader = request.body.getReader();
        try {
          let ended = false;
          for (let emptyChunks = 0; emptyChunks < 4; emptyChunks++) {
            const part = await reader.read();
            if (part.done) { ended = true; break; }
            if (part.value.length) { await reader.cancel(); return respond(400, "invalid_request"); }
          }
          if (!ended) { await reader.cancel(); return respond(400, "invalid_request"); }
        } finally { reader.releaseLock(); }
      }
      if (!d.configured) return respond(503, "screening_unavailable");
      const claims = await d.claim();
      if (!Array.isArray(claims) || claims.length > 5 || claims.some(item => !validClaim(item))) {
        return respond(503, "invalid_work");
      }
      let processed = 0;
      for (const item of claims) {
        let hash: string | null = null;
        let outcome: Verdict = "unavailable";
        try {
          const bytes = await d.download(item);
          if (bytes.length !== Number(item.bytes) || bytes[0] !== 0xff || bytes[1] !== 0xd8) throw Error("invalid_image");
          hash = [...new Uint8Array(await crypto.subtle.digest("SHA-256", new Uint8Array(bytes)))].map(x => x.toString(16).padStart(2, "0")).join("");
          outcome = await d.screener.screen(bytes);
        } catch { outcome = "unavailable"; }
        const accepted = await d.finish(item, outcome, hash);
        if (accepted) processed++;
        // A quota/network/service failure ends the batch, without immediate retries.
        if (outcome === "unavailable") return respond(503, "screening_unavailable", processed);
      }
      return respond(200, "complete", processed);
    } catch {
      return respond(503, "screening_unavailable");
    }
  };
}
