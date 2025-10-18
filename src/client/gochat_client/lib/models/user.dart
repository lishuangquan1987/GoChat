class User {
  final int id;
  final String username;
  final String nickname;
  final int sex;
  final String? avatar;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.sex,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      nickname: json['nickname'] as String,
      sex: json['sex'] as int? ?? 0,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'sex': sex,
      'avatar': avatar,
    };
  }
}
