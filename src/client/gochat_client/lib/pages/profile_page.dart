import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'user_switcher_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _showEditNicknameDialog(BuildContext context, UserProvider userProvider) {
    final TextEditingController nicknameController = TextEditingController(
      text: userProvider.currentUser?.nickname ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: nicknameController,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '请输入新昵称',
            border: OutlineInputBorder(),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newNickname = nicknameController.text.trim();
              if (newNickname.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('昵称不能为空')),
                );
                return;
              }

              try {
                final apiService = ApiService();
                final response = await apiService.updateProfile(
                  newNickname,
                  userProvider.currentUser?.sex ?? 0,
                );

                if (response.data['code'] == 0) {
                  // 更新本地用户信息
                  final updatedUser = User(
                    id: userProvider.currentUser!.id,
                    username: userProvider.currentUser!.username,
                    nickname: newNickname,
                    sex: userProvider.currentUser!.sex,
                  );
                  userProvider.updateUser(updatedUser);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('昵称修改成功')),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response.data['message'] ?? '修改失败')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('修改失败: $e')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await userProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        backgroundColor: const Color(0xFF07C160),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          // 用户头像和基本信息
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF07C160),
                  child: Text(
                    user?.nickname.isNotEmpty == true 
                        ? user!.nickname.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(fontSize: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.nickname ?? 'Unknown',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${user?.id ?? 0}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  '用户名: ${user?.username ?? 'Unknown'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Divider(height: 1),
          
          // 个人信息部分
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('昵称'),
            subtitle: Text(user?.nickname ?? 'Unknown'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEditNicknameDialog(context, userProvider),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('用户名'),
            subtitle: Text(user?.username ?? 'Unknown'),
            trailing: const Text('不可修改', style: TextStyle(color: Colors.grey)),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.wc_outlined),
            title: const Text('性别'),
            subtitle: Text(user?.sex == 0 ? '男' : user?.sex == 1 ? '女' : '未知'),
          ),
          
          const SizedBox(height: 20),
          const Divider(height: 1),
          
          // 设置部分
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: const Text('切换账户'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserSwitcherPage()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'GoChat',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.chat, size: 48, color: Color(0xFF07C160)),
                children: [
                  const Text('一个简洁的跨平台聊天应用'),
                ],
              );
            },
          ),
          
          const SizedBox(height: 20),
          const Divider(height: 1),
          
          // 退出登录
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () => _showLogoutConfirmDialog(context, userProvider),
          ),
        ],
      ),
    );
  }
}
