import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  static const String wsUrl = 'ws://localhost:8080/ws';
  
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  String? _userId;
  String? _token;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  void connect(String userId, String token) {
    _userId = userId;
    _token = token;
    _connect();
  }

  void _connect() {
    try {
      final uri = Uri.parse('$wsUrl?userId=$_userId&token=$_token');
      _channel = WebSocketChannel.connect(uri);
      
      _isConnected = true;
      _startHeartbeat();
      
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _handleDisconnect();
        },
      );
    } catch (e) {
      print('Failed to connect WebSocket: $e');
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      _messageController.add(data);
    } catch (e) {
      print('Failed to parse message: $e');
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    
    // 尝试重连
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_userId != null && _token != null) {
        print('Attempting to reconnect...');
        _connect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        sendMessage({'type': 'heartbeat'});
      }
    });
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _isConnected = false;
    _userId = null;
    _token = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
