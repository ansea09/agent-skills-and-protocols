# Source Fidelity And Condition Attribution

Use when paraphrasing a material source claim, combining definitions, mapping
statuses, or saying that one condition implies another. This is a conditional
check within R05/R13/R15 and S5/C5, not a new baseline or a full audit of every
sentence. F.0.1, A.6.P, A.7, A.10 and E.17.EFP supply the relevant distinctions.

## Check

1. Recover what each source actually supports for the identified subject,
   edition and use. Preserve negation, modality, quantifiers, preconditions,
   exceptions and time. Separate a quotation from the agent's inference.
2. Compare each material output condition with that basis. Mere co-occurrence,
   a shared label or plausible lifecycle order does not establish implication.
3. Check both directions. If A means generated and B means tested and accepted,
   neither A implies B nor B implies generated unless the source or an explicit
   admitted rule supports that implication. Unknown is not false or failed.
4. Inspect additive/comparative wording such as "also", "additionally",
   "more complete", "therefore" and "broader". These words are cues, not a
   blacklist: an explicit implication may make them correct.
5. Remove an unsupported condition, preserve the distinction, or clearly label
   an additional inference/assumption and its limit. Put any material limit in
   the user-facing answer beside the claim, not only in an audit record.

A small claim-to-source note normally suffices. Use a per-condition table only
when the mapping is nontrivial or needs review. Do not build a global claim
database just to answer a bounded question.

## Worked Boundary

Source A: ready = generation completed.
Source B: ready = integration check performed and customer accepted.

| Source report | Generation completed | Check performed | Check passed | Customer accepted |
| --- | --- | --- | --- | --- |
| A ready | supported | unknown | unknown | unknown |
| B ready | unknown | supported | unknown | supported |

This maps assertions, not verified real-world events. The two reports can be
combined only for the same identified subject/version under a justified
temporal rule. If B explicitly adds "generation completed" or "check passed",
the corresponding supported value changes. Do not turn an example's unknown
into a permanent prohibition on legitimate entailment.

## Watching Recurrence

Known case family: SC-01, unsupported transfer of source conditions.
Status: open-monitoring. The initial pilot found additive ambiguity in two
candidate answers to T13; it did not establish the cause or a defect in a
particular FPF pattern. Adding this check does not close the issue.

When an applicable answer is checked, no warning is needed if no issue is found.
Do not print an all-clear badge or write a log row for every ordinary response.
When a material issue is detected, including one corrected before delivery:

- Explain a correction to the user if the affected claim was already delivered
  or changes a decision. Do not silently rewrite a prior recommendation.
- If monitoring is requested and an authorized non-public log destination is
  configured, append one minimal observation: date, case ID, source locator and
  version, minimal permitted source excerpt/condition, answer claim, unsupported
  transfer, correction, review outcome and evidence limit.
- Preserve the original observation and append later review rather than replacing
  the evidence. Mark a suspected issue as suspected until checked. Store no
  secrets or unnecessary conversation/source copies.
- If persistence is unavailable, report that the observation was not durably
  logged. Do not invent an entry or create a public issue automatically.

The [observation template](templates/source-fidelity-observation.yaml) describes
the fields; it is not an automatic logger or detector. A user can request a
review of available observations. A scheduled monitor requires a separately
configured automation; this protocol installs none and cannot inspect all
chats. Do not infer an error rate from a log that records only detected cases.

## Regression And Closure

Use [SC-01 regression inputs](regressions/source-condition-attribution.md)
after relevant changes and when a new recurrence warrants it. Preserve raw
responses, versions, criteria and review results. Automated package/link checks
do not grade natural-language entailment.

A correction and passing retest address those examples, not universal
elimination. Keep open-monitoring until the user explicitly accepts a bounded
closure rationale; define conditions that would reopen it. More prompting or
more FPF pattern mentions are not evidence that the issue was fixed.
