enum MessageType {
  text(1),
  image(2),
  video(3);

  final int value;
  const MessageType(this.value);

  static MessageType fromValue(int value) {
    return MessageType.values.firstWhere((e) => e.value == value);
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class Message {
  final String msgId;
  final int fromUserId;
  final int toUserId;
  final MessageType msgType;
  final String content;
  final bool isGroup;
  final int? groupId;
  final DateTime createTime;
  MessageStatus status;

  Message({
    required this.msgId,
    required this.fromUserId,
    required this.toUserId,
    required this.msgType,
    required this.content,
    this.isGroup = false,
    this.groupId,
    required this.createTime,
    this.status = MessageStatus.sent,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      msgId: json['msgId'] as String,
      fromUserId: json['fromUserId'] as int,
      toUserId: json['toUserId'] as int,
      msgType: MessageType.fromValue(json['msgType'] as int),
      content: json['content'] as String,
      isGroup: json['isGroup'] as bool? ?? false,
      groupId: json['groupId'] as int?,
      createTime: DateTime.parse(json['createTime'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'msgId': msgId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'msgType': msgType.value,
      'content': content,
      'isGroup': isGroup,
      'groupId': groupId,
      'createTime': createTime.toIso8601String(),
    };
  }

  bool get isMine => false; // 将在使用时根据当前用户判断
}
