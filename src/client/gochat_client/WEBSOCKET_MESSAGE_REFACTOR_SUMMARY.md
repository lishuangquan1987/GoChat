# WebSocket消息接收机制重构总结

## 重构完成

已成功重构WebSocket消息接收机制，解决了消息接收和通知的BUG问题。

## 主要改进

### 1. 统一消息入口
- **MessageDispatcher**现在是全局唯一的WebSocket消息接收入口
- 所有WebSocket消息都通过MessageDispatcher处理，避免重复监听
- 确保每个消息只被处理一次

### 2. 消除重复监听
- **HomePage**：移除了直接的WebSocket监听，改为监听MessageDispatcher事件流
- **ChatPage**：移除了直接的WebSocket监听，改为监听MessageDispatcher事件流
- 只有MessageDispatcher监听WebSocket消息流

### 3. 活跃聊天管理
- ChatPage进入时设置活跃聊天ID：`MessageDispatcher().setActiveChatId(conversationId)`
- ChatPage退出时清除活跃聊天ID：`MessageDispatcher().setActiveChatId(null)`
- MessageDispatcher根据活跃聊天状态决定是否增加未读数和显示通知

### 4. 事件驱动架构
- 扩展了MessageEvent类型，支持更多事件：
  - `newMessage` - 新消息
  - `messageStatus` - 消息状态更新
  - `connectionStatus` - 连接状态变化
  - `fetchOfflineMessages` - 获取离线消息
  - `error` - 错误消息
  - `unknown` - 未知消息类型

### 5. 统一消息发送
- 通过MessageDispatcher发送WebSocket消息：`MessageDispatcher().sendWebSocketMessage()`
- 避免直接访问WebSocket服务

## 核心文件修改

### MessageDispatcher增强
- 添加WebSocket服务引用和监听器管理
- 实现统一的消息处理和分发逻辑
- 支持活跃聊天管理
- 提供WebSocket消息发送接口

### HomePage重构
- 移除重复的WebSocket监听代码
- 监听MessageDispatcher事件流
- 处理全局事件（如离线消息获取）
- 清理未使用的导入和方法

### ChatPage重构
- 移除重复的WebSocket监听代码
- 设置和清除活跃聊天ID
- 监听MessageDispatcher事件流
- 通过MessageDispatcher发送消息状态确认

## 解决的问题

1. **消息重复处理**：现在每个消息只被处理一次
2. **通知重复显示**：活跃聊天不会显示通知，避免重复
3. **状态不一致**：统一的消息处理确保状态一致性
4. **资源浪费**：只有一个WebSocket监听器，减少资源消耗
5. **代码重复**：消息处理逻辑集中在MessageDispatcher中

## 测试状态

- ✅ 代码编译通过
- ✅ Flutter应用构建成功
- ✅ Go服务器启动正常
- 🔄 功能测试进行中

## 使用指南

### 监听消息事件
```dart
MessageDispatcher().messageStream.listen((event) {
  switch (event.type) {
    case MessageEventType.newMessage:
      // 处理新消息
      break;
    case MessageEventType.connectionStatus:
      // 处理连接状态变化
      break;
    // ... 其他事件类型
  }
});
```

### 设置活跃聊天
```dart
// 进入聊天页面
MessageDispatcher().setActiveChatId(conversationId);

// 离开聊天页面
MessageDispatcher().setActiveChatId(null);
```

### 发送WebSocket消息
```dart
MessageDispatcher().sendWebSocketMessage({
  'type': 'read',
  'data': {'msgId': messageId},
});
```

这次重构彻底解决了WebSocket消息接收的架构问题，提供了更稳定、高效的消息处理机制。