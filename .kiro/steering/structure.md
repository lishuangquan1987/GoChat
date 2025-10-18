# GoChat Project Structure

## Root Directory Layout
```
├── src/
│   ├── client/          # Flutter client application (cross-platform)
│   └── server/
│       └── gochat-server/   # Go backend server
├── img/                 # Documentation images and diagrams
├── plan.md             # Detailed project requirements
└── README.MD           # Project overview and tech stack
```

## Server Architecture (`src/server/gochat-server/`)

### Core Directories
- **`controllers/`** - HTTP request handlers (Gin controllers)
- **`services/`** - Business logic layer
- **`routers/`** - Route definitions and middleware setup
- **`dto/`** - Data Transfer Objects for API requests/responses
- **`ent/`** - Generated ORM code and database schemas
- **`configs/`** - Configuration management
- **`auth_manager/`** - Authentication and authorization logic
- **`ws_manager/`** - WebSocket connection management
- **`msg_send_handler/`** - Message sending logic
- **`msg_recv_handlerr/`** - Message receiving logic (note: typo in folder name)

### Key Files
- **`main.go`** - Application entry point
- **`Config.json`** - Database and server configuration
- **`go.mod`** - Go module dependencies

## Architecture Patterns

### Layered Architecture
1. **Controllers** → Handle HTTP requests, validate input
2. **Services** → Business logic, data processing
3. **Ent/Database** → Data persistence layer

### Naming Conventions
- **Controllers**: `{entity}_controller.go` (e.g., `user_controller.go`)
- **Services**: `{entity}Service.go` (e.g., `userService.go`)
- **DTOs**: Descriptive names (`message.go`, `response.go`)
- **Schemas**: Entity names (`user.go`, `chatrecord.go`)

### Code Organization Rules
- Controllers should be thin - delegate to services
- Services contain business logic and database operations
- DTOs define API contracts and message structures
- Use Ent schemas for database entity definitions
- WebSocket handlers separate from HTTP controllers
- Configuration centralized in `configs/` package

### Database Schema Structure
Entities follow chat application domain:
- **User** - User accounts and profiles
- **ChatRecord** - Private message records
- **GroupChatRecord** - Group message records
- **Group** - Group/channel definitions
- **FriendRelationship** - User friendship connections
- **TextMessage/ImageMessage/VideoMessage** - Message content by type

### API Structure
- Base path: `/api`
- User endpoints: `/api/user/*`
- WebSocket: `/ws`
- RESTful conventions for HTTP endpoints