import 'package:flutter/foundation.dart';
import '../models/user.dart';

class FriendProvider with ChangeNotifier {
  final List<User> _friends = [];
  final List<dynamic> _friendRequests = [];

  List<User> get friends => _friends;
  List<dynamic> get friendRequests => _friendRequests;

  void setFriends(List<User> friends) {
    _friends.clear();
    _friends.addAll(friends);
    notifyListeners();
  }

  void setFriendRequests(List<dynamic> requests) {
    _friendRequests.clear();
    _friendRequests.addAll(requests);
    notifyListeners();
  }

  void addFriend(User friend) {
    _friends.add(friend);
    notifyListeners();
  }

  void removeFriend(int friendId) {
    _friends.removeWhere((f) => f.id == friendId);
    notifyListeners();
  }
}
