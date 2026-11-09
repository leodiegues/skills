import { expect, test } from 'claude-code/testing'

import { pngSize, split } from './mermaid'

test('split keeps closed mermaid fences apart and leaves an unclosed one as markdown', async () => {
  const text = 'Intro\n\n```mermaid\ngraph TD\n A --> B\n```\n\nOutro\n```mermaid\ngraph LR\n'
  expect(split(text)).toEqual([
    { kind: 'md', text: 'Intro' },
    { kind: 'mermaid', text: 'graph TD\n A --> B\n' },
    { kind: 'md', text: 'Outro\n```mermaid\ngraph LR' },
  ])
})

test('pngSize reads the IHDR', async () => {
  // 127 x 302 PNG header, as mmdr writes it
  expect(pngSize('iVBORw0KGgoAAAANSUhEUgAAAH8AAAEuCAYAAACnGM31AAAUbUlEQVR4nO2d')).toEqual({ w: 127, h: 302 })
})
