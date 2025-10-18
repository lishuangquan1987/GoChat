# GoChat 错误处理和日志系统文档

## 概述

本文档描述了 GoChat 服务器的统一错误处理和日志记录系统。

## 错误码定义

### 成功码
- `0` - 操作成功

### 客户端错误 (400-499)
- `400` - 参数错误 (CodeInvalidParam)
- `401` - 未授权 (CodeUnauthorized)
- `403` - 禁止访问 (CodeForbidden)
- `404` - 资源不存在 (CodeNotFound)
- `409` - 资源冲突 (CodeConflict)
- `422` - 验证失败 (CodeValidationFailed)

### 服务器错误 (500-599)
- `500` - 服务器内部错误 (CodeInternalError)
- `501` - 数据库错误 (CodeDatabaseError)
- `502` - WebSocket错误 (CodeWebSocketError)
- `503` - 文件操作错误 (CodeFileError)
- `504` - 缓存错误 (CodeCacheError)

## 统一响应格式

### 成功响应
```json
{
  "code": 0,
  "message": "success",
  "data": {
    // 响应数据
  }
}
```

### 错误响应
```json
{
  "code": 400,
  "message": "参数错误",
  "error": "详细错误信息（可选）"
}
```

## 使用方法

### 1. 在 Controller 中返回响应

```go
import (
    "gochat_server/utils"
    "github.com/gin-gonic/gin"
)

func SomeController(c *gin.Context) {
    // 成功响应
    data := map[string]interface{}{
        "userId": 123,
        "username": "test",
    }
    utils.RespondSuccess(c, data)

    // 错误响应 - 使用预定义方法
    utils.RespondBadRequest(c, "参数不能为空")
    utils.RespondUnauthorized(c, "未登录")
    utils.RespondNotFound(c, "用户不存在")
    utils.RespondConflict(c, "用户名已存在")
    utils.RespondInternalError(c, "服务器错误")

    // 错误响应 - 使用自定义错误
    err := utils.NewInvalidParamError("用户名格式不正确")
    utils.RespondError(c, err)
}
```

### 2. 在 Service 中抛出错误

```go
import "gochat_server/utils"

func SomeService() error {
    // 参数错误
    return utils.NewInvalidParamError("参数不能为空")

    // 未授权
    return utils.NewUnauthorizedError("token已过期")

    // 资源不存在
    return utils.NewNotFoundError("用户不存在")

    // 资源冲突
    return utils.NewConflictError("用户名已存在")

    // 数据库错误
    return utils.NewDatabaseError(err)

    // 内部错误
    return utils.NewInternalError(err)

    // 文件错误
    return utils.NewFileError(err)
}
```

### 3. 日志记录

```go
import "gochat_server/utils"

// 不同级别的日志
utils.Debug("调试信息: %s", debugInfo)
utils.Info("信息日志: %s", info)
utils.Warn("警告: %s", warning)
utils.Error("错误: %v", err)
utils.Fatal("致命错误: %v", err) // 会退出程序

// 专用日志方法
utils.LogRequest("GET", "/api/users", "127.0.0.1", 200, time.Second)
utils.LogError("数据库操作", err)
utils.LogWebSocket("CONNECT", 123, "连接成功")
utils.LogDatabase("SELECT", "users", time.Millisecond*100, nil)
```

### 4. 初始化日志系统

在 `main.go` 中：

```go
import "gochat_server/utils"

func main() {
    // 初始化日志（可选配置日志目录和级别）
    // err := utils.InitLogger("logs", utils.INFO)
    // if err != nil {
    //     log.Fatal(err)
    // }
    // defer utils.CloseLogger()

    // 使用默认配置（输出到标准输出）
    utils.Info("Server starting...")
}
```

## 中间件

### 1. Recovery 中间件
自动捕获 panic 并记录详细的错误信息和堆栈跟踪。

### 2. Logger 中间件
记录所有 HTTP 请求的详细信息：
- 请求方法和路径
- 客户端IP
- 响应状态码
- 请求耗时
- 响应大小
- User-Agent（错误请求）
- 错误信息（如果有）

### 3. CORS 中间件
处理跨域请求。

### 4. Auth 中间件
验证用户身份，自动处理认证错误。

## 日志格式

### 正常请求
```
[INFO] 2024/01/15 10:30:45 | 200 |      15.234ms |     192.168.1.1 | GET     /api/users | Size: 1234
```

### 错误请求
```
[ERROR] 2024/01/15 10:30:45 | 400 |      10.123ms |     192.168.1.1 | POST    /api/login | Size: 89 | UA: Mozilla/5.0...
  └─ Errors: 参数错误
```

### Panic 恢复
```
[PANIC RECOVERED] 2024/01/15 10:30:45
Request: POST /api/users
Client IP: 192.168.1.1
User-Agent: Mozilla/5.0...
Error: runtime error: invalid memory address
Stack Trace:
goroutine 1 [running]:
...
```

## 最佳实践

1. **统一使用错误码**：不要在代码中硬编码错误码，使用 `dto` 包中定义的常量。

2. **使用响应助手函数**：在 Controller 中使用 `utils.RespondXxx` 系列函数返回响应。

3. **Service 层返回错误**：Service 层应该返回 `*AppError` 类型的错误，让 Controller 层统一处理。

4. **记录关键操作**：使用日志记录关键操作，便于问题排查。

5. **不要暴露敏感信息**：错误消息中不要包含数据库结构、内部路径等敏感信息。

6. **使用结构化日志**：使用 `utils.LogXxx` 系列函数记录结构化日志。

## 示例

### 完整的 Controller 示例

```go
package controllers

import (
    "gochat_server/services"
    "gochat_server/utils"
    "github.com/gin-gonic/gin"
)

func GetUser(c *gin.Context) {
    userId := c.Param("userId")
    
    // 参数验证
    if userId == "" {
        utils.RespondBadRequest(c, "用户ID不能为空")
        return
    }

    // 调用 Service
    user, err := services.GetUserById(userId)
    if err != nil {
        // 统一错误处理
        utils.RespondError(c, err)
        return
    }

    // 返回成功响应
    utils.RespondSuccess(c, user)
}
```

### 完整的 Service 示例

```go
package services

import (
    "gochat_server/utils"
)

func GetUserById(userId string) (*User, error) {
    // 查询数据库
    user, err := db.User.Get(userId)
    if err != nil {
        utils.LogError("查询用户失败", err)
        return nil, utils.NewDatabaseError(err)
    }

    if user == nil {
        return nil, utils.NewNotFoundError("用户不存在")
    }

    return user, nil
}
```
