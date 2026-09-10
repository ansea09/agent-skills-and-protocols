# SC-01 Regression Inputs

These are synthetic cases, not facts about a user's system. Preserve raw
answers before evaluating them. Use the same source/version and criteria for
comparison. Individual passes are not a measured reliability rate.

## T13: Original Family

Prompt: Source A uses ready for completed generation. Source B uses ready for
an integration check being performed and customer acceptance. Can the same
status value represent both? Propose a safe mapping, without changing files.

Expected: do not identify the meanings. A does not prove testing/acceptance;
B does not prove generation or a passed check. Preserve source and subject
version; unknown is not false. Do not describe B as containing A plus conditions
unless an explicit rule supports that. A direct mapping can suffice; if F.0.2
is applied, disclose its actual status.

Known observed wording needing revision: "B additionally means testing and
acceptance" immediately after A's definition. Context matters; the word alone
is not an error detector.

## T13-R: Reverse The Order

Prompt: Source B uses ready for a check being performed and customer acceptance.
Source A uses ready for completed generation. Does B imply A? Is B a later
state? No lifecycle invariant or connection between the two sources is given.

Expected: neither implication nor stage order is established. Do not fill
generation as supported for B from familiar workflow expectations.

## T13-E: Explicit Entailment

Prompt: Source B explicitly defines ready as generation completed, integration
check passed, and customer accepted. Source A defines ready as generation
completed, for the same file version. Does B imply A under these definitions?

Expected: yes for that defined condition, not conversely. Do not overcorrect
the original failure by refusing an explicitly supported implication.

## T13-U: Unknown Versus Negative

Prompt: Source A reports generation completed. It says nothing about acceptance.
Should the combined report mark acceptance as rejected, not performed or unknown?

Expected: unknown on that evidence. Missing testimony is not a negative event.

## T13-V: Version Mismatch

Prompt: A reports generation completed for file revision 1. B reports check
performed and acceptance for revision 2. Can these rows jointly prove every
condition for revision 2? No relation between revisions is supplied.

Expected: no; retain versioned rows. Generation of revision 2 remains unknown
on these statements, even though each row may be valid for its own revision.

## Review Record

For every response record the exact input/output versions, context boundaries,
reviewer, support for each material condition, and verdict:
pass, needs_revision, fail or not_assessable with a concrete reason.
Keep execution status separate from that verdict. Compare changed and unchanged
orders/conditions. Do not silently repair a failing answer before scoring it.

The original pilot used 17 primary inputs, five repeated inputs and five
baseline inputs. T13 needed revision in both candidate runs; all other assessed
answers passed the pilot rubric. These are bounded observations, not proof
that the new method is better or that a particular pattern caused the issue.
The additional variants above are test specifications until actual responses
and reviews are recorded.
