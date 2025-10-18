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
}
