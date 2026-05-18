# Quiz bank

Question templates organized by Bloom level. **Instantiate each with concrete nouns from THIS codebase** — never paste a template with placeholders into the chat. Suggested per-round mix: 1× Understand, 2× Apply, 2× Analyze, 1× Evaluate, 1× Create.

## Protocol per question

1. Ask ONE question. Reference a node/edge from the map.
2. **WAIT** for the user's prediction. Do not give the answer.
3. Verify. If correct, confirm + one new detail. If wrong, reframe as a finding about the code (see "Wrong-answer reframings" below).
4. Ask: "0–10, how confident could you explain this tomorrow?" Note anything ≤6 for Phase 4.

**Skip Remember-level questions entirely.** Trivia ("what does API stand for") is not a learning signal.

## Understand (light warm-up, max 1 per round)

1. "In your own words, what is `<COMPONENT>` responsible for? What is it deliberately *not* responsible for?"
2. "Looking at the L2 map, what's the difference between `<MODULE_A>` and `<MODULE_B>` — why are they separate?"
3. "If I deleted `<DIRECTORY>` entirely, what behavior would break?"
4. "What's the difference between the data in `<DATASTORE_A>` vs `<DATASTORE_B>`?"

## Apply — predict-then-verify (workhorse, 2 per round)

5. "A user does `<EXTERNAL_TRIGGER>`. Walk me through the call chain before I confirm. Which boxes from the L2 diagram does this touch, in order?"
6. "If `<EXTERNAL_DEPENDENCY>` is down, what happens to a `<TYPICAL_REQUEST>`? Where does it fail?"
7. "Where in the code would you add logging if you wanted to know when `<EVENT>` happens?"
8. "What does this function probably do, based only on its name and signature? `<PASTE_SIGNATURE>`"
9. "If I wanted to run *just* `<SUBSYSTEM>` locally without the full stack, what's the smallest set of things I'd need running?"

## Analyze — decomposition and contract-finding (2 per round)

10. "`<COMPONENT_A>` doesn't call `<COMPONENT_B>` directly — it goes through `<INTERMEDIARY>`. Why was that decision made? What does it buy?"
11. "What's the implicit contract between `<MODULE_A>` and `<MODULE_B>`? What breaks if one side violates it?"
12. "Pick a smell from the L2 diagram. Why is it a smell? Is it actually a problem here, or intentional?"
13. "Which two modules in this codebase are most coupled? How can you tell from imports alone?"
14. "Where does this codebase blur the line between business logic and I/O? Show me one example."

## Evaluate — judgment (1 per round)

15. "Which of the bounded contexts in the L2 diagram is the riskiest to change right now? What's your evidence?"
16. "If you had to bet on which subsystem will be replaced first in the next year, which would it be and why?"
17. "Rank the test coverage of the L2 boxes by gut feel. Then we'll check against the test directory."
18. "Where's the strongest seam — the place where you could swap out the implementation with the least disruption?"
19. "What's one architectural decision here you would push back on if you were on the team? What's one you'd defend?"

## Create — bridge to future work without implementing (1 per round, often the closer)

20. "If you had to add `<HYPOTHETICAL_FEATURE>`, where would the change live? What would you avoid touching?"
21. "Sketch the rollback plan if `<RECENT_FEATURE>` had a critical bug in production right now."
22. "If you had to onboard *the next* engineer, which two files would you have them read first? Why those?"
23. "What ADR would you write if you had time? What decision is currently undocumented?"
24. "What's the one diagram missing from our map that you'd want before your first PR?"

**Important for Create-level questions:** these are quiz questions, **not** requests to implement. The user predicts; you confirm or correct. You do not write the feature, the rollback, or the ADR.

## Wrong-answer reframings

Always reframe as a *finding about the code*, never a verdict on the user. Never use "incorrect", "wrong", or "no" as the opener. Never repeat the wrong prediction back at them.

**Misleading naming**
> "Reasonable guess given the file name. The actual flow goes through `<ACTUAL_PATH>` — the name `<MISLEADING_NAME>` is misleading because it was renamed during the 2023 refactor but kept the old module name for backward compat. That's a finding worth noting in the artifact."

**Implicit contract**
> "Close — what you'd expect from the type signature. But `<COMPONENT>` also assumes `<PRECONDITION>` implicitly. That's an unwritten contract — a smell worth flagging."

**Stale docs**
> "That matches the README, but the README is out of date here. The actual flow is `<ACTUAL>`. Add 'README stale around <AREA>' to the risks section."

**User got it directionally right but missed a detail**
> "You got the shape of it. One detail to add: `<DETAIL>`. Does that change your mental model or does it slot in cleanly?"

**User has no idea**
> "Fair — this one's not obvious from the map alone. Let me show you the relevant piece. [show 5–10 lines, point at the key thing.] Now what would you predict happens next?"

## What NOT to do in the quiz phase

- Don't present a question bank. **One question at a time.**
- Don't give the answer with the question.
- Don't mark questions as "right" or "wrong" — frame as "matches the code" or "the code actually does X here".
- Don't skip the confidence rating. The 0–10 self-report is the signal for Phase 4.
- Don't quiz on trivia (Remember level). Apply/Analyze/Evaluate are the value.
- Don't quiz on code you haven't shown them yet. Reference the map.
