# 错误处理和日志系统测试指南

## 测试目的
验证统一错误处理和日志记录系统是否正常工作。

## 测试步骤

### 1. 启动服务器
```bash
cd src/server/gochat-server
go run main.go
```

观察启动日志，应该看到：
```
[INFO] GoChat Server starting...
[INFO] MinIO initialized successfully
[INFO] Server starting on port 8080
```

### 2. 测试正常请求日志

发送一个正常的注册请求：
```bash
curl -X POST http://localhost:8080/api/user/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"123456","nickname":"测试用户"}'
```

服务器日志应该显示：
```
[INFO] 2024/01/15 10:30:45 | 200 |      15.234ms |     127.0.0.1 | POST    /api/user/register | Size: 123
```

### 3. 测试错误请求日志

发送一个缺少参数的请求：
```bash
curl -X POST http://localhost:8080/api/user/register \
  -H "Content-Type: application/json" \
  -d '{}'
```

服务器日志应该显示：
```
[ERROR] 2024/01/15 10:30:45 | 400 |      5.123ms |     127.0.0.1 | POST    /api/user/register | Size: 89 | UA: curl/7.68.0
  └─ Errors: 参数错误
```

响应应该是：
```json
{
  "code": 400,
  "message": "参数错误"
}
```

### 4. 测试未授权错误

访问需要认证的接口但不提供token：
```bash
curl -X GET http://localhost:8080/api/user/profile
```

响应应该是：
```json
{
  "code": 401,
  "message": "未授权"
}
```

### 5. 测试CORS

从浏览器发送跨域请求，应该能正常访问。

### 6. 测试Recovery中间件

如果代码中有panic，应该被捕获并记录详细信息，而不是导致服务器崩溃。

## 验证清单

- [x] 服务器启动日志正常
- [x] 正常请求日志格式正确
- [x] 错误请求日志包含详细信息
- [x] 统一错误响应格式正确
- [x] 错误码定义完整
- [x] CORS中间件工作正常
- [x] Recovery中间件能捕获panic
- [x] 日志包含必要的请求信息（IP、耗时、状态码等）

## 预期结果

所有中间件应该按以下顺序执行：
1. RecoveryMiddleware - 捕获panic
2. CORSMiddleware - 处理跨域
3. LoggerMiddleware - 记录请求日志
4. AuthMiddleware - 验证身份（需要认证的路由）

所有错误响应应该使用统一的格式，包含正确的错误码和消息。

所有请求都应该被记录，包括请求方法、路径、IP、状态码、耗时等信息。
