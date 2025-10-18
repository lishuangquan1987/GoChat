# GoChat Technology Stack

## Backend Stack
- **Language**: Go 1.24+
- **Web Framework**: Gin (HTTP routing and middleware)
- **WebSocket**: Gorilla WebSocket for real-time communication
- **ORM**: Ent (Facebook's Entity Framework for Go)
- **Database**: PostgreSQL (primary), with support for MySQL and SQLite3
- **Cache**: Redka (Redis-compatible)
- **File Storage**: MinIO for multimedia content
- **Configuration**: Viper for config management

## Frontend Stack
- **Cross-Platform Client**: Flutter (Dart) - supports desktop (Windows/macOS/Linux), mobile (Android/iOS), and web
- **Alternative Option**: C# + Avalonia UI (desktop) + .NET MAUI (mobile) - requires maintaining two codebases

## Communication Protocols
- **HTTP/REST**: User management, message sending, file uploads
- **WebSocket**: Real-time message delivery and presence

## Development Dependencies
Key Go modules:
- `github.com/gin-gonic/gin` - Web framework
- `github.com/gorilla/websocket` - WebSocket support
- `entgo.io/ent` - ORM and code generation
- `github.com/lib/pq` - PostgreSQL driver
- `github.com/nalgeon/redka` - Redis-compatible cache
- `github.com/spf13/viper` - Configuration management

## Common Commands

### Server Development
```bash
# Navigate to server directory
cd src/server/gochat-server

# Install dependencies
go mod tidy

# Generate Ent code (after schema changes)
go generate ./ent

# Run the server
go run main.go

# Build for production
go build -o gochat-server main.go
```

### Database Operations
```bash
# Run migrations (if using Ent migrations)
go run -mod=mod entgo.io/ent/cmd/ent migrate apply

# Generate new migration
go run -mod=mod entgo.io/ent/cmd/ent migrate diff
```

## Configuration
- Server config: `Config.json` in server root
- Default port: 8080
- WebSocket endpoint: `/ws`
- API prefix: `/api`