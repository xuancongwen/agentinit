### C#
- Current LTS .NET. `dotnet format` clean; nullable reference types enabled with all warnings fixed.
- `async` end-to-end with `Async` suffix and `CancellationToken`; never `.Result` or `.Wait()`.
- Records for data, `IReadOnly*` collections in public APIs, `using` declarations for `IDisposable`.
- Constructor injection; LINQ for queries, loops for side effects.
- Tests: xUnit with FluentAssertions; `dotnet test` must pass.
