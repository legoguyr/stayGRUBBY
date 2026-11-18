export type Verdict = "approved" | "review" | "rejected" | "unavailable";
export interface ImageScreener { screen(bytes: Uint8Array): Promise<Verdict>; }

// Structural checks only. This does not recognize nudity, violence or abuse.
export function validJPEG(bytes: Uint8Array): boolean {
  if (bytes.length < 12 || bytes.length > 2_097_152 || bytes[0] !== 0xff || bytes[1] !== 0xd8
    || bytes[bytes.length - 2] !== 0xff || bytes[bytes.length - 1] !== 0xd9) return false;
  let offset = 2;
  let frame = false;
  while (offset + 3 < bytes.length) {
    if (bytes[offset++] !== 0xff) return false;
    while (bytes[offset] === 0xff) offset++;
    const marker = bytes[offset++];
    if (marker === 0xda) return frame;
    const length = bytes[offset] * 256 + bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) return false;
    if ([0xc0, 0xc1, 0xc2].includes(marker)) {
      if (length < 8) return false;
      const height = bytes[offset + 3] * 256 + bytes[offset + 4];
      const width = bytes[offset + 5] * 256 + bytes[offset + 6];
      if (height < 1 || width < 1 || height > 4096 || width > 4096) return false;
      frame = true;
    }
    offset += length;
  }
  return false;
}

/// The MVP adapter has no network dependency or key. Valid files await a person.
export function manualScreener(): ImageScreener {
  return { screen: async bytes => validJPEG(bytes) ? "review" : "rejected" };
}
