import 'user.dart';

class FriendRemark {
  final int userId;
  final int friendId;
  final String? remarkName;
  final String? category;
  final List<String> tags;

  FriendRemark({
    required this.userId,
    required this.friendId,
    this.remarkName,
    this.category,
    this.tags = const [],
  });

  factory FriendRemark.fromJson(Map<String, dynamic> json) {
    return FriendRemark(
      userId: json['userId'] as int,
      friendId: json['friendId'] as int,
      remarkName: json['remarkName'] as String?,
      category: json['category'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'friendId': friendId,
      'remarkName': remarkName,
      'category': category,
      'tags': tags,
    };
  }

  // 获取显示名称（优先使用备注名，否则使用昵称）
  String getDisplayName(User friend) {
    return remarkName?.isNotEmpty == true ? remarkName! : friend.nickname;
  }
}

