# Boundary And Scope

## Bounded Context

This folder describes the `assistant-user interaction process`: the process by which a user communicates with an assistant through ChatGPT, Codex, or an OpenAI API-backed application.

The context is limited to externally describable behavior: messages, inputs, outputs, tool calls, conversation state, instruction authority, and protocol routing. It does not claim knowledge of private implementation details.

## Inside The Boundary

Inside scope:

- the user/user as a system providing goals, constraints, messages, files, and corrections;
- the assistant/assistant as the model-enacted participant that answers or requests tool work;
- OpenAI platform/product runtime as the system that supplies model, policy, system messages, context handling, and tool mediation;
- developer/application layer as the system that supplies developer instructions, tool definitions, UI behavior, and business logic;
- tools/tools and connectors/connectors that may perform external or local work;
- message/message, input/input, content/content, tool output/tool output, response/response, and conversation state/conversation state;
- message ownership/source and instruction authority/authority;
- protocol-local extraction of Request, Task, and RoutedTask.

## Outside The Boundary

Outside scope:

- model training/training and fine-tuning internals;
- private OpenAI system policies or hidden implementation details;
- full hidden chain-of-thought;
- product UI details that do not affect the model-visible interaction;
- unrelated protocol domains outside assistant-user interaction;
- GitHub publication or automation execution, except as future examples of tool-mediated work.

## Boundary Rule

This process model describes the communication process, not every object that may appear inside the communication. For example, a file can be provided as an input resource, but the file's domain content belongs to a separate task-specific context unless the current task is about the file-handling process itself.

## Terminology Rule

OpenAI documentation uses `role` as an API field on messages. This process model treats that field as message ownership/source. A message is a carrier of content; it is not an acting system. Active systems can enact roles; messages have ownership/source and may carry instructions with an authority level.
