/// 免打扰设置模型
class DoNotDisturbSetting {
  final int id;
  final int userId;
  final int? targetUserId;
  final int? targetGroupId;
  final bool isGlobal;
  final DateTime? startTime;
  final DateTime? endTime;
  final DoNotDisturbType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  DoNotDisturbSetting({
    required this.id,
    required this.userId,
    this.targetUserId,
    this.targetGroupId,
    required this.isGlobal,
    this.startTime,
    this.endTime,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DoNotDisturbSetting.fromJson(Map<String, dynamic> json) {
    return DoNotDisturbSetting(
      id: json['id'] as int,
      userId: json['userId'] as int,
      targetUserId: json['targetUserId'] as int?,
      targetGroupId: json['targetGroupId'] as int?,
      isGlobal: json['isGlobal'] as bool,
      startTime: json['startTime'] != null 
          ? DateTime.parse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime'] as String)
          : null,
      type: DoNotDisturbType.values[json['type'] as int],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'targetUserId': targetUserId,
      'targetGroupId': targetGroupId,
      'isGlobal': isGlobal,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'type': type.index,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 检查当前是否处于免打扰时间段
  bool get isCurrentlyActive {
    if (startTime == null && endTime == null) {
      // 永久免打扰
      return true;
    }
    
    if (startTime != null && endTime != null) {
      final now = DateTime.now();
      return now.isAfter(startTime!) && now.isBefore(endTime!);
    }
    
    return false;
  }

  /// 获取免打扰描述文本
  String get description {
    if (isGlobal) {
      if (startTime == null && endTime == null) {
        return '全局免打扰';
      } else {
        return '全局免打扰 (${_formatTimeRange()})';
      }
    } else if (targetUserId != null) {
      if (startTime == null && endTime == null) {
        return '私聊免打扰';
      } else {
        return '私聊免打扰 (${_formatTimeRange()})';
      }
    } else if (targetGroupId != null) {
      if (startTime == null && endTime == null) {
        return '群聊免打扰';
      } else {
        return '群聊免打扰 (${_formatTimeRange()})';
      }
    }
    return '免打扰';
  }

  String _formatTimeRange() {
    if (startTime == null || endTime == null) return '';
    
    final start = startTime!;
    final end = endTime!;
    
    // 如果是同一天
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return '${_formatTime(start)} - ${_formatTime(end)}';
    } else {
      return '${_formatDateTime(start)} - ${_formatDateTime(end)}';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime time) {
    return '${time.month}/${time.day} ${_formatTime(time)}';
  }
}

/// 免打扰类型
enum DoNotDisturbType {
  private,  // 私聊免打扰
  group,    // 群聊免打扰
  global,   // 全局免打扰
}

extension DoNotDisturbTypeExtension on DoNotDisturbType {
  String get displayName {
    switch (this) {
      case DoNotDisturbType.private:
        return '私聊免打扰';
      case DoNotDisturbType.group:
        return '群聊免打扰';
      case DoNotDisturbType.global:
        return '全局免打扰';
    }
  }

  String get description {
    switch (this) {
      case DoNotDisturbType.private:
        return '设置后将不会收到该用户的消息通知';
      case DoNotDisturbType.group:
        return '设置后将不会收到该群组的消息通知';
      case DoNotDisturbType.global:
        return '设置后将不会收到任何消息通知';
    }
  }
}