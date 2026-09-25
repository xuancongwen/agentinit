### TypeScript
- `strict: true`. No `any` (use `unknown` and narrow); no non-null `!` or `as` casts without a justifying comment.
- Discriminated unions over optional fields; `readonly` where possible; derive types (`typeof`, `satisfies`, `as const`) instead of duplicating.
- Export types alongside the values they describe; avoid enums in favor of union literals.
- Otherwise as JavaScript: ES modules, `const` by default, `async`/`await` with every rejection handled, Prettier and ESLint clean.
