# DevRecipe roadmap

> Documentation type: explanation. This page lists conditions for future scope. For shipped behavior, see the [project overview](../README.md), [preflight and review reference](preflight-and-review.md), [status and narrow removal reference](status-and-removal.md), and [acceptance checks](../tests/acceptance/README.md).

## Admission criteria

Any expansion needs an explicit scope decision, a safety contract, provider-specific acceptance coverage, and updated documentation.

## Candidate expansions

- Discover provider updates from the selected manifest, then validate proposed updates interactively.
- Discover declared entries for removal, then validate proposed removals interactively.

These ideas do not change the current boundary. DevRecipe has no provider-wide update, automatic cleanup, ownership database, or universal rollback.
