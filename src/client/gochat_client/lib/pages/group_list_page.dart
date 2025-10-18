import 'package:flutter/material.dart';

class GroupListPage extends StatelessWidget {
  const GroupListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群组'),
        backgroundColor: const Color(0xFF07C160),
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF07C160),
              child: Text('G$index'),
            ),
            title: Text('群组 $index'),
            subtitle: Text('${index + 3} 人'),
            onTap: () {},
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF07C160),
        child: const Icon(Icons.group_add),
      ),
    );
  }
}
