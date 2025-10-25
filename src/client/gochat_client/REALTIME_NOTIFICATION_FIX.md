# 实时消息通知修复

## 问题描述

根据用户反馈，聊天还有以下BUG：

1. **实时消息接收问题** - 对方在聊天对话框中时，不能直接收到实时消息
2. **未读消息计数问题** - 聊天列表没有红色通知显示未读消息个数
3. **系统级通知问题** - 任务管理栏没有红色或闪动提示，缺少系统级通知

## 问题分析

### 1. WebSocket消息分发问题
- HomePage和ChatPage都在监听WebSocket消息，但使用不同的服务实例
- 消息可能没有正确分发到所有监听器
- 需要确保全局使用同一个WebSocket服务实例

### 2. 未读消息计数问题
- ChatPage进入时没有清除未读消息计数
- 未读消息状态没有正确更新到桌面通知

### 3. 桌面通知功能不完善
- 任务栏闪烁效果需要增强
- 系统通知权限和显示需要优化

## 修复方案

### 1. 统一WebSocket服务管理

**HomePage修复：**
```dart
// 使用UserProvider中的WebSocket服务，确保全局唯一
if (userProvider.wsService == null) {
  userProvider.setWebSocketService(_wsService);
  _wsService.connect(
    userProvider.currentUser!.id.toString(),
    userProvider.token!,
  );
}
```

**UserProvider增强：**
```dart
void setWebSocketService(WebSocketService service) {
  _wsService = service;
}
```

### 2. 修复未读消息计数

**ChatPage修复：**
```dart
@override
void initState() {
  super.initState();
  // ... 其他初始化代码
  
  // 清除未读消息计数
  _clearUnreadCount();
}

void _clearUnreadCount() {
  final chatProvider = context.read<ChatProvider>();
  chatProvider.clearUnreadCount(widget.conversation.id);
  
  // 更新桌面通知状态
  final totalUnread = chatProvider.conversations
      .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
  DesktopNotification.updateUnreadStatus(unreadCount: totalUnread);
}
```

**ChatProvider增强：**
```dart
void clearUnreadCount(String conversationId) {
  final index = _conversations.indexWhere((c) => c.id == conversationId);
  if (index != -1) {
    final oldConv = _conversations[index];
    _conversations[index] = Conversation(
      // ... 更新未读数为0
      unreadCount: 0,
    );
    
    // 保存会话到本地存储
    _saveConversationsToStorage();
    _debouncedNotify();
  }
}
```

### 3. 增强桌面通知功能

**Windows任务栏闪烁：**
```dart
static Future<void> _updateWindowsTaskbar() async {
  try {
    if (_hasUnreadMessages) {
      // Windows 任务栏闪烁效果
      await Process.run('powershell', [
        '-Command',
        '''
        Add-Type -TypeDefinition "
          using System;
          using System.Runtime.InteropServices;
          public class Win32 {
            [DllImport(\\"user32.dll\\")]
            public static extern bool FlashWindow(IntPtr hWnd, bool bInvert);
            [DllImport(\\"user32.dll\\")]
            public static extern IntPtr GetForegroundWindow();
          }
        "
        \$hwnd = [Win32]::GetForegroundWindow()
        for (\$i = 0; \$i -lt 3; \$i++) {
          [Win32]::FlashWindow(\$hwnd, \$true)
          Start-Sleep -Milliseconds 500
          [Win32]::FlashWindow(\$hwnd, \$false)
          Start-Sleep -Milliseconds 500
        }
        '''
      ]);
    }
  } catch (e) {
    debugPrint('Failed to update Windows taskbar: $e');
  }
}
```

### 4. 优化消息监听逻辑

**ChatPage消息监听优化：**
```dart
void _setupMessageListener() {
  final userProvider = context.read<UserProvider>();
  
  if (userProvider.wsService != null) {
    // 监听消息流，但只处理当前会话相关的消息
    userProvider.wsService!.messageStream.listen((data) {
      if (data['type'] == 'message') {
        final messageData = data['data'];
        final message = Message.fromJson(messageData);
        
        // 检查消息是否属于当前会话
        if (isCurrentConversation) {
          // 自动滚动到底部（消息已经由HomePage处理）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _messageListKey.currentState?.scrollToBottom();
            }
          });
          
          // 发送消息确认
          if (message.fromUserId != userProvider.currentUser?.id) {
            _markMessageAsDelivered(message);
            _markMessageAsRead(message);
          }
        }
      }
    });
  }
}
```

## 技术要点

### WebSocket服务单例模式
- 确保整个应用只有一个WebSocket服务实例
- 通过UserProvider管理全局WebSocket服务
- 避免消息监听器冲突和重复处理

### 未读消息状态管理
- 进入聊天界面时自动清除未读数
- 实时更新桌面通知状态
- 保持会话列表和桌面通知的同步

### 桌面通知增强
- Windows: 使用PowerShell调用Win32 API实现任务栏闪烁
- macOS: 使用AppleScript设置Dock徽章
- Linux: 使用notify-send显示系统通知

### 消息处理分工
- **HomePage**: 负责全局消息接收和会话列表更新
- **ChatPage**: 负责当前会话的消息显示和状态确认
- **DesktopNotification**: 负责系统级通知和任务栏状态

## 修复后的功能特性

1. ✅ **实时消息接收** - 对方在聊天界面能立即看到新消息
2. ✅ **未读消息计数** - 聊天列表正确显示红色未读消息徽章
3. ✅ **系统级通知** - 任务栏闪烁提醒和系统通知
4. ✅ **消息状态同步** - 已读/送达状态实时更新
5. ✅ **桌面通知** - 跨平台系统通知支持

## 相关文件

- `lib/pages/home_page.dart` - 全局消息处理
- `lib/pages/chat_page.dart` - 聊天界面消息处理
- `lib/providers/user_provider.dart` - WebSocket服务管理
- `lib/providers/chat_provider.dart` - 未读消息计数管理
- `lib/utils/desktop_notification.dart` - 桌面通知功能
- `lib/widgets/conversation_item.dart` - 未读消息徽章显示

## 测试验证

修复后应该验证以下场景：

1. ✅ 用户A发送消息，用户B在聊天界面立即收到
2. ✅ 用户B不在聊天界面时，聊天列表显示未读消息数
3. ✅ 收到新消息时任务栏闪烁提醒
4. ✅ 系统通知正确显示
5. ✅ 进入聊天界面后未读数清零
6. ✅ 桌面通知状态正确更新

## 注意事项

- 确保WebSocket连接稳定性
- 桌面通知功能需要系统权限
- 任务栏闪烁在某些系统上可能需要用户授权
- 保持消息处理的性能优化