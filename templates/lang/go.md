### Go
- `gofmt`/`goimports` and `go vet` clean; `golangci-lint` if configured.
- Handle every error; wrap with `fmt.Errorf("doing x: %w", err)`; no `panic` outside `main` and init.
- Accept interfaces, return structs; keep interfaces small; `context.Context` is the first parameter.
- No package-level mutable state; zero values should be useful; avoid `init()`.
- Table-driven tests with `t.Run`; `go test -race ./...` must pass.
