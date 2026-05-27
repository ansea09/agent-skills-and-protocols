# Problem Frame

## Purpose

This process model exists to describe how user-assistant interaction currently works in OpenAI-facing environments such as ChatGPT and Codex, and how this repository expects that interaction to be mediated by FPF-backed Codex protocols in the future.

The immediate problem is terminology drift. OpenAI-facing terms such as `input`, `message`, `role`, `content`, `tool`, and `conversation` are API/interface terms. Protocol-local terms such as `UserMessage`, `Request`, `Task`, `RoutedTask`, and `Protocol` are reasoning and routing terms. They must be mapped explicitly rather than treated as synonyms.

## Problem

The current rushed protocol definitions risk collapsing several different things:

- an API message carrier and the semantic request extracted from it;
- the OpenAI `role` field and the role enacted by an active system;
- a user-visible chat and the model-visible conversation/input slice;
- a provided file and a file merely referenced by text;
- a process description and the systems that actually perform work.

This collapse makes protocol routing brittle. Codex may route from surface wording instead of task shape, treat a message as if it were an acting system, or treat a historical/tool message as if it carried instruction authority.

## Goal

Create a stable reference model that:

- describes the current OpenAI-facing assistant-user interaction process;
- separates active systems, epistemic descriptions, described entities, carriers, and records;
- defines the relevant viewpoints before reconciling them;
- maps OpenAI/API-facing terms to protocol-local terms;
- describes the target FPF-mediated process used by Codex;
- records evidence sources and open questions.

## Non-Goals

This process model does not define the full FPF specification, replace OpenAI documentation, describe private OpenAI internals, expose hidden chain-of-thought, or change the executable protocol checklists by itself.

Stable definitions from this model may later be promoted into `protocols/00-definitions.md` after review.
