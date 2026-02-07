# Stage 1: Build the Go binary
FROM golang:1.25-alpine AS builder

WORKDIR /build

# Copy dependency files first for layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary with build info
ARG VERSION=dev
ARG COMMIT_HASH=unknown
ARG BUILD_TIME=unknown

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags "\
        -X main.version=${VERSION} \
        -X main.commitHash=${COMMIT_HASH} \
        -X main.buildTime=${BUILD_TIME} \
        -s -w" \
    -o /build/bin/server ./cmd/server

# Stage 2: Minimal runtime image
FROM alpine:3.21

# Install ca-certificates for TLS connections (IMAP, SMTP, Ollama)
RUN apk --no-cache add ca-certificates tzdata

# Create non-root user
RUN adduser -D -u 1000 app

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /build/bin/server /app/server

# Use non-root user
USER app

EXPOSE 8080

ENTRYPOINT ["/app/server"]
