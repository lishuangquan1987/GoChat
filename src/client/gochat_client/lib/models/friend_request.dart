class FriendRequest {
  final int id;
  final int fromUserId;
  final int toUserId;
  final String? remark;
  final int status; // 0-待处理, 1-已接受, 2-已拒绝
  final DateTime createTime;
  final String? fromUserNickname;
  final String? fromUserAvatar;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.remark,
    required this.status,
    required this.createTime,
    this.fromUserNickname,
    this.fromUserAvatar,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as int,
      fromUserId: json['fromUserId'] as int,
      toUserId: json['toUserId'] as int,
      remark: json['remark'] as String?,
      status: json['status'] as int? ?? 0,
      createTime: DateTime.parse(json['createTime'] as String),
      fromUserNickname: json['fromUserNickname'] as String?,
      fromUserAvatar: json['fromUserAvatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'remark': remark,
      'status': status,
      'createTime': createTime.toIso8601String(),
      'fromUserNickname': fromUserNickname,
      'fromUserAvatar': fromUserAvatar,
    };
  }

  bool get isPending => status == 0;
  bool get isAccepted => status == 1;
  bool get isRejected => status == 2;
}
