import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../models/user.dart';

class GroupProvider with ChangeNotifier {
  final List<Group> _groups = [];
  final Map<int, List<User>> _groupMembers = {};

  List<Group> get groups => _groups;
  Map<int, List<User>> get groupMembers => _groupMembers;

  void setGroups(List<Group> groups) {
    _groups.clear();
    _groups.addAll(groups);
    notifyListeners();
  }

  void addGroup(Group group) {
    _groups.add(group);
    notifyListeners();
  }

  void removeGroup(int groupId) {
    _groups.removeWhere((g) => g.id == groupId);
    notifyListeners();
  }

  void updateGroup(Group group) {
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      _groups[index] = group;
      notifyListeners();
    }
  }

  void setGroupMembers(int groupId, List<User> members) {
    _groupMembers[groupId] = members;
    notifyListeners();
  }

  List<User>? getGroupMembers(int groupId) {
    return _groupMembers[groupId];
  }

  void addGroupMember(int groupId, User member) {
    if (!_groupMembers.containsKey(groupId)) {
      _groupMembers[groupId] = [];
    }
    if (!_groupMembers[groupId]!.any((m) => m.id == member.id)) {
      _groupMembers[groupId]!.add(member);
      
      // 更新群组的成员列表
      final groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        final group = _groups[groupIndex];
        if (!group.members.contains(member.id)) {
          final updatedMembers = [...group.members, member.id];
          _groups[groupIndex] = Group(
            id: group.id,
            groupId: group.groupId,
            groupName: group.groupName,
            ownerId: group.ownerId,
            createUserId: group.createUserId,
            createTime: group.createTime,
            members: updatedMembers,
          );
        }
      }
      
      notifyListeners();
    }
  }

  void removeGroupMember(int groupId, int userId) {
    if (_groupMembers.containsKey(groupId)) {
      _groupMembers[groupId]!.removeWhere((m) => m.id == userId);
      
      // 更新群组的成员列表
      final groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        final group = _groups[groupIndex];
        final updatedMembers = group.members.where((id) => id != userId).toList();
        _groups[groupIndex] = Group(
          id: group.id,
          groupId: group.groupId,
          groupName: group.groupName,
          ownerId: group.ownerId,
          createUserId: group.createUserId,
          createTime: group.createTime,
          members: updatedMembers,
        );
      }
      
      notifyListeners();
    }
  }

  Group? getGroupById(int groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (e) {
      return null;
    }
  }

  bool isGroupOwner(int groupId, int userId) {
    final group = getGroupById(groupId);
    return group?.ownerId == userId;
  }

  bool isGroupMember(int groupId, int userId) {
    final group = getGroupById(groupId);
    return group?.members.contains(userId) ?? false;
  }
}
