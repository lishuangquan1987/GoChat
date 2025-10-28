import 'package:flutter/material.dart';
import '../models/do_not_disturb.dart';
import '../services/do_not_disturb_service.dart';

class DoNotDisturbPage extends StatefulWidget {
  const DoNotDisturbPage({super.key});

  @override
  State<DoNotDisturbPage> createState() => _DoNotDisturbPageState();
}

class _DoNotDisturbPageState extends State<DoNotDisturbPage> {
  final DoNotDisturbService _dndService = DoNotDisturbService();
  List<DoNotDisturbSetting> _settings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);
      final settings = await _dndService.getDoNotDisturbSettings();
      setState(() {
        _settings = settings ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('DEBUG DND PAGE: Error loading settings: $e');
      setState(() {
        _settings = [];
        _isLoading = false;
      });
      
      if (mounted) {
        // 检查是否是401认证错误
        if (e.toString().contains('401')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('认证已过期，请重新登录'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载免打扰设置失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('免打扰设置'),
        backgroundColor: const Color(0xFF07C160),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDoNotDisturbDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSettingsList(),
    );
  }

  Widget _buildSettingsList() {
    if (_settings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无免打扰设置',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '点击右上角 + 号添加免打扰设置',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _settings.length,
      itemBuilder: (context, index) {
        final setting = _settings[index];
        return _buildSettingItem(setting);
      },
    );
  }

  Widget _buildSettingItem(DoNotDisturbSetting setting) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: setting.isCurrentlyActive 
              ? Colors.red 
              : Colors.grey,
          child: Icon(
            _getIconForType(setting.type),
            color: Colors.white,
          ),
        ),
        title: Text(setting.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (setting.targetUserId != null)
              Text('用户ID: ${setting.targetUserId}'),
            if (setting.targetGroupId != null)
              Text('群组ID: ${setting.targetGroupId}'),
            Text(
              setting.isCurrentlyActive ? '生效中' : '未生效',
              style: TextStyle(
                color: setting.isCurrentlyActive 
                    ? Colors.red 
                    : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, setting),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('编辑'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(DoNotDisturbType type) {
    switch (type) {
      case DoNotDisturbType.private:
        return Icons.person;
      case DoNotDisturbType.group:
        return Icons.group;
      case DoNotDisturbType.global:
        return Icons.notifications_off;
    }
  }

  void _handleMenuAction(String action, DoNotDisturbSetting setting) {
    switch (action) {
      case 'edit':
        _showEditDoNotDisturbDialog(setting);
        break;
      case 'delete':
        _showDeleteConfirmDialog(setting);
        break;
    }
  }

  void _showAddDoNotDisturbDialog() {
    showDialog(
      context: context,
      builder: (context) => DoNotDisturbDialog(
        onSaved: () => _loadSettings(),
      ),
    );
  }

  void _showEditDoNotDisturbDialog(DoNotDisturbSetting setting) {
    showDialog(
      context: context,
      builder: (context) => DoNotDisturbDialog(
        setting: setting,
        onSaved: () => _loadSettings(),
      ),
    );
  }

  void _showDeleteConfirmDialog(DoNotDisturbSetting setting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除这个免打扰设置吗？\n\n${setting.description}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSetting(setting);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSetting(DoNotDisturbSetting setting) async {
    try {
      if (setting.isGlobal) {
        await _dndService.removeGlobalDoNotDisturb();
      } else if (setting.targetUserId != null) {
        await _dndService.removePrivateDoNotDisturb(setting.targetUserId!);
      } else if (setting.targetGroupId != null) {
        await _dndService.removeGroupDoNotDisturb(setting.targetGroupId!);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功')),
        );
      }
      _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
}

class DoNotDisturbDialog extends StatefulWidget {
  final DoNotDisturbSetting? setting;
  final VoidCallback onSaved;

  const DoNotDisturbDialog({
    super.key,
    this.setting,
    required this.onSaved,
  });

  @override
  State<DoNotDisturbDialog> createState() => _DoNotDisturbDialogState();
}

class _DoNotDisturbDialogState extends State<DoNotDisturbDialog> {
  final DoNotDisturbService _dndService = DoNotDisturbService();
  final TextEditingController _targetIdController = TextEditingController();
  
  DoNotDisturbType _selectedType = DoNotDisturbType.global;
  DoNotDisturbOption? _selectedOption;
  bool _isCustomTime = false;
  DateTime? _customStartTime;
  DateTime? _customEndTime;

  @override
  void initState() {
    super.initState();
    if (widget.setting != null) {
      _selectedType = widget.setting!.type;
      if (widget.setting!.targetUserId != null) {
        _targetIdController.text = widget.setting!.targetUserId.toString();
      } else if (widget.setting!.targetGroupId != null) {
        _targetIdController.text = widget.setting!.targetGroupId.toString();
      }
      _customStartTime = widget.setting!.startTime;
      _customEndTime = widget.setting!.endTime;
      _isCustomTime = _customStartTime != null || _customEndTime != null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.setting == null ? '添加免打扰' : '编辑免打扰'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 免打扰类型选择
            const Text('免打扰类型:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...DoNotDisturbType.values.map((type) => RadioListTile<DoNotDisturbType>(
              title: Text(type.displayName),
              subtitle: Text(type.description),
              value: type,
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                  _targetIdController.clear();
                });
              },
            )),
            
            // 目标ID输入（私聊或群聊时显示）
            if (_selectedType != DoNotDisturbType.global) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _targetIdController,
                decoration: InputDecoration(
                  labelText: _selectedType == DoNotDisturbType.private ? '用户ID' : '群组ID',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            
            const SizedBox(height: 16),
            const Text('免打扰时长:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            // 快速选项
            ...DoNotDisturbService.getQuickOptions().map((option) => RadioListTile<DoNotDisturbOption>(
              title: Text(option.title),
              value: option,
              groupValue: _selectedOption,
              onChanged: (value) {
                setState(() {
                  _selectedOption = value;
                  _isCustomTime = false;
                });
              },
            )),
            
            // 自定义时间选项
            RadioListTile<bool>(
              title: const Text('自定义时间'),
              value: true,
              groupValue: _isCustomTime,
              onChanged: (value) {
                setState(() {
                  _isCustomTime = value!;
                  _selectedOption = null;
                });
              },
            ),
            
            // 自定义时间选择器
            if (_isCustomTime) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _selectDateTime(true),
                      child: Text(
                        _customStartTime == null 
                            ? '选择开始时间' 
                            : '开始: ${_formatDateTime(_customStartTime!)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => _selectDateTime(false),
                      child: Text(
                        _customEndTime == null 
                            ? '选择结束时间' 
                            : '结束: ${_formatDateTime(_customEndTime!)}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _saveSetting,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _selectDateTime(bool isStartTime) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (time != null) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        
        setState(() {
          if (isStartTime) {
            _customStartTime = dateTime;
          } else {
            _customEndTime = dateTime;
          }
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveSetting() async {
    try {
      // 验证输入
      if (_selectedType != DoNotDisturbType.global && _targetIdController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请输入${_selectedType == DoNotDisturbType.private ? '用户' : '群组'}ID')),
        );
        return;
      }

      DateTime? startTime;
      DateTime? endTime;

      if (_selectedOption != null) {
        startTime = DateTime.now();
        endTime = _selectedOption!.endTime;
      } else if (_isCustomTime) {
        startTime = _customStartTime;
        endTime = _customEndTime;
      }

      // 保存设置
      switch (_selectedType) {
        case DoNotDisturbType.global:
          await _dndService.setGlobalDoNotDisturb(
            startTime: startTime,
            endTime: endTime,
          );
          break;
        case DoNotDisturbType.private:
          final targetUserId = int.parse(_targetIdController.text);
          await _dndService.setPrivateDoNotDisturb(
            targetUserId: targetUserId,
            startTime: startTime,
            endTime: endTime,
          );
          break;
        case DoNotDisturbType.group:
          final targetGroupId = int.parse(_targetIdController.text);
          await _dndService.setGroupDoNotDisturb(
            targetGroupId: targetGroupId,
            startTime: startTime,
            endTime: endTime,
          );
          break;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }
}