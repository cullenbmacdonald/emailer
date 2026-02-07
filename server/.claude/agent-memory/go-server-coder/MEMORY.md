# Go Server Coder Memory

## Architecture Patterns
- **Server struct** holds store interfaces (EmailStore, ClassificationStore, etc.) for DI
- **NewServer** accepts variadic `ServerDeps` to avoid breaking existing callers
- Routes conditionally registered based on whether stores are non-nil
- Tests use mock stores with function fields (e.g., `listFn`, `getFn`)
- `authReq()` helper creates authenticated test requests

## Storage Layer
- Stores are concrete structs wrapping `*pgxpool.Pool` (e.g., `storage.EmailStore`)
- API layer defines interfaces matching the storage methods it needs
- `pgx.ErrNoRows` is the canonical "not found" sentinel

## Pre-existing Lint Issues
- `make lint` has 4 pre-existing issues (goconst, gofmt in imap/, noctx in cmd/server)
- Use `golangci-lint run ./internal/api/` to verify only your package is clean

## Key Files
- `/server/internal/api/store.go` — storage interfaces for handler DI
- `/server/internal/api/emails.go` — list, get, update, delete handlers
- `/server/internal/api/reclassify.go` — classification override handler
- `/server/internal/api/snooze.go` — snooze/unsnooze handlers
- `/server/internal/api/accounts.go` — account list/detail handlers
- `/server/internal/storage/accounts.go` — account DB queries
