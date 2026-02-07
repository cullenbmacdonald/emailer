# Go Server Coder - Agent Memory

## Project Layout
- ALL server code lives under `server/` subdirectory (monorepo with clients/ and docs/)
- Worktree at `/Users/cullen/dev/emailer-server`, branch `server/foundation`
- Module: `github.com/cullenbmacdonald/emailer`
- Go 1.25.4, golangci-lint 2.6.2

## golangci-lint v2 Config
- Config file requires `version: "2"` at the top
- `gofmt` is a **formatter only** in v2, NOT a linter. Put it under `formatters.enable`, not `linters.enable`
- Use `linters.default: standard` for the default linter set
- Config file is `.golangci.yml` (not `.golangci.yaml`)

## Build Notes
- `CGO_ENABLED=0` produces static binary
- Build info injected via ldflags: `main.version`, `main.commitHash`, `main.buildTime`
- `make build` outputs to `bin/server`
- Always run `go build` with `-o` flag to avoid stray binaries in cwd

## Common Lint Fixes
- `errcheck`: Use `_, _ = fmt.Fprintf(...)` to explicitly discard write errors on http.ResponseWriter
- `gocritic/exitAfterDefer`: Don't use `defer cancel()` before `os.Exit()`. Call cancel() explicitly.
- `goconst`: When extracting a constant, be careful with `replace_all` — it can replace the string inside its own declaration, creating self-referencing constants like `const x = x`
- Always run `gofmt -s -w .` before committing to fix alignment

## Chi Router Notes
- Chi's `NotFound` handler bypasses subrouter middleware — use `HandleFunc("/*")` catch-all instead to ensure middleware (like auth) runs for non-existent routes
- Empty chi route groups (no registered routes) won't trigger middleware for requests

## Task Progress
- S-1.1: DONE (project scaffolding, config, main.go, Makefile)
- S-1.2: DONE (Docker Compose, Dockerfile, Caddyfile)
- S-1.3: DONE (pgxpool connection, embedded SQL migrations, migrationFS interface)
- S-1.4: DONE (001_initial.sql — 10 tables, 14 indexes)
- S-1.5: DONE (002_full_text_search.sql — tsvector, GIN index)
- S-1.6: DONE (13 model files, 24 tests)
- S-1.7: DONE (chi router, middleware, health endpoint, 13 tests)
- S-1.8: DONE (EmailStore CRUD, view-based listing, cursor pagination, 25 tests)
- S-1.9: DONE (7 storage files + 7 test files: classifications, snooze, recommendations, digests, vip, sender_stats, search — 42 integration tests)
- **Phase 1 Foundation COMPLETE** (S-1.1 through S-1.9)

## Config Env Var Overrides
- EMAILER_PORT, EMAILER_AUTH_TOKEN, EMAILER_DB_DSN, EMAILER_LLM_PROVIDER
- EMAILER_ANTHROPIC_API_KEY, EMAILER_OPENAI_API_KEY, EMAILER_LOG_LEVEL
