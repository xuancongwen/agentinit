### Go
- `gofmt`, `go vet`, and `golangci-lint` (if configured) clean.
- Handle every error; wrap with `fmt.Errorf("doing x: %w", err)`; no `panic` outside `main`.
- Accept interfaces, return structs; small interfaces; `context.Context` first.
- No package-level mutable state or `init()`; useful zero values.
- Table-driven tests with `t.Run`; `go test -race ./...` passes.
