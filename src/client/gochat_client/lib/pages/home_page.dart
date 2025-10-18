import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../services/websocket_service.dart';
import 'chat_list_page.dart';
import 'friend_list_page.dart';
import 'group_list_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _wsService = WebSocketService();

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (userProvider.currentUser != null && userProvider.token != null) {
      _wsService.connect(
        userProvider.currentUser!.id.toString(),
        userProvider.token!,
      );
      
      _wsService.messageStream.listen((message) {
        // Handle incoming messages
        chatProvider.setConnected(true);
      });
    }
  }

  @override
  void dispose() {
    _wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ChatListPage(),
      const FriendListPage(),
      const GroupListPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF07C160),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '聊天'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: '好友'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: '群组'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

