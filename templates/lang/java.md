### Java
- Java 17+; Spotless or Checkstyle clean, zero warnings.
- `final` fields, records for data, `Optional` only as a return type.
- Composition over inheritance; unchecked exceptions in new APIs; never swallow one.
- Streams for transforms, loops for side effects; try-with-resources for every `AutoCloseable`.
- Tests: JUnit 5 with AssertJ; `mvn verify` or `gradle check` passes.
