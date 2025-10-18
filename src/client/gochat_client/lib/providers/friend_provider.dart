import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/friend_request.dart';

class FriendProvider with ChangeNotifier {
  final List<User> _friends = [];
  final List<FriendRequest> _friendRequests = [];

  List<User> get friends => _friends;
  List<FriendRequest> get friendRequests => _friendRequests;

  void setFriends(List<User> friends) {
    _friends.clear();
    _friends.addAll(friends);
    notifyListeners();
  }

  void setFriendRequests(List<FriendRequest> requests) {
    _friendRequests.clear();
    _friendRequests.addAll(requests);
    notifyListeners();
  }

  void addFriend(User friend) {
    if (!_friends.any((f) => f.id == friend.id)) {
      _friends.add(friend);
      notifyListeners();
    }
  }

  void removeFriend(int friendId) {
    _friends.removeWhere((f) => f.id == friendId);
    notifyListeners();
  }

  void addFriendRequest(FriendRequest request) {
    if (!_friendRequests.any((r) => r.id == request.id)) {
      _friendRequests.insert(0, request);
      notifyListeners();
    }
  }

  void updateFriendRequest(int requestId, int status) {
    final index = _friendRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final oldRequest = _friendRequests[index];
      _friendRequests[index] = FriendRequest(
        id: oldRequest.id,
        fromUserId: oldRequest.fromUserId,
        toUserId: oldRequest.toUserId,
        remark: oldRequest.remark,
        status: status,
        createTime: oldRequest.createTime,
        fromUserNickname: oldRequest.fromUserNickname,
        fromUserAvatar: oldRequest.fromUserAvatar,
      );
      notifyListeners();
    }
  }

  void removeFriendRequest(int requestId) {
    _friendRequests.removeWhere((r) => r.id == requestId);
    notifyListeners();
  }

  List<FriendRequest> get pendingRequests {
    return _friendRequests.where((r) => r.isPending).toList();
  }

  int get pendingRequestCount {
    return _friendRequests.where((r) => r.isPending).length;
  }
}
