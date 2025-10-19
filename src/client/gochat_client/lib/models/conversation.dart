import 'user.dart';
import 'group.dart';
import 'message.dart';

enum ConversationType {
  private,
  group,
}

class Conversation {
  final String id;
  final ConversationType type;
  final User? user;
  final Group? group;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime? lastTime;

  Conversation({
    required this.id,
    required this.type,
    this.user,
    this.group,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastTime,
  });

  String get title {
    if (type == ConversationType.private) {
      return user?.nickname ?? 'Unknown';
    } else {
      return group?.groupName ?? 'Unknown Group';
    }
  }

  String? get avatar {
    if (type == ConversationType.private) {
      return user?.avatar;
    } else {
      return null; // 群组头像
    }
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      type: ConversationType.values[json['type'] as int],
      user: json['user'] != null ? User.fromJson(json['user'] as Map<String, dynamic>) : null,
      group: json['group'] != null ? Group.fromJson(json['group'] as Map<String, dynamic>) : null,
      lastMessage: json['lastMessage'] != null ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>) : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      lastTime: json['lastTime'] != null ? DateTime.parse(json['lastTime'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'user': user?.toJson(),
      'group': group?.toJson(),
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'lastTime': lastTime?.toIso8601String(),
    };
  }
}
