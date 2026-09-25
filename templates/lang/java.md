### Java
- Java 17+ per project. Formatted and checked by Spotless or Checkstyle; zero warnings.
- Immutability first: `final` fields, records for data, `Optional` only as a return type.
- Interfaces and composition over inheritance; unchecked exceptions in new APIs; never swallow an exception.
- Streams for transformations, loops for side effects; try-with-resources for every `AutoCloseable`.
- Tests: JUnit 5 with AssertJ; `mvn verify` or `gradle check` must pass.
