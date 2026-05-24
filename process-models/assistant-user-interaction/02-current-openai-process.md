# Current OpenAI-Facing Process

## Scope Of This Description

This file describes the current OpenAI-facing `assistant-user interaction process`: how a `user` interacts with an `assistant` through ChatGPT, Codex, or an OpenAI API-backed application.

Inside scope:

- the `assistant`, `model`, `conversation`, `input`, `message`, `role`, `content`, `metadata`, `tool`, `token`, `developer`, `user`, `response`, and `chain of command` terms used by OpenAI;
- how `messages` are assembled into model-visible input;
- how `role` values identify message source/ownership and affect instruction authority;
- how `tools`, `tool` messages, and side effects enter the interaction;
- how long `conversations` may be truncated or persisted through `conversation state`.

Outside scope:

- model training internals;
- private OpenAI infrastructure;
- hidden system-policy details that are not exposed in the public Model Spec or API docs;
- raw hidden chain-of-thought content;
- task-specific domain content carried inside a user file or message.

## Term Marking Rule

OpenAI-facing terms are marked with inline code, for example `assistant`, `conversation`, `input`, `message`, `role`, `content`, `tool`, and `chain of command`.

No separate OpenAI-terms file is introduced here. A separate glossary would duplicate this file, `04-api-to-protocol-term-mapping.md`, and `evidence-register.yaml`. If this vocabulary grows beyond the current small set, create a dedicated terminology file and register it in `registry.yaml`.

## Core Process Summary

From the OpenAI-facing viewpoint, interaction is organized as a `conversation`: valid model input is a `conversation`, and a `conversation` consists of a list of `messages`.

At this description layer, the basic unit of communication is the `message`. A `message` carries `content` and source-like `metadata`. In OpenAI's public terminology, each `message` contains a `role`; in this process model, that `role` field is treated as message ownership/source, not as a role enacted by the `message` itself.

At the API layer, `input` is the payload supplied to a model request. `input` may be a plain string or a structured set of input items, including `messages` with `role` and `content`. Therefore `input` is the transport/API surface, while `conversation` is the conversation-description structure.

The `assistant` is the entity that the `user` or `developer` interacts with. OpenAI generally prefers `assistant` over `agent`; the term `agent` is used mainly for more autonomous deployments. OpenAI also uses `model` when describing the underlying language model. In this process model, `assistant` names the interaction participant, while `model` names the computational system that generates assistant behavior.

## OpenAI Objects In The Process

### `assistant` And `model`

The `assistant` is the participant that responds to the `user` or `developer`. The `model` is the language-model system that generates the `assistant` output.

For process description, treat `assistant` as the externally visible participant and `model` as the underlying system. They are close in OpenAI prose, but they should not be collapsed when implementation or responsibility matters.

### `conversation`

A `conversation` is the model-facing interaction structure: a list of `messages` supplied as valid input to the `model`.

In ChatGPT, a user-visible chat can grow longer than the model can process in one request. When that happens, the model-visible `conversation` may be truncated. OpenAI describes truncation as prioritizing newer and more relevant information. The `user` may not know which parts of the visible chat are actually included in the model-visible `conversation`.

In the API, a `conversation` may also be represented or continued through explicit history, `previous_response_id`, or a durable conversation object. Therefore, a `conversation` is not automatically identical to the entire visible chat.

### `input`

`Input` is the model-request payload. It is what the application or product sends to the model-facing API or runtime for a particular generation step.

`Input` may include `messages`, content items, files, images, tool definitions, and state references. The exact `input` supplied to one model request may be only a slice of a longer user-visible interaction.

### `message`

A `message` is the basic exchange unit in the `conversation`. The `assistant` and `user` exchange `messages`; tool calls and tool outputs can also be represented as `messages` or conversation items, depending on the API surface.

Each `message` has at least:

- `role`: OpenAI's field for the source of the `message`;
- `content`: text, untrusted text, and/or multimodal chunks such as images or audio;
- optional `metadata`: information about intended purpose, use, audience, user state, or system handling.

Ontology note: a `message` is a carrier or record of communicative content. The `message` itself is not an active system. Active systems such as OpenAI, the `developer`, the `user`, the `assistant`, and `tools` may produce or own `messages`.

## `role` As Source/Ownership, Not Enacted Role

OpenAI says every `message` has a `role`. In this process model, that statement is normalized as follows:

> A `message` has a source/ownership characteristic. OpenAI's API field for that characteristic is `role`.

This avoids confusing two different meanings of "role":

- OpenAI API-facing `role`: the source/ownership label on a `message`;
- protocol/ontology role: a role enacted by an active system in a bounded context.

The OpenAI `role` values relevant here are:

| OpenAI `role` | Process-model reading | Authority relation |
| --- | --- | --- |
| `system` | `message` added by OpenAI or the platform/system layer | higher than `developer`, `user`, and `guideline` instructions |
| `developer` | `message` from the API application developer, possibly also OpenAI in first-party products | lower than `system`, higher than `user` |
| `user` | input from end users, or a catch-all for data supplied to the `model` | lower than `developer` |
| `assistant` | `message` sampled/generated from the language model as assistant output | no instruction authority by default |
| `tool` | `message` generated by a program, code execution, API call, or other tool result | no instruction authority by default |

OpenAI `role` is therefore tied to authority, but it is not identical to authority. Source/ownership helps determine the authority level of instructions carried by a `message`. Other `content` inside a `message` can still be untrusted or non-instructional.

## `system` Message Vs `assistant` Message

A `system` message is owned by OpenAI or the platform/system layer. It sets rules, safety boundaries, runtime constraints, product conditions, or tool availability. It is not the `assistant` replying to the `user`.

An `assistant` message is generated by the `model` as assistant output. It may be a user-visible answer, an intermediate assistant output, or a message that calls a `tool`. It can become part of conversation history, but it has no instruction authority by default.

The system layer frames the interaction. The `assistant` acts inside that frame.

## `content` And `metadata`

The `content` of a `message` can be text, untrusted text, or multimodal data such as image or audio chunks. In the Responses API, a `user` message may contain structured content items such as `input_text` and `input_file`.

`Conversations` and `messages` may also contain `metadata` about their intended purpose and use in the overall system. For example, the system may indicate that the interaction should be handled under Under-18 Principles. Such `metadata` can affect how the `assistant` should interpret and respond to the `conversation`.

Process-model distinction:

- `content` is what the `message` carries;
- `metadata` describes how the `message` or `conversation` should be interpreted or used;
- neither `content` nor `metadata` is an acting system.

## `hidden chain-of-thought message`

Some OpenAI models can generate a `hidden chain-of-thought message` before producing a final answer. OpenAI describes this as hidden reasoning used to guide model behavior.

The `hidden chain-of-thought message` is not exposed to the `user` or `developer`, except potentially in summarized form. If the `user` asks for the model's hidden reasoning, the assistant should not reveal raw hidden chain-of-thought. A visible explanation should be a brief, safe summary of reasoning rather than the hidden reasoning trace.

Process-model distinction:

- the final `assistant` response is user-visible output;
- the `hidden chain-of-thought message` is not part of the user-visible conversation;
- the hidden reasoning may mention unsafe or policy-violating candidate content, so it must not be treated as ordinary shareable `content`.

## `token`

OpenAI describes a `token` as an atomic unit of text or multimodal data, such as a word or part of a word. A `message` is converted into a sequence of `tokens` before being passed into the language model.

For this process model, `token` is a measurement unit for input and output length. Models typically have a maximum number of `tokens` they can take in or produce in one request. When a `conversation` becomes too long, token limits are one reason the model-visible input may be truncated or compacted.

## `tool`

A `tool` is a program that the `assistant` can call to perform a specific task, such as retrieving data, executing code, reading files, generating images, or calling an API.

Usually, the `assistant` decides whether a `tool` is appropriate for the task. A `system` or `developer` message can list available `tools` and document each tool's function and invocation syntax. When the `assistant` sends a message to a `tool`, the result is appended back to the interaction as `tool` output or a `tool` message, and the `assistant` may be invoked again.

Some `tool` calls may have `side-effects` that are difficult or impossible to reverse, such as sending email, deleting a file, editing a repository, or publishing to an external service. In `agentic contexts`, the `assistant` must take extra care before generating `actions` that may produce `side-effects`.

## `developer`

In OpenAI's API context, the `developer` is the customer or application layer that uses the OpenAI API.

The `developer` can provide `developer` messages containing application rules, business logic, output format requirements, tool definitions, or task framing. OpenAI's API documentation says `developer` messages are prioritized ahead of `user` messages.

The `developer` can choose to send a sequence of `developer`, `user`, and `assistant` messages as `input`, including `assistant` messages that were not actually generated by the `assistant`. OpenAI may also insert `system` messages into the input to steer assistant behavior.

The `developer` may receive the assistant's output messages from the API, but may not know all system messages or receive hidden chain-of-thought messages. In first-party products such as ChatGPT, OpenAI itself may also play a developer-like role when it creates product behavior or third-party extension rules.

## `user`

The `user` is the person using an OpenAI product such as ChatGPT, Codex, or a third-party application built on the OpenAI API.

The `user` typically sees their own `messages`, the `assistant` replies, and sometimes messages to or from `tools`. The `user` may not know about `system` or `developer` messages. The `user`'s goals may differ from the `developer`'s goals.

In API applications, the `assistant` may not know whether there is an end user distinct from the `developer`, or how the `assistant` input and output relate to what the end user actually sees.

## `chain of command`

The `chain of command` is OpenAI's hierarchy for deciding which instructions the `assistant` should follow when instructions conflict.

The authority order is:

1. `root`
2. `system`
3. `developer`
4. `user`
5. `guideline`
6. `no authority`

When the `assistant` receives model input, it should identify candidate instructions, assign them authority based on their source, and filter out instructions that are overridden by higher-authority instructions, superseded by later same-authority instructions, or outside the assistant's capabilities.

Assistant and `tool` messages, quoted text, untrusted text, images, and tool outputs have no instruction authority by default. They should not override higher-authority instructions unless a higher-authority instruction explicitly delegates authority to them.

## Step-By-Step Interaction Flow

1. The `user` writes a `message` through ChatGPT, Codex, or an API-backed application.
2. The product or application combines the `user` message with other model-visible material: `system` messages, `developer` messages, prior `conversation` history, tool definitions, files, images, and `conversation state`.
3. The resulting model `input` is represented as a `conversation` or another Responses API input structure.
4. Each `message` in that input has `content` and a `role` field. This process model interprets `role` as message source/ownership.
5. The `message` `content` is converted into `tokens` before model processing.
6. The `assistant` identifies candidate instructions from the Model Spec and from plain, unquoted text in `system`, `developer`, and `user` messages.
7. The `assistant` applies the `chain of command` to determine which instructions are applicable.
8. The `assistant` reasons toward a response. Some models may generate a `hidden chain-of-thought message`; that hidden reasoning is not exposed as raw output.
9. The `assistant` either produces a user-visible `assistant` message or calls a `tool`.
10. If a `tool` is called, the `tool` performs the external or hosted operation and returns `tool` output.
11. The `tool` output is added back to the interaction as `tool` content or a conversation item.
12. The `assistant` may be invoked again with the updated `conversation`.
13. The final `assistant` `response` is returned to the `user` through the product or application surface.

## ChatGPT And Codex Product Surfaces

ChatGPT and Codex are product surfaces over OpenAI models and runtime services. ChatGPT is a general assistant-facing product. Codex is a coding-agent product surface where the interaction may include workspace files, shell commands, browser/tool use, GitHub context, code edits, approvals, and side effects.

These product-specific capabilities change available tools and work surfaces. They do not remove the core distinctions in this file: `conversation`, `input`, `message`, `role`, `content`, `metadata`, `tool`, `token`, `developer`, `user`, `assistant`, `response`, and `chain of command`.
