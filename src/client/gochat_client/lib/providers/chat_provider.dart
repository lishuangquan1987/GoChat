import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../services/storage_service.dart';
import '../utils/performance_monitor.dart';

class ChatProvider with ChangeNotifier {
  final Map<String, List<Message>> _messages = {};
  final List<Conversation> _conversations = [];
  bool _isConnected = false;
  
  // 分页加载状态
  final Map<String, bool> _isLoadingMore = {};
  final Map<String, bool> _hasMoreMessages = {};
  final Map<String, int> _currentPage = {};
  
  // 消息缓存限制（每个会话最多缓存的消息数量）
  static const int _maxCachedMessages = 200;
  
  // 性能监控
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  
  // 防抖通知
  bool _isNotifying = false;

  Map<String, List<Message>> get messages => _messages;
  List<Conversation> get conversations => _conversations;
  bool get isConnected => _isConnected;
  
  bool isLoadingMore(String conversationId) => _isLoadingMore[conversationId] ?? false;
  bool hasMoreMessages(String conversationId) => _hasMoreMessages[conversationId] ?? true;
  int getCurrentPage(String conversationId) => _currentPage[conversationId] ?? 1;

  void addMessage(String conversationId, Message message, {bool isCurrentChat = false}) {
    _performanceMonitor.startTimer('add_message');
    
    if (!_messages.containsKey(conversationId)) {
      _messages[conversationId] = [];
    }
    
    // 检查消息是否已存在（避免重复添加）
    final existingIndex = _messages[conversationId]!.indexWhere(
      (m) => m.msgId == message.msgId,
    );
    
    bool shouldNotify = false;
    bool isNewMessage = false;
    
    if (existingIndex != -1) {
      // 更新现有消息
      final oldMessage = _messages[conversationId]![existingIndex];
      if (oldMessage.status != message.status || 
          oldMessage.content != message.content) {
        _messages[conversationId]![existingIndex] = message;
        shouldNotify = true;
      }
    } else {
      // 添加新消息，确保按时间顺序插入
      final messages = _messages[conversationId]!;
      int insertIndex = messages.length;
      
      // 找到正确的插入位置（保持时间顺序）
      for (int i = messages.length - 1; i >= 0; i--) {
        if (messages[i].createTime.isBefore(message.createTime) || 
            messages[i].createTime.isAtSameMomentAs(message.createTime)) {
          insertIndex = i + 1;
          break;
        }
        insertIndex = i;
      }
      
      messages.insert(insertIndex, message);
      shouldNotify = true;
      isNewMessage = true;
      
      // 限制内存使用
      if (messages.length > _maxCachedMessages) {
        messages.removeAt(0);
      }
    }
    
    if (shouldNotify) {
      // 更新会话列表中的最后一条消息
      _updateConversationLastMessage(conversationId, message);
      
      // 如果是新消息且不是当前聊天界面，增加未读数
      if (isNewMessage && !isCurrentChat) {
        incrementUnreadCount(conversationId);
      }
      
      // 保存消息到本地存储
      _saveMessagesToStorage(conversationId);
      
      _debouncedNotify();
    }
    
    _performanceMonitor.endTimer('add_message');
  }

  void setConversations(List<Conversation> conversations) {
    _performanceMonitor.startTimer('set_conversations');
    _conversations.clear();
    _conversations.addAll(conversations);
    
    // 保存会话到本地存储
    _saveConversationsToStorage();
    
    _debouncedNotify();
    _performanceMonitor.endTimer('set_conversations');
  }

  void addConversation(Conversation conversation) {
    // 检查是否已存在
    final existingIndex = _conversations.indexWhere((c) => c.id == conversation.id);
    if (existingIndex != -1) {
      _conversations[existingIndex] = conversation;
    } else {
      _conversations.insert(0, conversation);
    }
    
    // 保存会话到本地存储
    _saveConversationsToStorage();
    
    _debouncedNotify();
  }

  void updateConversation(String conversationId, {
    Message? lastMessage,
    int? unreadCount,
    DateTime? lastTime,
  }) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final oldConv = _conversations[index];
      _conversations[index] = Conversation(
        id: oldConv.id,
        type: oldConv.type,
        user: oldConv.user,
        group: oldConv.group,
        lastMessage: lastMessage ?? oldConv.lastMessage,
        unreadCount: unreadCount ?? oldConv.unreadCount,
        lastTime: lastTime ?? oldConv.lastTime,
      );
      
      // 将更新的会话移到列表顶部
      final updatedConv = _conversations.removeAt(index);
      _conversations.insert(0, updatedConv);
      
      _debouncedNotify();
    }
  }

  void _updateConversationLastMessage(String conversationId, Message message) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final oldConv = _conversations[index];
      _conversations[index] = Conversation(
        id: oldConv.id,
        type: oldConv.type,
        user: oldConv.user,
        group: oldConv.group,
        lastMessage: message,
        unreadCount: oldConv.unreadCount,
        lastTime: message.createTime,
      );
      
      // 将更新的会话移到列表顶部
      final updatedConv = _conversations.removeAt(index);
      _conversations.insert(0, updatedConv);
    }
  }

  void incrementUnreadCount(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final oldConv = _conversations[index];
      _conversations[index] = Conversation(
        id: oldConv.id,
        type: oldConv.type,
        user: oldConv.user,
        group: oldConv.group,
        lastMessage: oldConv.lastMessage,
        unreadCount: oldConv.unreadCount + 1,
        lastTime: oldConv.lastTime,
      );
      _debouncedNotify();
    }
  }

  void clearUnreadCount(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final oldConv = _conversations[index];
      _conversations[index] = Conversation(
        id: oldConv.id,
        type: oldConv.type,
        user: oldConv.user,
        group: oldConv.group,
        lastMessage: oldConv.lastMessage,
        unreadCount: 0,
        lastTime: oldConv.lastTime,
      );
      _debouncedNotify();
    }
  }

  void setConnected(bool connected) {
    _isConnected = connected;
    _debouncedNotify();
  }

  List<Message>? getMessages(String conversationId) {
    return _messages[conversationId];
  }

  void setMessages(String conversationId, List<Message> messages, {bool append = false}) {
    if (append && _messages.containsKey(conversationId)) {
      // 历史消息追加：服务器返回的历史消息也是降序的，需要排序后插入到开头
      final sortedHistoryMessages = List<Message>.from(messages);
      sortedHistoryMessages.sort((a, b) => a.createTime.compareTo(b.createTime));
      _messages[conversationId]!.insertAll(0, sortedHistoryMessages);
      
      // 限制缓存的消息数量，移除最旧的消息
      if (_messages[conversationId]!.length > _maxCachedMessages) {
        final excess = _messages[conversationId]!.length - _maxCachedMessages;
        _messages[conversationId]!.removeRange(0, excess);
      }
    } else {
      // 服务器返回的消息是按时间降序排列的（最新的在前），
      // 我们需要反转为升序（最旧的在前），这样配合ListView的reverse=true就能正确显示
      final sortedMessages = List<Message>.from(messages);
      sortedMessages.sort((a, b) => a.createTime.compareTo(b.createTime));
      _messages[conversationId] = sortedMessages;
    }
    _debouncedNotify();
  }

  // 优化内存使用：清理不活跃会话的消息缓存
  void cleanupInactiveConversations() {
    final now = DateTime.now();
    final inactiveThreshold = const Duration(hours: 1);
    
    _messages.removeWhere((conversationId, messages) {
      final conversation = _conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => Conversation(
          id: conversationId,
          type: ConversationType.private,
          unreadCount: 0,
        ),
      );
      
      // 如果会话超过1小时没有活动，清理其消息缓存
      if (conversation.lastTime != null) {
        return now.difference(conversation.lastTime!) > inactiveThreshold;
      }
      return false;
    });
  }

  // 预加载消息（在后台加载下一页消息）
  void preloadNextPage(String conversationId) {
    if (!_hasMoreMessages[conversationId]! || _isLoadingMore[conversationId]!) {
      return;
    }
    
    // 这里可以触发预加载逻辑
    // 实际的API调用应该在UI层处理
    debugPrint('Preloading next page for conversation: $conversationId');
  }

  void clearMessages(String conversationId) {
    _messages[conversationId]?.clear();
    _currentPage[conversationId] = 1;
    _hasMoreMessages[conversationId] = true;
    _isLoadingMore[conversationId] = false;
    notifyListeners();
  }
  
  // 设置加载状态
  void setLoadingMore(String conversationId, bool loading) {
    _isLoadingMore[conversationId] = loading;
    _debouncedNotify();
  }
  
  // 设置是否还有更多消息
  void setHasMoreMessages(String conversationId, bool hasMore) {
    _hasMoreMessages[conversationId] = hasMore;
    _debouncedNotify();
  }
  
  // 增加页码
  void incrementPage(String conversationId) {
    _currentPage[conversationId] = (_currentPage[conversationId] ?? 1) + 1;
  }
  
  // 重置分页状态
  void resetPagination(String conversationId) {
    _currentPage[conversationId] = 1;
    _hasMoreMessages[conversationId] = true;
    _isLoadingMore[conversationId] = false;
  }

  void removeConversation(String conversationId) {
    _conversations.removeWhere((c) => c.id == conversationId);
    _messages.remove(conversationId);
    _debouncedNotify();
  }

  // 创建或获取私聊会话
  Conversation getOrCreatePrivateConversation(User user) {
    final conversationId = 'private_${user.id}';
    final existingIndex = _conversations.indexWhere((c) => c.id == conversationId);
    
    if (existingIndex != -1) {
      return _conversations[existingIndex];
    }
    
    final newConversation = Conversation(
      id: conversationId,
      type: ConversationType.private,
      user: user,
      unreadCount: 0,
    );
    
    addConversation(newConversation);
    return newConversation;
  }

  // 创建或获取群聊会话
  Conversation getOrCreateGroupConversation(Group group) {
    final conversationId = 'group_${group.id}';
    final existingIndex = _conversations.indexWhere((c) => c.id == conversationId);
    
    if (existingIndex != -1) {
      return _conversations[existingIndex];
    }
    
    final newConversation = Conversation(
      id: conversationId,
      type: ConversationType.group,
      group: group,
      unreadCount: 0,
    );
    
    addConversation(newConversation);
    return newConversation;
  }

  /// 处理私聊消息通知
  void handlePrivateMessageNotification(Map<String, dynamic> data) {
    final messageData = data['data'] as Map<String, dynamic>?;
    if (messageData != null) {
      final fromUserId = messageData['fromUserId'] as int;
      final conversationId = 'private_$fromUserId';
      
      // 更新会话的未读消息数
      _updateConversationUnreadCount(conversationId, 1);
      
      // 可以在这里添加系统通知或声音提示
      print('New private message from: ${messageData['fromUserNickname']}');
    }
  }

  /// 处理群聊消息通知
  void handleGroupMessageNotification(Map<String, dynamic> data) {
    final messageData = data['data'] as Map<String, dynamic>?;
    if (messageData != null) {
      final groupName = messageData['groupName'] as String? ?? '';
      final fromUserNickname = messageData['fromUserNickname'] as String? ?? '';
      
      // 可以在这里添加系统通知或声音提示
      print('New group message from $fromUserNickname in $groupName');
    }
  }

  /// 更新会话未读消息数
  void _updateConversationUnreadCount(String conversationId, int increment) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final conversation = _conversations[index];
      _conversations[index] = Conversation(
        id: conversation.id,
        type: conversation.type,
        user: conversation.user,
        group: conversation.group,
        lastMessage: conversation.lastMessage,
        unreadCount: conversation.unreadCount + increment,
        lastTime: conversation.lastTime,
      );
      _debouncedNotify();
    }
  }

  /// 防抖通知，避免频繁的UI重建
  void _debouncedNotify() {
    if (_isNotifying) return;
    
    _isNotifying = true;
    Future.microtask(() {
      if (_isNotifying) {
        _isNotifying = false;
        notifyListeners();
      }
    });
  }

  /// 批量更新消息，减少通知次数
  void batchUpdateMessages(String conversationId, List<Message> messages) {
    _performanceMonitor.startTimer('batch_update_messages');
    
    if (!_messages.containsKey(conversationId)) {
      _messages[conversationId] = [];
    }
    
    bool hasChanges = false;
    
    for (final message in messages) {
      final existingIndex = _messages[conversationId]!.indexWhere(
        (m) => m.msgId == message.msgId,
      );
      
      if (existingIndex != -1) {
        final oldMessage = _messages[conversationId]![existingIndex];
        if (oldMessage.status != message.status || 
            oldMessage.content != message.content) {
          _messages[conversationId]![existingIndex] = message;
          hasChanges = true;
        }
      } else {
        _messages[conversationId]!.add(message);
        hasChanges = true;
      }
    }
    
    // 限制内存使用
    if (_messages[conversationId]!.length > _maxCachedMessages) {
      final excess = _messages[conversationId]!.length - _maxCachedMessages;
      _messages[conversationId]!.removeRange(0, excess);
      hasChanges = true;
    }
    
    if (hasChanges) {
      // 更新最后一条消息
      if (messages.isNotEmpty) {
        final lastMessage = messages.last;
        _updateConversationLastMessage(conversationId, lastMessage);
      }
      _debouncedNotify();
    }
    
    _performanceMonitor.endTimer('batch_update_messages');
  }

  /// 获取性能统计信息
  Map<String, dynamic> getPerformanceStats() {
    return _performanceMonitor.getPerformanceReport();
  }

  /// 清理性能数据
  void clearPerformanceData() {
    _performanceMonitor.clearData();
  }

  /// 从本地存储加载会话
  Future<void> loadConversationsFromStorage() async {
    try {
      final conversationsData = await StorageService.getConversations();
      final conversations = conversationsData.map((data) => Conversation.fromJson(data)).toList();
      
      _conversations.clear();
      _conversations.addAll(conversations);
      
      // 为每个会话加载消息
      for (final conversation in conversations) {
        await _loadMessagesFromStorage(conversation.id);
      }
      
      _debouncedNotify();
    } catch (e) {
      print('Failed to load conversations from storage: $e');
    }
  }

  /// 保存会话到本地存储
  Future<void> _saveConversationsToStorage() async {
    try {
      final conversationsData = _conversations.map((c) => c.toJson()).toList();
      await StorageService.saveConversations(conversationsData);
    } catch (e) {
      print('Failed to save conversations to storage: $e');
    }
  }

  /// 从本地存储加载指定会话的消息
  Future<void> _loadMessagesFromStorage(String conversationId) async {
    try {
      final messagesData = await StorageService.getMessages(conversationId);
      final messages = messagesData.map((data) => Message.fromJson(data)).toList();
      
      if (messages.isNotEmpty) {
        _messages[conversationId] = messages;
      }
    } catch (e) {
      print('Failed to load messages for $conversationId from storage: $e');
    }
  }

  /// 保存指定会话的消息到本地存储
  Future<void> _saveMessagesToStorage(String conversationId) async {
    try {
      final messages = _messages[conversationId];
      if (messages != null && messages.isNotEmpty) {
        final messagesData = messages.map((m) => m.toJson()).toList();
        await StorageService.saveMessages(conversationId, messagesData);
      }
    } catch (e) {
      print('Failed to save messages for $conversationId to storage: $e');
    }
  }

  /// 重写addMessage方法以支持持久化存储
  void addMessageWithPersistence(String conversationId, Message message) {
    addMessage(conversationId, message);
    
    // 保存消息到本地存储
    _saveMessagesToStorage(conversationId);
  }
}