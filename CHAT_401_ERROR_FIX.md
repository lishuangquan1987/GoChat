# 聊天界面401错误修复

## 问题描述
客户端进入聊天界面时出现HTTP 401认证错误，导致无法加载聊天历史记录。

## 根本原因
1. **Token过期或无效**：用户的认证token可能已过期或在存储过程中损坏
2. **认证流程问题**：API请求时token未正确传递给服务端
3. **服务端认证中间件**：严格验证token有效性

## 修复措施

### 1. 添加调试日志
在API服务和聊天页面添加详细的调试日志：

**API服务调试** (`src/client/gochat_client/lib/services/api_service.dart`):
```dart
onRequest: (options, handler) async {
  final token = await StorageService.getToken();
  print('DEBUG API: Token from storage: $token');
  if (token != null) {
    options.headers['Authorization'] = 'Bearer $token';
    print('DEBUG API: Added Authorization header');
  } else {
    print('DEBUG API: No token available for request to ${options.path}');
  }
  print('DEBUG API: Request headers: ${options.headers}');
  return handler.next(options);
},
```

**聊天页面调试** (`src/client/gochat_client/lib/pages/chat_page.dart`):
```dart
// 在_loadChatHistory方法开始处检查token
final token = await StorageService.getToken();
print('DEBUG CHAT: Current token: $token');
if (token == null || token.isEmpty) {
  print('DEBUG CHAT: No token found, user may need to re-login');
  // 显示错误提示并返回
  return;
}
```

### 2. 改进错误处理
**自动清理无效Token**:
```dart
onError: (error, handler) async {
  if (error.response?.statusCode == 401) {
    print('DEBUG API: 401 Unauthorized - Token may be invalid or expired');
    // 清除无效的token
    await StorageService.deleteToken();
    print('DEBUG API: Cleared invalid token');
  }
  return handler.next(error);
},
```

**用户友好的错误提示**:
```dart
if (e.toString().contains('401')) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('认证已过期，请重新登录'),
      backgroundColor: Colors.red,
    ),
  );
}
```

### 3. 预防性检查
在聊天页面加载前检查token有效性，如果token缺失则提前返回并提示用户。

## 测试步骤

### 1. 启动应用并登录
- 确保服务器运行在端口8080
- 使用有效账号登录应用
- 观察控制台输出的调试信息

### 2. 进入聊天界面
- 点击任意聊天会话
- 观察调试日志输出：
  - Token是否正确读取
  - Authorization头是否正确设置
  - API请求是否成功

### 3. 验证错误处理
- 如果仍出现401错误，检查：
  - Token格式是否正确 (Bearer + 空格 + token)
  - 服务端认证中间件日志
  - Token是否已过期

## 可能的解决方案

### 方案1: 重新登录
如果token确实无效：
1. 退出当前账号
2. 重新登录获取新token
3. 再次尝试进入聊天界面

### 方案2: 检查Token生成
如果问题持续存在，检查：
1. 服务端JWT token生成逻辑
2. Token过期时间设置
3. 认证中间件的token解析逻辑

### 方案3: 添加Token刷新机制
实现自动token刷新：
1. 在401错误时尝试刷新token
2. 如果刷新成功，重试原请求
3. 如果刷新失败，跳转到登录页面

## 调试输出示例

**正常情况**:
```
DEBUG API: Token from storage: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
DEBUG API: Added Authorization header
DEBUG API: Request headers: {Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...}
DEBUG CHAT: Current token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**异常情况**:
```
DEBUG API: Token from storage: null
DEBUG API: No token available for request to /messages/history
DEBUG CHAT: Current token: null
DEBUG CHAT: No token found, user may need to re-login
```

## 修复状态
✅ 添加了详细的调试日志  
✅ 改进了错误处理机制  
✅ 添加了token有效性检查  
✅ 提供了用户友好的错误提示  
✅ 重新编译了客户端应用  

## 下一步
1. 运行修复后的应用
2. 观察调试日志输出
3. 根据日志信息确定具体问题
4. 如需要，实施进一步的修复措施

现在用户可以重新测试聊天功能，调试信息将帮助我们准确定位问题所在。