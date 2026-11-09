export type Part = { kind: 'md' | 'mermaid'; text: string }

const FENCE = /^```mermaid[^\n]*\n([\s\S]*?)^```[ \t]*$/gm

/** Splits markdown into plain runs and closed ```mermaid fences (an unclosed one stays markdown). */
export function split(text: string): Part[] {
  const parts: Part[] = []
  let at = 0
  for (const m of text.matchAll(FENCE)) {
    const before = text.slice(at, m.index).trim()
    if (before) parts.push({ kind: 'md', text: before })
    parts.push({ kind: 'mermaid', text: m[1] ?? '' })
    at = m.index + m[0].length
  }
  const rest = text.slice(at).trim()
  if (rest) parts.push({ kind: 'md', text: rest })
  return parts
}

/** Width/height of a PNG from its base64 IHDR. */
export function pngSize(b64: string): { w: number; h: number } {
  const b = Uint8Array.from(atob(b64.slice(0, 32)), c => c.charCodeAt(0))
  const u32 = (o: number) => new DataView(b.buffer).getUint32(o)
  return { w: u32(16), h: u32(20) }
}
