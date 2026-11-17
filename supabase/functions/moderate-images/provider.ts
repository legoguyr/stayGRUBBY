export type Verdict = "approved" | "review" | "rejected" | "unavailable";
export interface ImageScreener {
  screen(bytes: Uint8Array): Promise<Verdict>;
}

const levels = ["UNKNOWN", "VERY_UNLIKELY", "UNLIKELY", "POSSIBLE", "LIKELY", "VERY_LIKELY"];
export function safeSearchVerdict(result: unknown): Verdict {
  if (!result || typeof result !== "object") return "unavailable";
  const body = result as { responses?: { error?: unknown; safeSearchAnnotation?: Record<string, unknown> }[] };
  if (!Array.isArray(body.responses) || body.responses.length !== 1) return "unavailable";
  const entry = body.responses[0];
  if (!entry || entry.error || !entry.safeSearchAnnotation) return "unavailable";
  // Medical/spoof content alone is not prohibited. Explicit adult, racy or violent
  // content is routed conservatively, preserving human review for ambiguity.
  const scores = ["adult", "violence", "racy"].map(key => levels.indexOf(String(entry.safeSearchAnnotation![key])));
  if (scores.some(score => score <= 0)) return "review";
  if (scores[0] >= 4 || scores[1] >= 4) return "rejected";
  if (scores.some(score => score >= 3)) return "review";
  return "approved";
}

export function visionScreener(key: string, send: typeof fetch = fetch): ImageScreener {
  return {
    async screen(bytes) {
      if (!key || bytes.length === 0 || bytes.length > 2_097_152) return "unavailable";
      let binary = "";
      for (let offset = 0; offset < bytes.length; offset += 8192) {
        binary += String.fromCharCode(...bytes.subarray(offset, offset + 8192));
      }
      try {
        const response = await send("https://vision.googleapis.com/v1/images:annotate", {
          method: "POST",
          headers: { "content-type": "application/json", "x-goog-api-key": key },
          body: JSON.stringify({ requests: [{ image: { content: btoa(binary) }, features: [{ type: "SAFE_SEARCH_DETECTION" }] }] }),
          signal: AbortSignal.timeout(12_000),
          redirect: "error",
        });
        if (!response.ok) return "unavailable";
        const reader = response.body?.getReader();
        if (!reader) return "unavailable";
        const chunks: Uint8Array[] = [];
        let size = 0;
        try {
          while (true) {
            const part = await reader.read();
            if (part.done) break;
            size += part.value.length;
            if (size > 32_000) { await reader.cancel(); return "unavailable"; }
            chunks.push(part.value);
          }
        } finally { reader.releaseLock(); }
        const all = new Uint8Array(size);
        let offset = 0;
        for (const chunk of chunks) { all.set(chunk, offset); offset += chunk.length; }
        return safeSearchVerdict(JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(all)));
      } catch {
        return "unavailable";
      }
    },
  };
}
