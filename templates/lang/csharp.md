### C#
- Current LTS .NET; `dotnet format` clean; nullable enabled with all warnings fixed.
- `async` end to end, `Async` suffix, `CancellationToken`; never `.Result` or `.Wait()`.
- Records for data, `IReadOnly*` in public APIs, `using` declarations for `IDisposable`.
- Constructor injection; LINQ for queries, loops for side effects.
- Tests: xUnit with FluentAssertions; `dotnet test` passes.
