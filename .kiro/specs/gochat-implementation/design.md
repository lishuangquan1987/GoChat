# GoChat 系统设计文档

## Overview

GoChat 采用前后端分离的架构设计，后端使用 Go + Gin + WebSocket 提供 RESTful API 和实时通信能力，前端使用 Flutter 实现跨平台客户端。系统通过 PostgreSQL 存储结构化数据，MinIO 存储多媒体文件，Redka 提供缓存支持。

## Architecture

### 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Client                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Login   │  │   Chat   │  │ Friends  │  │  Groups  │   │
│  │   UI     │  │    UI    │  │    UI    │  │    UI    │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│         │              │              │              │      │
│         └──────────────┴──────────────┴──────────────┘      │
│                        │                                     │
│              ┌─────────┴─────────┐                          │
│              │   HTTP Client     │                          │
│              │  WebSocket Client │                          │
│              └─────────┬─────────┘                          │
└────────────────────────┼──────────────────────────────────┘
                         │
                         │ HTTP/WebSocket
                         │
┌────────────────────────┼──────────────────────────────────┐
│                        │      Go Server                    │
│              ┌─────────┴─────────┐                         │
│              │   Gin Router      │                         │
│              └─────────┬─────────┘                         │
│                        │                                    │
│         ┌──────────────┼──────────────┐                    │
│         │              │               │                    │
│  ┌──────▼─────┐ ┌─────▼──────┐ ┌─────▼──────┐            │
│  │ Controllers│ │ WebSocket  │ │   Auth     │            │
│  │            │ │  Manager   │ │  Manager   │            │
│  └──────┬─────┘ └─────┬──────┘ └─────┬──────┘            │
│         │              │               │                    │
│  ┌──────▼──────────────▼───────────────▼──────┐           │
│  │              Services Layer                 │           │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐ │           │
│  │  │   User   │  │ Message  │  │  Group   │ │           │
│  │  │ Service  │  │ Service  │  │ Service  │ │           │
│  │  └──────────┘  └──────────┘  └──────────┘ │           │
│  └──────┬──────────────┬───────────────┬──────┘           │
│         │              │               │                    │
│  ┌──────▼──────────────▼───────────────▼──────┐           │
│  │              Ent ORM Layer                  │           │
│  └──────┬──────────────┬───────────────┬──────┘           │
└─────────┼──────────────┼───────────────┼─────────────────┘
          │              │               │
┌─────────▼────┐  ┌──────▼──────┐  ┌───▼──────┐
│  PostgreSQL  │  │    MinIO    │  │  Redka   │
│   Database   │  │   Storage   │  │  Cache   │
└──────────────┘  └─────────────┘  └──────────┘
```

### 技术栈选型

**后端:**
- Go 1.24+ - 高性能并发处理
- Gin - 轻量级 Web 框架
- Gorilla WebSocket - WebSocket 实现
- Ent - 类型安全的 ORM
- PostgreSQL - 关系型数据库
- MinIO - 对象存储
- Redka - Redis 兼容缓存

**前端:**
- Flutter 3.x - 跨平台 UI 框架
- Dart - 编程语言
- web_socket_channel - WebSocket 客户端
- dio - HTTP 客户端
- provider/riverpod - 状态管理

## Components and Interfaces

### 后端组件

#### 1. Controllers Layer

**UserController**
```go
// 用户注册
POST /api/user/register
Request: { username, password, nickname, sex }
Response: { code, message, data: User }

// 用户登录
POST /api/user/login
Request: { username, password }
Response: { code, message, data: { user: User, token: string } }

// 获取用户信息
GET /api/user/profile
Headers: { Authorization: Bearer <token> }
Response: { code, message, data: User }

// 更新用户信息
PUT /api/user/profile
Headers: { Authorization: Bearer <token> }
Request: { nickname, sex }
Response: { code, message, data: User }
```

**FriendController**
```go
// 获取好友列表
GET /api/friends
Headers: { Authorization: Bearer <token> }
Response: { code, message, data: []User }

// 发送好友请求
POST /api/friends/request
Headers: { Authorization: Bearer <token> }
Request: { friendId, remark }
Response: { code, message }

// 接受好友请求
POST /api/friends/accept
Headers: { Authorization: Bearer <token> }
Request: { requestId }
Response: { code, message }

// 删除好友
DELETE /api/friends/:friendId
Headers: { Authorization: Bearer <token> }
Response: { code, message }
```

**MessageController**
```go
// 发送消息
POST /api/messages/send
Headers: { Authorization: Bearer <token> }
Request: { toUserId, msgType, content, groupId? }
Response: { code, message, data: { msgId } }

// 获取聊天历史
GET /api/messages/history
Headers: { Authorization: Bearer <token> }
Query: { userId?, groupId?, page, pageSize }
Response: { code, message, data: { messages: []Message, total } }

// 上传文件
POST /api/messages/upload
Headers: { Authorization: Bearer <token> }
FormData: { file }
Response: { code, message, data: { url } }
```

**GroupController**
```go
// 创建群组
POST /api/groups
Headers: { Authorization: Bearer <token> }
Request: { groupName, memberIds }
Response: { code, message, data: Group }

// 获取群组列表
GET /api/groups
Headers: { Authorization: Bearer <token> }
Response: { code, message, data: []Group }

// 添加群成员
POST /api/groups/:groupId/members
Headers: { Authorization: Bearer <token> }
Request: { userIds }
Response: { code, message }

// 移除群成员
DELETE /api/groups/:groupId/members/:userId
Headers: { Authorization: Bearer <token> }
Response: { code, message }
```

#### 2. WebSocket Manager

**连接管理**
```go
type WSManager struct {
    connections map[string]*websocket.Conn  // userId -> connection
    mu          sync.RWMutex
}

// 建立连接
GET /ws?userId=<userId>&token=<token>

// 消息格式
type WSMessage struct {
    Type    string      `json:"type"`    // "message", "notification", "heartbeat"
    Data    interface{} `json:"data"`
    Time    int64       `json:"time"`
}
```

#### 3. Services Layer

**UserService**
```go
func Register(username, password, nickname string, sex int) (*ent.User, error)
func Login(username, password string) (*ent.User, string, error)
func GetUserByID(userId int) (*ent.User, error)
func UpdateUser(userId int, nickname string, sex int) (*ent.User, error)
func GenerateToken(userId int) (string, error)
func ValidateToken(token string) (int, error)
```

**MessageService**
```go
func SendMessage(fromUserId, toUserId int, msgType int, content string, groupId *int) (string, error)
func GetChatHistory(userId, friendId int, page, pageSize int) ([]Message, int, error)
func GetGroupChatHistory(groupId, page, pageSize int) ([]Message, int, error)
func GetOfflineMessages(userId int) ([]Message, error)
func MarkMessageAsDelivered(msgId string) error
```

**GroupService**
```go
func CreateGroup(groupName string, ownerId int, memberIds []int) (*ent.Group, error)
func GetUserGroups(userId int) ([]*ent.Group, error)
func AddGroupMembers(groupId int, userIds []int) error
func RemoveGroupMember(groupId, userId int) error
func GetGroupMembers(groupId int) ([]*ent.User, error)
```

**FriendService**
```go
func SendFriendRequest(userId, friendId int, remark string) error
func AcceptFriendRequest(requestId int) error
func RejectFriendRequest(requestId int) error
func GetFriendList(userId int) ([]*ent.User, error)
func DeleteFriend(userId, friendId int) error
```

**FileService**
```go
func UploadFile(file multipart.File, fileType string) (string, error)
func GetFileURL(fileId string) (string, error)
func DeleteFile(fileId string) error
```

### 前端组件

#### 1. 状态管理

```dart
// 用户状态
class UserState {
  User? currentUser;
  String? token;
  bool isLoggedIn;
}

// 聊天状态
class ChatState {
  List<Conversation> conversations;
  Map<String, List<Message>> messages;
  WebSocketChannel? wsChannel;
}

// 好友状态
class FriendState {
  List<User> friends;
  List<FriendRequest> requests;
}

// 群组状态
class GroupState {
  List<Group> groups;
  Map<String, List<User>> groupMembers;
}
```

#### 2. 服务层

```dart
// API 服务
class ApiService {
  Future<Response> register(String username, String password, String nickname);
  Future<Response> login(String username, String password);
  Future<Response> sendMessage(Message message);
  Future<Response> getChatHistory(String userId, int page);
  Future<Response> uploadFile(File file);
}

// WebSocket 服务
class WebSocketService {
  void connect(String userId, String token);
  void disconnect();
  Stream<WSMessage> get messageStream;
  void sendMessage(WSMessage message);
}

// 存储服务
class StorageService {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> saveUser(User user);
  Future<User?> getUser();
}
```

#### 3. UI 组件

```dart
// 登录页面
class LoginPage extends StatefulWidget

// 聊天列表页面
class ChatListPage extends StatefulWidget

// 聊天页面
class ChatPage extends StatefulWidget

// 好友列表页面
class FriendListPage extends StatefulWidget

// 群组列表页面
class GroupListPage extends StatefulWidget

// 个人信息页面
class ProfilePage extends StatefulWidget
```

## Data Models

### 数据库 Schema (已存在)

基于现有的 Ent schema，数据模型已定义：

- User - 用户信息
- ChatRecord - 私聊记录
- GroupChatRecord - 群聊记录
- Group - 群组信息
- FriendRelationship - 好友关系
- TextMessage - 文本消息
- ImageMessage - 图片消息
- VideoMessage - 视频消息

### 新增 Schema

**FriendRequest** - 好友请求
```go
type FriendRequest struct {
    ent.Schema
}

func (FriendRequest) Fields() []ent.Field {
    return []ent.Field{
        field.Int("fromUserId").Comment("发送者ID"),
        field.Int("toUserId").Comment("接收者ID"),
        field.String("remark").Optional().Comment("备注"),
        field.Int("status").Default(0).Comment("状态: 0-待处理, 1-已接受, 2-已拒绝"),
        field.Time("createTime").Default(time.Now).Comment("创建时间"),
    }
}
```

**MessageStatus** - 消息状态
```go
type MessageStatus struct {
    ent.Schema
}

func (MessageStatus) Fields() []ent.Field {
    return []ent.Field{
        field.String("msgId").Comment("消息ID"),
        field.Int("userId").Comment("用户ID"),
        field.Bool("isDelivered").Default(false).Comment("是否已送达"),
        field.Bool("isRead").Default(false).Comment("是否已读"),
        field.Time("deliveredTime").Optional().Comment("送达时间"),
        field.Time("readTime").Optional().Comment("已读时间"),
    }
}
```

### Flutter 数据模型

```dart
class User {
  final int id;
  final String username;
  final String nickname;
  final int sex;
  final String? avatar;
}

class Message {
  final String msgId;
  final int fromUserId;
  final int toUserId;
  final int msgType;
  final String content;
  final int? groupId;
  final DateTime time;
  final MessageStatus status;
}

class Conversation {
  final String id;
  final ConversationType type;  // private or group
  final User? user;
  final Group? group;
  final Message? lastMessage;
  final int unreadCount;
}

class Group {
  final int id;
  final String groupId;
  final String groupName;
  final int ownerId;
  final List<int> memberIds;
  final DateTime createTime;
}
```

## Error Handling

### 后端错误处理

```go
// 统一错误响应格式
type ErrorResponse struct {
    Code    int    `json:"code"`
    Message string `json:"message"`
}

// 错误码定义
const (
    ErrCodeSuccess          = 0
    ErrCodeInvalidParam     = 400
    ErrCodeUnauthorized     = 401
    ErrCodeForbidden        = 403
    ErrCodeNotFound         = 404
    ErrCodeInternalError    = 500
    ErrCodeDatabaseError    = 501
    ErrCodeWebSocketError   = 502
)

// 中间件处理 panic
func RecoveryMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        defer func() {
            if err := recover(); err != nil {
                c.JSON(500, ErrorResponse{
                    Code:    ErrCodeInternalError,
                    Message: "Internal server error",
                })
            }
        }()
        c.Next()
    }
}
```

### 前端错误处理

```dart
class ApiException implements Exception {
  final int code;
  final String message;
  
  ApiException(this.code, this.message);
}

// 统一错误处理
Future<T> handleApiCall<T>(Future<T> Function() apiCall) async {
  try {
    return await apiCall();
  } on DioError catch (e) {
    if (e.response != null) {
      throw ApiException(
        e.response!.data['code'],
        e.response!.data['message'],
      );
    }
    throw ApiException(500, 'Network error');
  }
}
```

## Testing Strategy

### 后端测试

**单元测试**
- Services 层业务逻辑测试
- 工具函数测试
- 数据验证测试

**集成测试**
- API 端点测试
- WebSocket 连接测试
- 数据库操作测试

**测试工具**
```go
import (
    "testing"
    "github.com/stretchr/testify/assert"
)
```

### 前端测试

**单元测试**
- 状态管理测试
- 工具函数测试
- 数据模型测试

**Widget 测试**
- UI 组件测试
- 交互测试

**集成测试**
- 端到端流程测试

**测试工具**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
```

## Security Considerations

### 认证与授权

1. **密码加密**: 使用 bcrypt 加密存储密码
2. **Token 机制**: JWT token 用于身份验证
3. **Token 过期**: 设置合理的过期时间（如 7 天）
4. **HTTPS**: 生产环境强制使用 HTTPS

### 数据安全

1. **SQL 注入防护**: 使用 Ent ORM 参数化查询
2. **XSS 防护**: 前端输入验证和转义
3. **文件上传安全**: 验证文件类型和大小
4. **敏感信息**: 不在日志中记录密码等敏感信息

### WebSocket 安全

1. **连接验证**: 建立连接时验证 token
2. **消息验证**: 验证消息发送者身份
3. **频率限制**: 防止消息轰炸

## Performance Optimization

### 后端优化

1. **连接池**: 数据库连接池配置
2. **缓存策略**: 使用 Redka 缓存热点数据
3. **消息队列**: 异步处理离线消息推送
4. **索引优化**: 数据库索引优化查询性能

### 前端优化

1. **懒加载**: 聊天记录分页加载
2. **图片缓存**: 使用 cached_network_image
3. **状态管理**: 避免不必要的 rebuild
4. **本地存储**: 缓存常用数据减少网络请求

## Deployment

### 后端部署

```bash
# 构建
go build -o gochat-server main.go

# Docker 部署
docker build -t gochat-server .
docker run -p 8080:8080 gochat-server

# 环境变量
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=password
DB_NAME=gochat
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
```

### 前端部署

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```
