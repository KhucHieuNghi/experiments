<div align="center">
  <h1>ETUS</h1>
  <p>The self-improving Agentic QA harness with Memory.</p>
</div>

## ETUS

ETUS helps teams write tests in natural language for web and mobile products. It learns from past runs, adapts when UI changes, and gives developers a reviewable dashboard for triage.

## Features

- **Natural-language checks**: Define actions and assertions in human language while the harness works from visible roles, labels, and screen state.
- **Self-healing execution**: When a sub-action such as click, fill, or select fails, ETUS re-observes the UI and tries a different path in the same run.
- **Memory-aware runs**: ETUS builds execution memory from product, suite, and test observations, then adds that context to future runs.
- **Human and agent workflows**: Developers use the dashboard and CLI; coding agents use the local tool surface and schema-aware skills.
- **Smart cache**: The action cache reuses validated plans across similar runs to reduce planner work, token usage, and runtime overhead.
- **Sandboxed hooks**: Node, Bun, Python, and Bash hooks can prepare state, call APIs, seed fixtures, tear down state, and pass structured outputs back into a run.

## Quickstart

Install dependencies, initialize a project, install browser or mobile runtime support, then open the dashboard. The current technical CLI/package compatibility names are preserved in source code and package metadata so existing workflows continue to run.

## Docs

- [Product and business onboarding](docs/onboarding/product-business.md)
- [Technical architecture onboarding](docs/onboarding/technical-architecture.md)
- [License](LICENSE.md)
- [Notice](NOTICE.md)
