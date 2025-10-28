# 聊天界面401错误调试

## 问题描述
客户端进入聊天界面时出现HTTP 401错误：
```
DioException [bad response]: This exception was thrown because the response has a status code of 401 and RequestOptions.validateStatus was configured to throw for this status code.
```

## 可能原因分析

### 1. Token过期或无效
- 用户登录后token可能已过期
- Token格式不正确
- Token在存储/读取过程中损坏

### 2. API请求问题
- 聊天历史API (`/api/messages/history`) 需要认证
- 请求头中Authorization字段可能缺失或格式错误

### 3. 服务端认证中间件问题
- 认证中间件可能有bug
- Token解析失败

## 调试步骤

### 步骤1: 检查Token存储
在客户端添加调试代码检查token是否正确存储和读取：

```dart
// 在ChatPage的_loadChatHistory方法开始处添加
final token = await StorageService.getToken();
print('DEBUG: Current token: $token');
if (token == null || token.isEmpty) {
  print('DEBUG: No token found, user may need to re-login');
  return;
}
```

### 步骤2: 检查API请求头
在ApiService的拦截器中添加调试日志：

```dart
onRequest: (options, handler) async {
  final token = await StorageService.getToken();
  print('DEBUG: Token from storage: $token');
  if (token != null) {
    options.headers['Authorization'] = 'Bearer $token';
    print('DEBUG: Added Authorization header: Bearer $token');
  } else {
    print('DEBUG: No token available for request');
  }
  print('DEBUG: Request headers: ${options.headers}');
  return handler.next(options);
},
```

### 步骤3: 检查服务端日志
查看服务端认证中间件的日志输出，确认：
- 是否收到Authorization头
- Token解析是否成功
- 用户ID是否正确提取

### 步骤4: 验证Token有效性
可以通过其他需要认证的API（如获取用户信息）来验证token是否有效。

## 临时解决方案

### 方案1: 强制重新登录
如果token确实无效，可以在401错误时自动跳转到登录页面：

```dart
// 在ApiService的错误拦截器中添加
onError: (error, handler) {
  if (error.response?.statusCode == 401) {
    // 清除无效token并跳转到登录页面
    StorageService.clearAll();
    // 导航到登录页面的逻辑
  }
  return handler.next(error);
},
```

### 方案2: 添加Token刷新机制
如果服务端支持token刷新，可以在401错误时尝试刷新token。

## 下一步行动
1. 添加调试日志确认token状态
2. 检查服务端认证中间件日志
3. 根据调试结果确定具体问题
4. 实施相应的修复方案

## 相关文件
- `src/client/gochat_client/lib/pages/chat_page.dart` - 聊天页面
- `src/client/gochat_client/lib/services/api_service.dart` - API服务
- `src/client/gochat_client/lib/services/storage_service.dart` - 存储服务
- `src/client/gochat_client/lib/providers/user_provider.dart` - 用户状态管理
- `src/server/gochat-server/middlewares/auth_middleware.go` - 服务端认证中间件