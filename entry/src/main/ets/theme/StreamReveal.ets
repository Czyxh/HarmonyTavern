export class StreamReveal {
  static boundary(text: string, shown: number, elapsed: number): number {
    const remaining: number = text.length - shown;
    if (remaining <= 0) { return text.length; }
    const frame: number = Math.max(1, Math.min(4, elapsed / 16));
    const advance: number = Math.max(1, Math.ceil(remaining * 0.16 * frame));
    let end: number = Math.min(text.length, Math.max(shown + advance, text.length - 320));
    if (end < text.length && text.charCodeAt(end - 1) >= 0xD800 && text.charCodeAt(end - 1) <= 0xDBFF) { end++; }
    return end;
  }
}
