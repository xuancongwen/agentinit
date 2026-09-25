### Kotlin
- ktlint and detekt clean. No `!!`: use `?.`, `?:`, or `requireNotNull` with a message.
- `val` over `var`; data classes, sealed classes for state, exhaustive `when`.
- Structured concurrency; never `GlobalScope`; suspend functions over callbacks.
- Tests: JUnit 5 or Kotest with MockK.
