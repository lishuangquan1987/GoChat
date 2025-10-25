# WebSocket消息接收机制重构

## 问题描述

之前的实现中存在以下问题：
1. **多个监听器**：HomePage和ChatPage都在监听WebSocket消息流，导致消息重复处理
2. **状态不一致**：不同页面对同一消息的处理可能不同步
3. **通知混乱**：消息通知可能重复显示或丢失
4. **资源浪费**：多个监听器消耗额外的内存和CPU资源

## 重构方案

### 1. 统一消息入口
- **MessageDispatcher**作为全局唯一的WebSocket消息接收入口
- 所有WebSocket消息都通过MessageDispatcher处理和分发
- 确保每个消息只被处理一次

### 2. 事件驱动架构
- MessageDispatcher将处理后的消息转换为事件
- 各个页面监听MessageDispatcher的事件流，而不是直接监听WebSocket
- 支持多种事件类型：新消息、消息状态、连接状态等

### 3. 活跃聊天管理
- MessageDispatcher跟踪当前活跃的聊天页面
- 根据是否为活跃聊天决定是否增加未读数和显示通知
- 避免当前聊天页面显示重复通知

## 重构内容

### MessageDispatcher增强
```dart
class MessageDispatcher {
  // 统一的WebSocket监听
  void _setupWebSocketListeners()
  
  // 活跃聊天管理
  void setActiveChatId(String? chatId)
  
  // 消息分发
  void handleWebSocketMessage(Map<String, dynamic> data)
  
  // WebSocket消息发送
  void sendWebSocketMessage(Map<String, dynamic> message)
}
```

### HomePage重构
- 移除直接的WebSocket监听
- 监听MessageDispatcher事件流
- 处理离线消息获取等全局事件

### ChatPage重构
- 移除直接的WebSocket监听
- 设置/清除活跃聊天ID
- 监听MessageDispatcher事件流
- 通过MessageDispatcher发送WebSocket消息

### 事件类型扩展
```dart
enum MessageEventType {
  newMessage,           // 新消息
  messageStatus,        // 消息状态更新
  friendRequest,        // 好友请求
  systemMessage,        // 系统消息
  connectionStatus,     // 连接状态变化
  fetchOfflineMessages, // 获取离线消息
  error,               // 错误消息
  unknown,             // 未知消息类型
}
```

## 优势

1. **消息处理一致性**：所有消息都通过统一入口处理，确保状态一致
2. **避免重复处理**：每个消息只被处理一次，避免重复通知和状态更新
3. **资源优化**：只有一个WebSocket监听器，减少内存和CPU消耗
4. **易于维护**：集中的消息处理逻辑，便于调试和维护
5. **扩展性好**：新的消息类型和处理逻辑可以轻松添加到MessageDispatcher

## 使用方式

### 初始化（在HomePage中）
```dart
_messageDispatcher.initialize(
  chatProvider: chatProvider,
  friendProvider: friendProvider,
  notificationService: _notificationService,
  webSocketService: _wsService,
);
```

### 设置活跃聊天（在ChatPage中）
```dart
// 进入聊天页面时
MessageDispatcher().setActiveChatId(widget.conversation.id);

// 离开聊天页面时
MessageDispatcher().setActiveChatId(null);
```

### 监听事件
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

### 发送WebSocket消息
```dart
MessageDispatcher().sendWebSocketMessage({
  'type': 'read',
  'data': {'msgId': messageId},
});
```

## 注意事项

1. **单例模式**：MessageDispatcher使用单例模式，确保全局唯一
2. **生命周期管理**：需要在适当的时候调用dispose()清理资源
3. **错误处理**：增强了错误处理和日志记录
4. **向后兼容**：保持了原有的API接口，减少对现有代码的影响

这次重构解决了WebSocket消息接收的核心问题，提供了更稳定、高效的消息处理机制。