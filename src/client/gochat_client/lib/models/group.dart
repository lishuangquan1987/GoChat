class Group {
  final int id;
  final String groupId;
  final String groupName;
  final int ownerId;
  final int createUserId;
  final DateTime createTime;
  final List<int> members;

  Group({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.ownerId,
    required this.createUserId,
    required this.createTime,
    required this.members,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as int,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      ownerId: json['ownerId'] as int,
      createUserId: json['createUserId'] as int,
      createTime: DateTime.parse(json['createTime'] as String),
      members: (json['members'] as List<dynamic>).cast<int>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'groupName': groupName,
      'ownerId': ownerId,
      'createUserId': createUserId,
      'createTime': createTime.toIso8601String(),
      'members': members,
    };
  }

  int get memberCount => members.length;
}
