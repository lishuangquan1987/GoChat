import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// WebSocket消息类型
class WSMessageType {
  static const String chat = 'chat';
  static const String heartbeat = 'heartbeat';
  static const String ack = 'ack';
  static const String typing = 'typing';
  static const String system = 'system';
  static const String notification = 'notification';
  static const String error = 'error';
  static const String friendRequest = 'friend_request';
  static const String friendRequestAccepted = 'friend_request_accepted';
  static const String privateMessage = 'private_message';
  static const String groupMessage = 'group_message';
}

/// WebSocket连接状态
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// WebSocket服务
/// 负责管理WebSocket连接、消息发送接收、心跳和重连
class WebSocketService {
  static const String wsUrl = 'ws://localhost:8080/ws';
  static const int heartbeatInterval = 30; // 心跳间隔（秒）
  static const int reconnectDelay = 5; // 重连延迟（秒）
  static const int maxReconnectAttempts = 5; // 最大重连次数
  
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<ConnectionState> _connectionStateController = 
      StreamController<ConnectionState>.broadcast();
  
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  ConnectionState _connectionState = ConnectionState.disconnected;
  int _reconnectAttempts = 0;
  
  String? _userId;
  String? _token;
  bool _shouldReconnect = true;

  // 消息流
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  
  // 连接状态流
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  
  // 当前连接状态
  ConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == ConnectionState.connected;

  /// 连接WebSocket
  /// [userId] 用户ID
  /// [token] 认证token
  void connect(String userId, String token) {
    _userId = userId;
    _token = token;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _connect();
  }

  /// 内部连接方法
  void _connect() {
    if (_connectionState == ConnectionState.connecting || 
        _connectionState == ConnectionState.connected) {
      return;
    }

    _updateConnectionState(ConnectionState.connecting);
    
    try {
      final uri = Uri.parse('$wsUrl?userId=$_userId&token=$_token');
      print('Connecting to WebSocket: $uri');
      
      _channel = WebSocketChannel.connect(uri);
      
      // 监听WebSocket流
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );
      
      // 连接成功
      _updateConnectionState(ConnectionState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();
      
      print('WebSocket connected successfully');
    } catch (e) {
      print('Failed to connect WebSocket: $e');
      _handleDisconnect();
    }
  }

  /// 处理接收到的消息
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final messageType = data['type'] as String?;
      
      print('Received WebSocket message: type=$messageType');
      
      // 处理不同类型的消息
      switch (messageType) {
        case WSMessageType.system:
          _handleSystemMessage(data);
          break;
        case WSMessageType.notification:
          _handleNotification(data);
          break;
        case WSMessageType.ack:
          _handleAckMessage(data);
          break;
        case WSMessageType.error:
          _handleErrorMessage(data);
          break;
        case WSMessageType.friendRequest:
          _handleFriendRequestNotification(data);
          break;
        case WSMessageType.friendRequestAccepted:
          _handleFriendRequestAcceptedNotification(data);
          break;
        case WSMessageType.privateMessage:
          _handlePrivateMessageNotification(data);
          break;
        case WSMessageType.groupMessage:
          _handleGroupMessageNotification(data);
          break;
        default:
          // 将消息发送到流中供外部处理
          _messageController.add(data);
      }
    } catch (e) {
      print('Failed to parse WebSocket message: $e');
    }
  }

  /// 处理系统消息
  void _handleSystemMessage(Map<String, dynamic> data) {
    final message = data['message'] as String?;
    print('System message: $message');
    _messageController.add(data);
  }

  /// 处理通知消息
  void _handleNotification(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    print('Notification: action=$action');
    
    // 特殊处理离线消息通知
    if (action == 'fetch_offline_messages') {
      // 通知外部获取离线消息
      _messageController.add(data);
    } else {
      _messageController.add(data);
    }
  }

  /// 处理确认消息
  void _handleAckMessage(Map<String, dynamic> data) {
    print('Message acknowledged: ${data['msgId']}');
    _messageController.add(data);
  }

  /// 处理错误消息
  void _handleErrorMessage(Map<String, dynamic> data) {
    final errorMsg = data['message'] as String?;
    print('Server error: $errorMsg');
    _messageController.add(data);
  }

  /// 处理好友请求通知
  void _handleFriendRequestNotification(Map<String, dynamic> data) {
    print('Friend request notification received');
    _messageController.add(data);
  }

  /// 处理好友请求被接受通知
  void _handleFriendRequestAcceptedNotification(Map<String, dynamic> data) {
    print('Friend request accepted notification received');
    _messageController.add(data);
  }

  /// 处理私聊消息通知
  void _handlePrivateMessageNotification(Map<String, dynamic> data) {
    print('Private message notification received');
    _messageController.add(data);
  }

  /// 处理群聊消息通知
  void _handleGroupMessageNotification(Map<String, dynamic> data) {
    print('Group message notification received');
    _messageController.add(data);
  }

  /// 处理WebSocket错误
  void _handleError(error) {
    print('WebSocket error: $error');
    _handleDisconnect();
  }

  /// 处理WebSocket关闭
  void _handleDone() {
    print('WebSocket connection closed');
    _handleDisconnect();
  }

  /// 处理断开连接
  void _handleDisconnect() {
    _stopHeartbeat();
    _updateConnectionState(ConnectionState.disconnected);
    
    // 尝试重连
    if (_shouldReconnect && _reconnectAttempts < maxReconnectAttempts) {
      _scheduleReconnect();
    } else if (_reconnectAttempts >= maxReconnectAttempts) {
      print('Max reconnect attempts reached. Giving up.');
      _messageController.add({
        'type': WSMessageType.error,
        'message': '连接失败，请检查网络后重试',
      });
    }
  }

  /// 安排重连
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    
    _updateConnectionState(ConnectionState.reconnecting);
    
    print('Scheduling reconnect attempt $_reconnectAttempts in $reconnectDelay seconds...');
    
    _reconnectTimer = Timer(Duration(seconds: reconnectDelay), () {
      if (_userId != null && _token != null && _shouldReconnect) {
        print('Attempting to reconnect... (attempt $_reconnectAttempts)');
        _connect();
      }
    });
  }

  /// 启动心跳
  void _startHeartbeat() {
    _stopHeartbeat();
    
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: heartbeatInterval),
      (timer) {
        if (isConnected) {
          _sendHeartbeat();
        }
      },
    );
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 发送心跳消息
  void _sendHeartbeat() {
    try {
      sendMessage({
        'type': WSMessageType.heartbeat,
        'time': DateTime.now().millisecondsSinceEpoch,
      });
      print('Heartbeat sent');
    } catch (e) {
      print('Failed to send heartbeat: $e');
    }
  }

  /// 发送消息
  /// [message] 消息内容（Map格式）
  void sendMessage(Map<String, dynamic> message) {
    if (!isConnected || _channel == null) {
      print('Cannot send message: WebSocket not connected');
      throw Exception('WebSocket未连接');
    }

    try {
      final jsonStr = jsonEncode(message);
      _channel!.sink.add(jsonStr);
      print('Message sent: ${message['type']}');
    } catch (e) {
      print('Failed to send message: $e');
      throw Exception('发送消息失败: $e');
    }
  }

  /// 发送聊天消息
  /// [toUserId] 接收者ID
  /// [msgType] 消息类型
  /// [content] 消息内容
  /// [groupId] 群组ID（可选）
  /// [msgId] 客户端消息ID（用于确认）
  void sendChatMessage({
    required int toUserId,
    required int msgType,
    required String content,
    int? groupId,
    String? msgId,
  }) {
    final message = {
      'type': WSMessageType.chat,
      'msgId': msgId,
      'data': {
        'toUserId': toUserId,
        'msgType': msgType,
        'content': content,
        if (groupId != null) 'groupId': groupId,
      },
      'time': DateTime.now().millisecondsSinceEpoch,
    };

    sendMessage(message);
  }

  /// 发送正在输入状态
  /// [toUserId] 接收者ID
  /// [isTyping] 是否正在输入
  void sendTypingStatus(int toUserId, bool isTyping) {
    if (!isConnected) return;

    final message = {
      'type': WSMessageType.typing,
      'data': {
        'toUserId': toUserId,
        'isTyping': isTyping,
      },
      'time': DateTime.now().millisecondsSinceEpoch,
    };

    sendMessage(message);
  }

  /// 发送消息确认
  /// [msgId] 消息ID
  void sendAck(String msgId) {
    if (!isConnected) return;

    final message = {
      'type': WSMessageType.ack,
      'data': {
        'msgId': msgId,
      },
      'time': DateTime.now().millisecondsSinceEpoch,
    };

    sendMessage(message);
  }

  /// 更新连接状态
  void _updateConnectionState(ConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionStateController.add(state);
      print('Connection state changed: $state');
    }
  }

  /// 断开连接
  void disconnect() {
    print('Disconnecting WebSocket...');
    
    _shouldReconnect = false;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    
    try {
      _channel?.sink.close(status.goingAway);
    } catch (e) {
      print('Error closing WebSocket: $e');
    }
    
    _updateConnectionState(ConnectionState.disconnected);
    _userId = null;
    _token = null;
    _reconnectAttempts = 0;
  }

  /// 手动重连
  void reconnect() {
    if (_userId != null && _token != null) {
      print('Manual reconnect requested');
      _reconnectAttempts = 0;
      _shouldReconnect = true;
      disconnect();
      _connect();
    }
  }

  /// 释放资源
  void dispose() {
    print('Disposing WebSocketService...');
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}
