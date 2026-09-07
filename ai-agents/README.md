# AI agents

This directory contains the instruction files for AI agents used by the
control-toolbox organization.

## Separation of responsibilities

An agent file defines the agent's persistent behavior: its role, tone, expertise,
expected output, and safety constraints. It is loaded as the system instructions
for an AI provider.

The reusable execution logic lives in
[`CTActions/.github/workflows/ai-agent.yml`](https://github.com/control-toolbox/CTActions/blob/main/.github/workflows/ai-agent.yml).
A package provides a thin caller workflow, such as
[`CTBase/.github/workflows/AIHello.yml`](https://github.com/control-toolbox/CTBase.jl/blob/main/.github/workflows/AIHello.yml).

The caller supplies the concrete `task` for a run. In other words:

```text
ai-agents/<name>.md = persistent system instructions
workflow task       = concrete request for this run
```

## Agent file format

Agent files are Markdown documents. Keep their instructions provider-independent
whenever possible. Provider and model information is supplied at runtime by the
reusable workflow.

A useful agent definition should describe:

- the agent's role and area of expertise;
- the expected language, tone, and response structure;
- the information it should use from the runtime context;
- how it should handle uncertainty;
- secrets and information it must never reveal.

Do not put API keys, tokens, credentials, or other secrets in an agent file.

## Runtime context

The reusable workflow appends runtime context to the system instructions when it
calls the provider. The context currently includes:

- the provider;
- the resolved model;
- the calling repository.

The user-facing `task` is sent separately as the user message. Agents should use
this context and task together, while keeping their persistent instructions
independent of any single repository.

## Adding an agent

1. Create a new Markdown file in this directory, for example:

   ```text
   ai-agents/code-review.md
   ```

2. Define the agent's role and output requirements without embedding secrets.
3. Add or update a thin caller workflow in the consuming repository.
4. Call the reusable CTActions workflow with the agent name and task:

   ```yaml
   jobs:
     call:
       uses: control-toolbox/CTActions/.github/workflows/ai-agent.yml@main
       with:
         provider: albert
         handbook_ref: main
         agent_name: code-review
         model: deepseek
         task: "Summarize the current project and identify its main coding concerns."
       secrets:
         ALBERT_API_KEY: ${{ secrets.ALBERT_API_KEY }}
         HANDBOOK_READ_TOKEN: ${{ secrets.HANDBOOK_READ_TOKEN }}
   ```

5. Test the caller with `workflow_dispatch` or the trigger defined by the
   consuming repository.

## Current example

[`hello.md`](hello.md) is a small smoke-test agent. It uses a playful round-table
introduction, invents a fictional provider-inspired name, presents itself as a
coding specialist, and gives a short overview of the calling project.
