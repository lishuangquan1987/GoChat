import 'package:flutter/material.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GoChat'),
        backgroundColor: const Color(0xFF07C160),
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF07C160),
              child: Text('U$index'),
            ),
            title: Text('用户 $index'),
            subtitle: const Text('最后一条消息...'),
            trailing: const Text('12:00'),
            onTap: () {
              // Navigate to chat page
            },
          );
        },
      ),
    );
  }
}
