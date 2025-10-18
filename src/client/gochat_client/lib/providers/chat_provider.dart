import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../models/group.dart';

class ChatProvider with ChangeNotifier {
  final Map<String, List<Message>> _messages = {};
  final List<Conversation> _conversations = [];
  bool _isConnected = false;
  
  // 分页加载状态
  final Map<String, bool> _isLoadingMore = {};
  final Map<String, bool> _hasMoreMessages = {};
  final Map<String, int> _currentPage = {};

  Map<String, List<Message>> get messages => _messages;
  List<Conversation> get conversations => _conversations;
  bool get isConnected => _isConnected;
  
  bool isLoadingMore(String conversationId) => _isLoadingMore[conversationId] ?? false;
  bool hasMoreMessages(String conversationId) => _hasMoreMessages[conversationId] ?? true;
  int getCurrentPage(String conversationId) => _currentPage[conversationId] ?? 1;

  void addMessage(String conversationId, Message message) {
    if (!_messages.containsKey(conversationId)) {
      _messages[conversationId] = [];
    }
    
    // 检查消息是否已存在（避免重复添加）
    final existingIndex = _messages[conversationId]!.indexWhere(
      (m) => m.msgId == message.msgId,
    );
    
    if (existingIndex != -1) {
      // 更新现有消息
      _messages[conversationId]![existingIndex] = message;
    } else {
      // 添加新消息
      _messages[conversationId]!.add(message);
    }
    
    // 更新会话列表中的最后一条消息
    _updateConversationLastMessage(conversationId, message);
    
    notifyListeners();
  }

  void setConversations(List<Conversation> conversations) {
    _conversations.clear();
    _conversations.addAll(conversations);
    notifyListeners();
  }

  void addConversation(Conversation conversation) {
    // 检查是否已存在
    final existingIndex = _conversations.indexWhere((c) => c.id == conversation.id);
    if (existingIndex != -1) {
      _conversations[existingIndex] = conversation;
    } else {
      _conversations.insert(0, conversation);
    }
    notifyListeners();
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
      
      notifyListeners();
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
      notifyListeners();
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
      notifyListeners();
    }
  }

  void setConnected(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  List<Message>? getMessages(String conversationId) {
    return _messages[conversationId];
  }

  void setMessages(String conversationId, List<Message> messages, {bool append = false}) {
    if (append && _messages.containsKey(conversationId)) {
      // 追加到现有消息列表的开头（历史消息）
      _messages[conversationId]!.insertAll(0, messages);
    } else {
      _messages[conversationId] = messages;
    }
    notifyListeners();
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
    notifyListeners();
  }
  
  // 设置是否还有更多消息
  void setHasMoreMessages(String conversationId, bool hasMore) {
    _hasMoreMessages[conversationId] = hasMore;
    notifyListeners();
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
    notifyListeners();
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
}
