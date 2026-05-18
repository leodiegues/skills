# HTML artifact template

The HTML artifact is built **incrementally across Phase 2** (one section per L) and updated again in Phase 4. Self-contained HTML + CSS + Mermaid via CDN. No build step. No React. No bundler.

## Path

Write to `~/.codebase-explorer/<repo>/<slug>.html`. Run `mkdir -p ~/.codebase-explorer/<repo>` before the first write. `<repo>` is the target-repo directory name in kebab-case (e.g. `everday-monorepo`). `<slug>` is a short, descriptive kebab-case label for this exploration session — ≤6 words, derived from the user's scope at Checkpoint A (e.g. `prism-intake-boundary`, `auth-redirect-flow`, `pr-123-billing-refactor`). One HTML per session; one folder per repo. If the file already exists for a new session, pick a slightly different slug rather than overwriting. Phase 4 updates the in-progress session's file in place.

## Incremental write protocol

Phase 2 builds the file in three passes (one per L) plus a finalization pass:

- **Pass 1 (L1)**: create the file. Include header, **Metadata** (filled), **Findings summary** (placeholder), legend, L1 `<section>` (filled), and placeholder `<section>` blocks for L2, L3, Risks, "What I did NOT explore", Glossary, and (optional) Quiz log. Each placeholder is a `<section>` with the heading and a single `<p><em>… pending — will appear after the next checkpoint.</em></p>` body.
- **Pass 2 (L2)**: replace the L2 placeholder section's body with the real diagram + summary + `<details>` notes. Update the **Status** field in Metadata. Leave L3 and downstream placeholders intact.
- **Pass 3 (L3)**: same, for the L3 placeholder. Update Status.
- **Pass 4 (finalize, end of Phase 2)**: fill the Findings summary, Risks, "What I did NOT explore", and Glossary placeholders. Update Status to "Phase 2 complete".
- **Phase 3 (Quiz, optional)**: append entries to the Quiz log section live as each question closes. Promote any genuine codebase findings into the Findings summary (curated, not duplicated).
- **Phase 4 (Deepen)**: append a new `<section>` after L3 for the deepened view. Do not rewrite the file; just append the new section before the Risks section. Update Status.

Each pass only edits its own section (plus the Status field). Downstream placeholders remain readable so the user can see at a glance what's coming.

## Section order

1. **Header** — `<h1>` repo name + one-paragraph "what this is, in plain English" (≤40 words, ~grade-9 reading level).
2. **Metadata** — `<dl>` card: repo @ HEAD SHA · scope · anchor · generated date · status. Glanceable at top.
3. **Findings summary** — 3–7 headline takeaways from the session, curated. Populated at end of Phase 2; grows through Phase 3/4 as quiz/deepen surface new insights.
4. **Map legend** — arrow conventions, color conventions, zoom-level scheme.
5. **L1 — Context**: diagram → 2–3 bullet summary → `<details>` deeper notes.
6. **L2 — Containers**: same pattern.
7. **L3 — Vertical slice**: same pattern, with the chosen flow named ("What happens when a user submits the signup form").
8. **L3+ — Deepened views** (added by Phase 4, if any).
9. **Risks and smells** — bullet list, each with one-sentence explanation and a file/area pointer.
10. **What I did NOT explore** — explicit bullet list of skipped areas. This closes the loop on completeness anxiety.
11. **Glossary** — 5–10 plain-language definitions for jargon that did appear. Each ≤15 words.
12. **Quiz log** (optional, populated during Phase 3) — collapsed `<details>` per question: question · prediction · what matched/didn't · codebase finding · 0–10 confidence.
13. **Footer** — generated date, repo HEAD SHA (from `git rev-parse HEAD`), disclaimer: "this map is intentionally incomplete — see § What I did NOT explore."

## Accessibility rules (baked in, non-negotiable)

- `<html lang="en">`.
- Body font ≥16px (`clamp(16px, 1rem + 0.25vw, 18px)`), line-height 1.65, main column `max-width: 70ch`.
- Dark mode by default via CSS custom properties; toggle button in header flips `data-theme` on `<html>`.
- Foreground/background contrast ratio ≥7:1 (WCAG AAA for body text).
- Every Mermaid diagram followed by `<figcaption>` with the 2–3 bullet text equivalent. Screen readers get the same info.
- `<details>` blocks collapsed by default — progressive disclosure inside the document, ADHD-friendly.
- Mermaid containers: `role="img"`, `aria-label` matching the caption.
- `@media (prefers-reduced-motion: reduce)` disables any pan/zoom animations.
- No autoplay, no scroll animations, no sticky elements that obscure content.
- Headings in correct hierarchy: one `<h1>`, then `<h2>` per major section, no skipped levels.

## Prose style (in the surrounding text)

- One concept per paragraph; max 3 sentences per paragraph.
- "Uses" not "leverages", "creates" not "instantiates", "sends" not "dispatches", "stores" not "persists", "runs" not "executes".
- Italicize unavoidable jargon on first use and gloss in ≤5 words.
- Use the user's vocabulary from Checkpoint A when given.

## Skeleton

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{REPO_NAME}} — codebase map</title>
<script>
  // Read persisted theme BEFORE styles paint, so the toggle survives reloads
  // and we avoid a flash of wrong-theme content.
  (function () {
    var saved = localStorage.getItem('codebase-explorer-theme') || 'dark';
    document.documentElement.dataset.theme = saved;
  })();
</script>
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<style>
  :root[data-theme="dark"] {
    --bg: #0f1115;
    --fg: #e8e8ea;
    --muted: #9aa0a6;
    --accent: #7aa2f7;
    --border: #2a2d34;
    --code-bg: #1a1d23;
  }
  :root[data-theme="light"] {
    --bg: #fafafa;
    --fg: #1a1a1a;
    --muted: #555;
    --accent: #1d4ed8;
    --border: #d0d0d0;
    --code-bg: #f0f0f0;
  }
  * { box-sizing: border-box; }
  html { color-scheme: dark light; }
  body {
    font: clamp(16px, 1rem + 0.25vw, 18px)/1.65 system-ui, -apple-system, sans-serif;
    color: var(--fg);
    background: var(--bg);
    margin: 0;
  }
  main { max-width: 70ch; margin: 2rem auto; padding: 0 1rem; }
  h1, h2, h3 { line-height: 1.25; }
  h1 { border-bottom: 2px solid var(--accent); padding-bottom: .3em; }
  h2 { margin-top: 2.5em; border-bottom: 1px solid var(--border); padding-bottom: .2em; }
  figure { margin: 1.5em 0; }
  .mermaid { background: var(--code-bg); border: 1px solid var(--border); border-radius: 8px; padding: 1em; overflow-x: auto; }
  figcaption { color: var(--muted); margin-top: .6em; font-size: .95em; }
  figcaption ul { margin: .4em 0; padding-left: 1.2em; }
  details { margin: .6em 0 1.4em; border-left: 3px solid var(--border); padding-left: 1em; }
  details summary { cursor: pointer; color: var(--accent); }
  /* Inline code: chip style. */
  code { background: var(--code-bg); padding: .1em .35em; border-radius: 4px; font-size: .92em; }
  /* Block code: pre is the container; nested code resets so each preserved-whitespace line doesn't get its own chip. */
  pre:not(.mermaid) { background: var(--code-bg); border: 1px solid var(--border); border-radius: 8px; padding: 1em; overflow-x: auto; line-height: 1.5; }
  pre:not(.mermaid) code { background: transparent; padding: 0; border-radius: 0; font-size: .92em; display: block; white-space: pre; }
  .legend, .meta { background: var(--code-bg); border: 1px solid var(--border); border-radius: 8px; padding: 1em; }
  .legend ul { margin: .4em 0; padding-left: 1.2em; }
  .meta dl { display: grid; grid-template-columns: max-content 1fr; gap: .3em .9em; margin: .4em 0 0; }
  .meta dt { font-weight: 600; color: var(--muted); }
  .meta dd { margin: 0; }
  .findings ol { margin: .6em 0; padding-left: 1.4em; }
  .findings li { margin: .4em 0; }
  .theme-toggle {
    position: absolute; top: 1rem; right: 1rem;
    background: transparent; color: var(--fg);
    border: 1px solid var(--border); border-radius: 4px;
    padding: .3em .7em; cursor: pointer;
  }
  @media (prefers-reduced-motion: reduce) {
    * { animation: none !important; transition: none !important; }
  }
</style>
</head>
<body>
<button class="theme-toggle" onclick="(function(){var n=document.documentElement.dataset.theme==='dark'?'light':'dark';localStorage.setItem('codebase-explorer-theme',n);location.reload();})()">Toggle theme</button>

<main>
  <h1>{{REPO_NAME}} — codebase map</h1>
  <p>{{ONE_PARAGRAPH_WHAT_THIS_IS}}</p>

  <section aria-labelledby="meta-h" class="meta">
    <h2 id="meta-h">Metadata</h2>
    <dl>
      <dt>Repo</dt><dd><code>{{REPO_NAME}}</code> @ <code>{{HEAD_SHA}}</code></dd>
      <dt>Scope</dt><dd>{{ONE_LINE_SCOPE}}</dd>
      <dt>Anchor</dt><dd>{{ANCHOR — PR #N, feature name, file path, or "free exploration"}}</dd>
      <dt>Generated</dt><dd>{{DATE}}</dd>
      <dt>Status</dt><dd>{{Phase 1 done · Phase 2 in progress (L1) · Phase 2 complete · Phase 3 active · Phase 4}}</dd>
    </dl>
  </section>

  <section aria-labelledby="findings-h" class="findings">
    <h2 id="findings-h">Findings summary</h2>
    <p>The 3–7 most important things to remember from this session. Curated, not exhaustive — for the full lists see § Risks and smells, § Glossary, and § Quiz log.</p>
    <ol>
      <li><strong>{{HEADLINE_FINDING_1}}</strong> — {{ONE_SENTENCE_EXPLANATION}}</li>
      <li><strong>{{HEADLINE_FINDING_2}}</strong> — {{ONE_SENTENCE_EXPLANATION}}</li>
      <!-- 3 to 7 items total -->
    </ol>
  </section>

  <section aria-labelledby="legend-h" class="legend">
    <h2 id="legend-h">Map legend</h2>
    <ul>
      <li><strong>Solid arrow</strong> — runtime call or data flow.</li>
      <li><strong>Dotted arrow</strong> — depends on / configuration / build-time.</li>
      <li><strong>Thick arrow</strong> — the primary path highlighted in that view.</li>
      <li>Colors group by bounded context, not importance.</li>
    </ul>
  </section>

  <section aria-labelledby="l1-h">
    <h2 id="l1-h">Level 1 — Context</h2>
    <p>{{L1_PROSE}}</p>
    <figure>
      <pre class="mermaid" role="img" aria-label="{{L1_ARIA_LABEL}}">
{{L1_MERMAID_SOURCE}}
      </pre>
      <figcaption>
        <ul>
          <li>{{L1_BULLET_1}}</li>
          <li>{{L1_BULLET_2}}</li>
          <li>{{L1_BULLET_3}}</li>
        </ul>
      </figcaption>
    </figure>
    <details>
      <summary>Deeper notes</summary>
      <p>{{L1_DEEPER_NOTES}}</p>
    </details>
  </section>

  <section aria-labelledby="l2-h">
    <h2 id="l2-h">Level 2 — Containers</h2>
    <!-- same pattern as L1 -->
  </section>

  <section aria-labelledby="l3-h">
    <h2 id="l3-h">Level 3 — {{SLICE_NAME}}</h2>
    <!-- same pattern, with sequenceDiagram source -->
  </section>

  <section aria-labelledby="risks-h">
    <h2 id="risks-h">Risks and smells</h2>
    <ul>
      <li>{{RISK_1}} — <code>{{FILE_OR_AREA}}</code></li>
    </ul>
  </section>

  <section aria-labelledby="notexplored-h">
    <h2 id="notexplored-h">What I did NOT explore</h2>
    <ul>
      <li>{{SKIPPED_AREA_1}}</li>
    </ul>
  </section>

  <section aria-labelledby="glossary-h">
    <h2 id="glossary-h">Glossary</h2>
    <dl>
      <dt>{{TERM}}</dt><dd>{{≤15_WORD_DEFINITION}}</dd>
    </dl>
  </section>

  <footer>
    <p style="color: var(--muted); font-size: .9em; margin-top: 3em; border-top: 1px solid var(--border); padding-top: 1em;">
      Generated {{DATE}} from <code>{{HEAD_SHA}}</code>. This map is intentionally incomplete — see § What I did NOT explore.
    </p>
  </footer>
</main>

<script>
  mermaid.initialize({
    startOnLoad: true,
    theme: document.documentElement.dataset.theme === 'dark' ? 'dark' : 'default',
    securityLevel: 'loose',
    flowchart: { curve: 'basis' }
  });
</script>
</body>
</html>
```

## Filling the template

- Replace every `{{PLACEHOLDER}}` with concrete content for the actual repo.
- The `<pre class="mermaid">` blocks contain Mermaid source verbatim — preserve indentation and line breaks.
- `{{L1_ARIA_LABEL}}` must paraphrase the diagram content for screen-reader users (e.g. "Context diagram showing the system, two external services, and one datastore").
- Every `<figcaption>` MUST contain the 2–3 bullet plain-language summary. This is the text equivalent — never skip it.
- Repeat the `<section>` + `<figure>` + `<figcaption>` + `<details>` pattern for every diagram. Predictable structure is itself accessibility.

## Common mistakes

- Forgetting `<figcaption>` (breaks screen-reader access).
- Inline color values instead of CSS custom properties (breaks theme toggle).
- Heading levels skipped (`<h1>` → `<h3>`) — fails accessibility audit.
- Mermaid source inside a `<code>` block instead of `<pre class="mermaid">` — won't render.
- Trying to embed external CSS/JS — must be self-contained except CDN script.
- Writing to a path that's not `~/.codebase-explorer/<repo>/<slug>.html` — the artifact location is part of the contract.
