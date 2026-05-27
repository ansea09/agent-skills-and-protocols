# Open Questions

These questions remain intentionally open until the process model is reviewed and promoted into executable protocols.

## Naming

- Should the protocol-local field be named `messageOwnership`, `messageSource`, or `messageBelongsTo`?
- Should Russian-facing prose prefer `принадлежность сообщения`, `источник сообщения`, or both?
- Should `ConversationStateRecord` and `ConversationStatePointer` become durable protocol terms, or remain explanatory terms?

## Routing

- When one user message contains several requests, when should each request become a separate routed task?
- When should a subtask inherit the parent protocol, and when should it become a separately routed task?
- Should `RoutedTask` be treated as routing-kitted only, or should there be a separate `WorkReadyTask` for full-kitted work?

## Evidence

- Which OpenAI source should be treated as primary when Model Spec and API docs use different language for the same surface?
- How often should the evidence register be refreshed?
- Should this repository pin exact OpenAI documentation versions, latest URLs, or both?

## Process Scope

- Should ChatGPT and Codex be modeled in one shared process model with product-specific notes, or split into separate process models later?
- Should agent delegation and recurring automations get their own process-model folders?
