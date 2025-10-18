import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/conversation.dart';

class ChatProvider with ChangeNotifier {
  final Map<String, List<Message>> _messages = {};
  final List<Conversation> _conversations = [];
  bool _isConnected = false;

  Map<String, List<Message>> get messages => _messages;
  List<Conversation> get conversations => _conversations;
  bool get isConnected => _isConnected;

  void addMessage(String conversationId, Message message) {
    if (!_messages.containsKey(conversationId)) {
      _messages[conversationId] = [];
    }
    _messages[conversationId]!.add(message);
    notifyListeners();
  }

  void setConversations(List<Conversation> conversations) {
    _conversations.clear();
    _conversations.addAll(conversations);
    notifyListeners();
  }

  void setConnected(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  List<Message>? getMessages(String conversationId) {
    return _messages[conversationId];
  }

  void clearMessages(String conversationId) {
    _messages[conversationId]?.clear();
    notifyListeners();
  }
}
