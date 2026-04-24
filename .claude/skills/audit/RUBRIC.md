# Audit Rubric

Every finding from the `audit` skill cites one dimension below and one severity. Findings that don't fit a dimension are out of scope.

Severity gate for the pre-commit hook: blocks on `blockers ≥ 1` or `majors ≥ 3`. Minors warn only.

## Dimensions

### D1. Correctness

Does the code do what the spec says? Requires a spec in `design/` — if missing, `audit` notes this and scopes correctness findings to obvious bugs only.

- **Blocker:** produces wrong output on a documented input; crashes on a documented flow.
- **Major:** documented edge case unhandled; silent failure where an error is expected.
- **Minor:** off-by-one or boundary issue in a non-critical path.

### D2. Love2D API

Uses current, valid Love2D APIs for the version in `.love-version`.

- **Blocker:** calls a removed or renamed API (code will not run).
- **Major:** uses a deprecated API flagged for removal in the next major version.
- **Minor:** uses an inefficient-but-valid API where a better one exists (e.g. `love.graphics.print` in a hot path instead of a `Text` object).

### D3. Lua idioms

Local over global; single-assignment where possible; correct `pairs` vs. `ipairs`; no accidental globals.

- **Blocker:** accidental global in a hot path (will cause runtime lookups every frame).
- **Major:** missing `local` on a loop variable or inner function; `ipairs` on a sparse table.
- **Minor:** stylistic drift (naming, spacing) from the rest of the module.

### D4. Performance

No allocations in `love.update` or `love.draw` hot paths. No per-frame string concatenation, table construction, or closure creation.

- **Blocker:** table allocation per frame in a hot path (e.g. `{x=x, y=y}` inside `update`).
- **Major:** repeated string concat per frame; closure created per frame.
- **Minor:** cacheable computation not cached (e.g. `math.rad(45)` every frame).

### D5. Coupling

Modules depend on interfaces, not internals. Two modules shouldn't reach into each other's tables.

- **Blocker:** cross-module reach-in that breaks on any rename (`OtherModule._private.field`).
- **Major:** circular require; module import chain that requires specific load order.
- **Minor:** function takes more than ~5 positional parameters where a table would be clearer.

### D6. Naming

Names tell a reader what something is and why it exists.

- **Blocker:** misleading name (function named `getX` that mutates state).
- **Major:** ambiguous abbreviation in a public API (`proc`, `mgr`, `util` in an exported name).
- **Minor:** inconsistent casing vs. sibling code (`snake_case` next to `camelCase` with no reason).

### D7. Testability

Pure where possible; side effects isolated at module edges.

- **Blocker:** business logic directly inside `love.draw` or `love.update` with no seam to test it.
- **Major:** state-mutating helper that can't be driven from a test without also initializing Love2D.
- **Minor:** test seam missing where the pattern elsewhere in the codebase would have one.

### D8. Feel

Does the change match what recent playtest notes flagged? `audit` reads `playtests/` and weights findings in code adjacent to reported feel issues.

- **Blocker:** a playtest-flagged bug is still present in the diff's scope.
- **Major:** a playtest-flagged concern touches code being modified, but the diff doesn't address it.
- **Minor:** not used — feel findings are either blocking or worth naming explicitly.

## Exit trailer

Every `audit` run prints exactly one line at the end:

```
AUDIT_RESULT: blockers=<N> majors=<N> minors=<N>
```

The pre-commit hook greps for this line. If missing, the hook treats the audit as failed.
