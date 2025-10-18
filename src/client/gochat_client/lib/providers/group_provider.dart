import 'package:flutter/foundation.dart';
import '../models/group.dart';

class GroupProvider with ChangeNotifier {
  final List<Group> _groups = [];

  List<Group> get groups => _groups;

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
}
