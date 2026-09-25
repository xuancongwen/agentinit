### TypeScript
- `strict: true`. No `any` (use `unknown` and narrow); no `!` or `as` without a justifying comment.
- Discriminated unions over optional fields; `readonly` where possible; derive types (`typeof`, `satisfies`, `as const`) rather than duplicate.
- Union literals over enums; export types beside the values they describe.
- Otherwise as JavaScript: ES modules, `const` by default, `async`/`await` with every rejection handled, Prettier and ESLint clean.
