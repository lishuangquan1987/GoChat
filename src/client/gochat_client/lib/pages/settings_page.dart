import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart' as settings;
import '../services/notification_service.dart';
import '../pages/do_not_disturb_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _serverAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settingsProvider = Provider.of<settings.SettingsProvider>(context, listen: false);
    _serverAddressController.text = settingsProvider.serverAddress;
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF07C160),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<settings.SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return ListView(
            children: [
              // 主题设置
              _buildSectionHeader('主题设置'),
              _buildThemeColorTile(settingsProvider),
              _buildThemeModeTile(settingsProvider),
              _buildFontSizeTile(settingsProvider),
              
              const Divider(height: 32),
              
              // 通知设置
              _buildSectionHeader('通知设置'),
              _buildSwitchTile(
                title: '声音通知',
                subtitle: '接收消息时播放提示音',
                value: settingsProvider.soundEnabled,
                onChanged: (value) {
                  settingsProvider.setSoundEnabled(value);
                  NotificationService().setSoundEnabled(value);
                },
              ),
              _buildSwitchTile(
                title: '震动通知',
                subtitle: '接收消息时震动提醒',
                value: settingsProvider.vibrationEnabled,
                onChanged: (value) {
                  settingsProvider.setVibrationEnabled(value);
                  NotificationService().setVibrationEnabled(value);
                },
              ),
              _buildSwitchTile(
                title: '应用内通知',
                subtitle: '在应用内显示通知横幅',
                value: settingsProvider.showInAppNotification,
                onChanged: (value) {
                  settingsProvider.setShowInAppNotification(value);
                  NotificationService().setShowInAppNotification(value);
                },
              ),
              _buildSwitchTile(
                title: '消息预览',
                subtitle: '在通知中显示消息内容',
                value: settingsProvider.showMessagePreview,
                onChanged: settingsProvider.setShowMessagePreview,
              ),
              
              const Divider(height: 32),
              
              // 服务器设置
              _buildSectionHeader('服务器设置'),
              _buildServerAddressTile(settingsProvider),
              _buildSwitchTile(
                title: '使用HTTPS',
                subtitle: '启用安全连接（需要服务器支持）',
                value: settingsProvider.useHttps,
                onChanged: settingsProvider.setUseHttps,
              ),
              
              const Divider(height: 32),
              
              // 聊天设置
              _buildSectionHeader('聊天设置'),
              _buildSwitchTile(
                title: '回车键发送',
                subtitle: '按回车键直接发送消息',
                value: settingsProvider.sendByEnter,
                onChanged: settingsProvider.setSendByEnter,
              ),
              
              const Divider(height: 32),
              
              // 隐私设置
              _buildSectionHeader('隐私设置'),
              _buildSwitchTile(
                title: '已读回执',
                subtitle: '向对方显示消息已读状态',
                value: settingsProvider.readReceiptEnabled,
                onChanged: settingsProvider.setReadReceiptEnabled,
              ),
              _buildSwitchTile(
                title: '最后在线时间',
                subtitle: '向好友显示最后在线时间',
                value: settingsProvider.lastSeenEnabled,
                onChanged: settingsProvider.setLastSeenEnabled,
              ),
              _buildNavigationTile(
                title: '免打扰设置',
                subtitle: '管理消息通知免打扰',
                icon: Icons.notifications_off,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DoNotDisturbPage(),
                    ),
                  );
                },
              ),
              
              const Divider(height: 32),
              
              // 其他设置
              _buildSectionHeader('其他'),
              _buildResetTile(settingsProvider),
              
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF07C160),
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF07C160)),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildThemeColorTile(settings.SettingsProvider settingsProvider) {
    return ListTile(
      title: const Text('主题颜色'),
      subtitle: Text(settingsProvider.themeColorName),
      trailing: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: settingsProvider.primaryColor,
          shape: BoxShape.circle,
        ),
      ),
      onTap: () => _showThemeColorDialog(settingsProvider),
    );
  }

  Widget _buildThemeModeTile(settings.SettingsProvider settingsProvider) {
    String modeText;
    switch (settingsProvider.themeMode) {
      case settings.ThemeMode.system:
        modeText = '跟随系统';
        break;
      case settings.ThemeMode.light:
        modeText = '浅色模式';
        break;
      case settings.ThemeMode.dark:
        modeText = '深色模式';
        break;
    }

    return ListTile(
      title: const Text('深色模式'),
      subtitle: Text(modeText),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeModeDialog(settingsProvider),
    );
  }

  Widget _buildFontSizeTile(settings.SettingsProvider settingsProvider) {
    return ListTile(
      title: const Text('字体大小'),
      subtitle: Text('${settingsProvider.fontSize.toInt()}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showFontSizeDialog(settingsProvider),
    );
  }

  Widget _buildServerAddressTile(settings.SettingsProvider settingsProvider) {
    return ListTile(
      title: const Text('服务器地址'),
      subtitle: Text(settingsProvider.serverAddress),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showServerAddressDialog(settingsProvider),
    );
  }

  Widget _buildResetTile(settings.SettingsProvider settingsProvider) {
    return ListTile(
      title: const Text(
        '重置所有设置',
        style: TextStyle(color: Colors.red),
      ),
      subtitle: const Text('将所有设置恢复为默认值'),
      trailing: const Icon(Icons.refresh, color: Colors.red),
      onTap: () => _showResetDialog(settingsProvider),
    );
  }

  void _showThemeColorDialog(settings.SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题颜色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: settings.ThemeColor.values.map((color) {
            String colorName;
            Color colorValue;
            switch (color) {
              case settings.ThemeColor.green:
                colorName = '微信绿';
                colorValue = const Color(0xFF07C160);
                break;
              case settings.ThemeColor.blue:
                colorName = '蓝色';
                colorValue = const Color(0xFF1976D2);
                break;
              case settings.ThemeColor.purple:
                colorName = '紫色';
                colorValue = const Color(0xFF7B1FA2);
                break;
              case settings.ThemeColor.orange:
                colorName = '橙色';
                colorValue = const Color(0xFFFF9800);
                break;
              case settings.ThemeColor.red:
                colorName = '红色';
                colorValue = const Color(0xFFD32F2F);
                break;
            }

            return RadioListTile<settings.ThemeColor>(
              title: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colorValue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(colorName),
                ],
              ),
              value: color,
              groupValue: settingsProvider.themeColor,
              onChanged: (value) {
                if (value != null) {
                  settingsProvider.setThemeColor(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showThemeModeDialog(settings.SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择深色模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<settings.ThemeMode>(
              title: const Text('跟随系统'),
              value: settings.ThemeMode.system,
              groupValue: settingsProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  settingsProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<settings.ThemeMode>(
              title: const Text('浅色模式'),
              value: settings.ThemeMode.light,
              groupValue: settingsProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  settingsProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<settings.ThemeMode>(
              title: const Text('深色模式'),
              value: settings.ThemeMode.dark,
              groupValue: settingsProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  settingsProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSizeDialog(settings.SettingsProvider settingsProvider) {
    double tempFontSize = settingsProvider.fontSize;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('字体大小'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '示例文字',
                style: TextStyle(fontSize: tempFontSize),
              ),
              const SizedBox(height: 16),
              Slider(
                value: tempFontSize,
                min: 12.0,
                max: 24.0,
                divisions: 12,
                label: tempFontSize.toInt().toString(),
                onChanged: (value) {
                  setState(() {
                    tempFontSize = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                settingsProvider.setFontSize(tempFontSize);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07C160),
                foregroundColor: Colors.white,
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _showServerAddressDialog(settings.SettingsProvider settingsProvider) {
    _serverAddressController.text = settingsProvider.serverAddress;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('服务器地址'),
        content: TextField(
          controller: _serverAddressController,
          decoration: const InputDecoration(
            hintText: '例如: localhost:8080',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final address = _serverAddressController.text.trim();
              if (address.isNotEmpty) {
                settingsProvider.setServerAddress(address);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('服务器地址已更新，重启应用后生效'),
                    backgroundColor: Color(0xFF07C160),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF07C160),
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(settings.SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置设置'),
        content: const Text('确定要将所有设置恢复为默认值吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              settingsProvider.resetAllSettings();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('设置已重置'),
                  backgroundColor: Color(0xFF07C160),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}