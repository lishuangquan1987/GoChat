import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../models/user.dart';
import '../providers/user_provider.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _signatureController = TextEditingController();
  final _regionController = TextEditingController();
  final _apiService = ApiService();
  final _imagePicker = ImagePicker();
  
  String? _avatarUrl;
  File? _avatarFile;
  int? _selectedSex;
  DateTime? _selectedBirthday;
  String? _selectedStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    
    if (user != null) {
      _nicknameController.text = user.nickname;
      _signatureController.text = user.signature ?? '';
      _regionController.text = user.region ?? '';
      _selectedSex = user.sex;
      _selectedBirthday = user.birthday;
      _selectedStatus = user.status ?? 'online';
      _avatarUrl = user.avatar;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _signatureController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _avatarFile = File(pickedFile.path);
          _avatarUrl = null; // 清除网络头像，使用本地文件
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
    return;
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择头像'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_avatarUrl != null || _avatarFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除头像', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _avatarFile = null;
                    _avatarUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBirthday() async {
    final initialDate = _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 20));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? avatarUrl = _avatarUrl;
      
      // 如果有新选择的头像文件，先上传
      if (_avatarFile != null) {
        try {
          final uploadResponse = await _apiService.uploadFile(
            _avatarFile!.path,
            'image',
          );
          if (uploadResponse.data['code'] == 0) {
            avatarUrl = uploadResponse.data['data']['url'] as String?;
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('头像上传失败: $e')),
            );
          }
        }
      }

      // 更新用户资料
      final response = await _apiService.updateUserProfile(
        nickname: _nicknameController.text.trim(),
        sex: _selectedSex,
        avatar: avatarUrl,
        signature: _signatureController.text.trim().isEmpty 
            ? null 
            : _signatureController.text.trim(),
        region: _regionController.text.trim().isEmpty 
            ? null 
            : _regionController.text.trim(),
        birthday: _selectedBirthday != null
            ? '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}'
            : null,
        status: _selectedStatus,
      );

      if (response.data['code'] == 0) {
        // 更新本地用户信息
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final currentUser = userProvider.currentUser;
        if (currentUser != null) {
          final updatedUser = User(
            id: currentUser.id,
            username: currentUser.username,
            nickname: _nicknameController.text.trim(),
            sex: _selectedSex ?? 0,
            avatar: avatarUrl,
            signature: _signatureController.text.trim().isEmpty 
                ? null 
                : _signatureController.text.trim(),
            region: _regionController.text.trim().isEmpty 
                ? null 
                : _regionController.text.trim(),
            birthday: _selectedBirthday,
            lastSeen: currentUser.lastSeen,
            status: _selectedStatus,
          );
          userProvider.updateUser(updatedUser);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('资料更新成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? '更新失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAvatar() {
    if (_avatarFile != null) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: FileImage(_avatarFile!),
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: NetworkImage(_avatarUrl!),
        onBackgroundImageError: (_, __) {
          setState(() {
            _avatarUrl = null;
          });
        },
      );
    } else {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      return CircleAvatar(
        radius: 50,
        backgroundColor: const Color(0xFF07C160),
        child: Text(
          user?.nickname.isNotEmpty == true
              ? user!.nickname[0].toUpperCase()
              : 'U',
          style: const TextStyle(fontSize: 32, color: Colors.white),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        backgroundColor: const Color(0xFF07C160),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 头像
            Center(
              child: GestureDetector(
                onTap: _showImageSourceDialog,
                child: Stack(
                  children: [
                    _buildAvatar(),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF07C160),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 昵称
            TextFormField(
              controller: _nicknameController,
              decoration: InputDecoration(
                labelText: '昵称',
                hintText: '请输入昵称',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '昵称不能为空';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // 性别
            DropdownButtonFormField<int>(
              value: _selectedSex,
              decoration: InputDecoration(
                labelText: '性别',
                prefixIcon: const Icon(Icons.wc_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('男')),
                DropdownMenuItem(value: 1, child: Text('女')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedSex = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // 个人签名
            TextFormField(
              controller: _signatureController,
              decoration: InputDecoration(
                labelText: '个人签名',
                hintText: '请输入个人签名',
                prefixIcon: const Icon(Icons.edit_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            
            // 地区
            TextFormField(
              controller: _regionController,
              decoration: InputDecoration(
                labelText: '地区',
                hintText: '请输入所在地区',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 生日
            InkWell(
              onTap: _selectBirthday,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '生日',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selectedBirthday != null
                      ? '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}'
                      : '请选择生日',
                  style: TextStyle(
                    color: _selectedBirthday != null 
                        ? Colors.black 
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 在线状态
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: '在线状态',
                prefixIcon: const Icon(Icons.circle),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'online', child: Text('在线')),
                DropdownMenuItem(value: 'offline', child: Text('离线')),
                DropdownMenuItem(value: 'busy', child: Text('忙碌')),
                DropdownMenuItem(value: 'away', child: Text('离开')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
            const SizedBox(height: 32),
            
            // 保存按钮
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07C160),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

