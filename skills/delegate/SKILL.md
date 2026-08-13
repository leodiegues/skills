---
name: delegate
description: Use when the session model is Fable 5 and the work involves exploring a codebase or implementing a change — Fable plans and judges, Opus 5 and Sonnet 5 subagents explore, type, and run deeper reviews. Triggers on "delegate this", "orchestrate", "who should do this". Do NOT use on Opus, Sonnet, or Haiku sessions — those do the work directly.
---

# Delegate

Fable thinks. Opus and Sonnet type.

- **Not on Fable?** Say so in one line, do the work directly.
- **Plan, and judge the result, yourself.** Never delegate either.
- **Always pass `model` explicitly** — agents inherit Fable otherwise. `model: sonnet` when the target is named and the answer is mechanical; `model: opus` when the agent must make a call you haven't made, or Sonnet already came back wrong.
- **Explore** with `subagent_type: Explore`, **implement** with the default agent. Same tier rule for both.
- **Review** — run `/code-review low --fix` yourself for simple changes; Fable only produces low-effort reviews, so anything cross-cutting goes to a `model: opus` agent running `/code-review medium --fix`. Judge the findings yourself either way: they're proposals, check each against the diff.
- **Skip all this** for work smaller than the prompt describing it.

## Write the prompt so nothing comes back surprising

The agent sees none of this conversation. Anything you don't state, it invents. Every delegation carries:

- **Scope** — exact paths. Not "the auth module", not "the file we discussed".
- **Acceptance** — the command that proves it worked, and that the agent must run before returning.
- **Bounds** — what not to touch. Say it explicitly: no drive-by refactors, no new dependencies, no reformatting, no fixing unrelated things it notices.
- **Decisions already made** — the approach you chose and rejected alternatives, or it will re-litigate them and hand back a different design.
- **Return shape** — what you want back: a diff summary, a file list, a direct answer.

Restate constraints even when they feel obvious. The surprise is always in the gap you left.

Thin output means a thin prompt. Sharpen it and re-delegate rather than quietly finishing the work yourself — otherwise you write the same thin prompt next time.
