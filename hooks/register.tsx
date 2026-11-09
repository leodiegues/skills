import type { EngineInterface, Register } from 'claude-code'

import { pngSize, split } from './mermaid'

type Png = { png: string; w: number; h: number }
type Drawn = Png | { svg: string } | null

// mmdr (mermaid-rs-renderer) is found on PATH or in cargo's bin.
const SH = 'PATH="$PATH:$HOME/.cargo/bin"; '
const SCALE = 3 // rasterize at 3x so the image stays sharp on HiDPI terminals

// ponytail: per-process cache, unbounded; fine for a session's diagrams, add LRU if it ever grows large
const cache = new Map<string, Promise<Drawn>>()

async function mmdr($: EngineInterface, src: string, args: string): Promise<string | null> {
  try {
    const r = await $.process.run(['sh', '-c', SH + args], { stdin: src, timeoutMs: 10_000 })
    return r.exitCode === 0 && r.stdout.trim() ? r.stdout.trim() : null
  } catch {
    return null
  }
}

async function draw($: EngineInterface, src: string, isTerminal: boolean): Promise<Drawn> {
  if (!isTerminal) {
    const svg = await mmdr($, src, 'mmdr -i -')
    return svg && svg.length <= 131_072 ? { svg } : null
  }
  const size = await mmdr($, src, 'mmdr -i - --size')
  if (!size) return null
  const { width, height } = JSON.parse(size) as { width: number; height: number }
  const w = Math.ceil(width * SCALE)
  const h = Math.ceil(height * SCALE)
  const png = await mmdr($, src, `set -o pipefail; mmdr -i - -e png -w ${w} -H ${h} -o /dev/stdout | base64`)
  if (!png?.startsWith('iVBOR')) return null
  const b64 = png.replace(/\s/g, '')
  return { png: b64, ...pngSize(b64) }
}

/** Terminal cells for a picture: ~8px per column at 1x, cells twice as tall as wide. */
function cells(p: Png, maxColumns: number) {
  let columns = Math.min(maxColumns, Math.ceil(p.w / SCALE / 8))
  let rows = Math.ceil((columns * p.h) / p.w / 2)
  if (rows > 40) {
    rows = 40
    columns = Math.max(1, Math.round((rows * 2 * p.w) / p.h))
  }
  return { columns: Math.max(1, Math.min(255, columns)), rows: Math.max(1, rows) }
}

export const register: Register = on => {
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (!e.props.text.includes('```mermaid')) return next(e)
    const parts = split(e.props.text)
    if (!parts.some(p => p.kind === 'mermaid')) return next(e)

    const isTerminal = e.surface === 'terminal'
    const drawn = await Promise.all(
      parts.map(p => {
        if (p.kind === 'md') return null
        const key = `${e.surface}:${p.text}`
        if (!cache.has(key)) cache.set(key, draw($, p.text, isTerminal))
        return cache.get(key)!
      }),
    )
    // Nothing rendered (mmdr missing, bad syntax): leave the reply as the engine draws it.
    if (drawn.every(d => d === null)) return next(e)

    const maxColumns = Math.max(10, (e.viewport?.columns ?? 80) - 4)
    const t = $.ui.resolve(e)
    const fence = (src: string) => '```mermaid\n' + src + '```'

    return (
      <t.Box flexDirection="column">
        {parts.map((p, i) => {
          const d = drawn[i]
          if (p.kind === 'md' || !d) return <t.Markdown text={p.kind === 'md' ? p.text : fence(p.text)} />
          if ('svg' in d) return 'Svg' in t ? <t.Svg source={d.svg} alt="mermaid diagram" /> : null
          return 'Image' in t ? (
            <t.Image source={{ png: d.png }} alt="[mermaid diagram]" {...cells(d, maxColumns)} />
          ) : null
        })}
      </t.Box>
    )
  })
}
