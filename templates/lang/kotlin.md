### Kotlin
- Kotlin coding conventions; ktlint and detekt clean. No `!!`: use `?.`, `?:`, or `requireNotNull` with a message.
- `val` over `var`; data classes for data, sealed classes for state, exhaustive `when`.
- Coroutines with structured concurrency; never `GlobalScope`; suspend functions over callbacks.
- Tests: JUnit 5 or Kotest with MockK.
