class User {
  final int id;
  final String username;
  final String nickname;
  final int sex;
  final String? avatar;
  final String? signature;
  final String? region;
  final DateTime? birthday;
  final DateTime? lastSeen;
  final String? status; // online, offline, busy, away

  User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.sex,
    this.avatar,
    this.signature,
    this.region,
    this.birthday,
    this.lastSeen,
    this.status,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      nickname: json['nickname'] as String,
      sex: json['sex'] as int? ?? 0,
      avatar: json['avatar'] as String?,
      signature: json['signature'] as String?,
      region: json['region'] as String?,
      birthday: json['birthday'] != null 
          ? DateTime.tryParse(json['birthday'] as String)
          : null,
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String)
          : null,
      status: json['status'] as String? ?? 'offline',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'sex': sex,
      'avatar': avatar,
      'signature': signature,
      'region': region,
      'birthday': birthday?.toIso8601String(),
      'lastSeen': lastSeen?.toIso8601String(),
      'status': status,
    };
  }

  // 格式化生日显示
  String get formattedBirthday {
    if (birthday == null) return '';
    return '${birthday!.year}-${birthday!.month.toString().padLeft(2, '0')}-${birthday!.day.toString().padLeft(2, '0')}';
  }

  // 获取在线状态文本
  String get statusText {
    switch (status) {
      case 'online':
        return '在线';
      case 'offline':
        return '离线';
      case 'busy':
        return '忙碌';
      case 'away':
        return '离开';
      default:
        return '离线';
    }
  }

  // 判断是否在线
  bool get isOnline => status == 'online';

  // 格式化最后在线时间
  String get formattedLastSeen {
    if (lastSeen == null) return '从未在线';
    final now = DateTime.now();
    final difference = now.difference(lastSeen!);
    
    if (difference.inDays > 7) {
      return '${lastSeen!.year}-${lastSeen!.month.toString().padLeft(2, '0')}-${lastSeen!.day.toString().padLeft(2, '0')}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}
