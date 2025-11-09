import 'package:dio/dio.dart';
import 'storage_service.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api';
  
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 添加 token
        final token = await StorageService.getToken();
        print('DEBUG API: Token from storage: $token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          print('DEBUG API: Added Authorization header');
        } else {
          print('DEBUG API: No token available for request to ${options.path}');
        }
        print('DEBUG API: Request headers: ${options.headers}');
        return handler.next(options);
      },
      onError: (error, handler) async {
        // 统一错误处理
        print('DEBUG API: Error occurred: ${error.response?.statusCode} - ${error.message}');
        if (error.response?.statusCode == 401) {
          print('DEBUG API: 401 Unauthorized - Token may be invalid or expired');
          // 清除无效的token和用户数据
          await StorageService.deleteToken();
          await StorageService.deleteUser();
          print('DEBUG API: Cleared invalid token and user data');
        }
        return handler.next(error);
      },
    ));
  }

  // 用户相关
  Future<Response> register(String username, String password, String nickname, int sex) {
    return _dio.post('/user/register', data: {
      'username': username,
      'password': password,
      'nickname': nickname,
      'sex': sex,
    });
  }

  Future<Response> login(String username, String password) {
    return _dio.post('/user/login', data: {
      'username': username,
      'password': password,
    });
  }

  Future<Response> getProfile() {
    return _dio.get('/user/profile');
  }

  Future<Response> updateProfile(String nickname, int sex) {
    return _dio.put('/user/profile', data: {
      'nickname': nickname,
      'sex': sex,
    });
  }

  Future<Response> updateUserProfile({
    String? nickname,
    int? sex,
    String? avatar,
    String? signature,
    String? region,
    String? birthday,
    String? status,
  }) {
    final data = <String, dynamic>{};
    if (nickname != null) data['nickname'] = nickname;
    if (sex != null) data['sex'] = sex;
    if (avatar != null) data['avatar'] = avatar;
    if (signature != null) data['signature'] = signature;
    if (region != null) data['region'] = region;
    if (birthday != null) data['birthday'] = birthday;
    if (status != null) data['status'] = status;
    return _dio.put('/user/profile', data: data);
  }

  Future<Response> searchUsers(String keyword, {bool excludeFriends = false, int limit = 20}) {
    return _dio.get('/user/search', queryParameters: {
      'keyword': keyword,
      'excludeFriends': excludeFriends,
      'limit': limit,
    });
  }

  Future<Response> logout() {
    return _dio.post('/user/logout');
  }

  // 好友相关
  Future<Response> getFriendList() {
    return _dio.get('/friends');
  }

  Future<Response> sendFriendRequest(int friendId, String remark) {
    return _dio.post('/friends/request', data: {
      'friendId': friendId,
      'remark': remark,
    });
  }

  Future<Response> acceptFriendRequest(int requestId) {
    return _dio.post('/friends/accept', data: {
      'requestId': requestId,
    });
  }

  Future<Response> rejectFriendRequest(int requestId) {
    return _dio.post('/friends/reject', data: {
      'requestId': requestId,
    });
  }

  Future<Response> getFriendRequests() {
    return _dio.get('/friends/requests');
  }

  Future<Response> deleteFriend(int friendId) {
    return _dio.delete('/friends/$friendId');
  }

  Future<Response> updateFriendRemark(int friendId, {
    String? remarkName,
    String? category,
    List<String>? tags,
  }) {
    final data = <String, dynamic>{};
    if (remarkName != null) data['remarkName'] = remarkName;
    if (category != null) data['category'] = category;
    if (tags != null) data['tags'] = tags;
    return _dio.put('/friends/$friendId/remark', data: data);
  }

  Future<Response> getFriendWithRemark(int friendId) {
    return _dio.get('/friends/$friendId');
  }

  // 消息相关
  Future<Response> sendMessage(int toUserId, int msgType, String content, {int? groupId}) {
    return _dio.post('/messages/send', data: {
      'toUserId': toUserId,
      'msgType': msgType,
      'content': content,
      if (groupId != null) 'groupId': groupId,
    });
  }

  Future<Response> getChatHistory({int? friendId, int? groupId, int page = 1, int pageSize = 20}) {
    return _dio.get('/messages/history', queryParameters: {
      if (friendId != null) 'friendId': friendId,
      if (groupId != null) 'groupId': groupId,
      'page': page,
      'pageSize': pageSize,
    });
  }

  Future<Response> getConversationList() {
    return _dio.get('/messages/conversations');
  }

  Future<Response> getOfflineMessages() {
    return _dio.get('/messages/offline');
  }

  Future<Response> uploadFile(String filePath, String type) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'type': type,
    });
    return _dio.post('/messages/upload', data: formData);
  }

  Future<Response> recallMessage(String msgId) {
    return _dio.post('/messages/recall', data: {
      'msgId': msgId,
    });
  }

  Future<Response> getUnreadMessageCount({int? friendId, int? groupId}) {
    final queryParameters = <String, dynamic>{};
    if (friendId != null) queryParameters['friendId'] = friendId;
    if (groupId != null) queryParameters['groupId'] = groupId;
    return _dio.get('/messages/unread', queryParameters: queryParameters);
  }

  Future<Response> markAllMessagesAsRead({int? friendId, int? groupId}) {
    final queryParameters = <String, dynamic>{};
    if (friendId != null) queryParameters['friendId'] = friendId;
    if (groupId != null) queryParameters['groupId'] = groupId;
    return _dio.post('/messages/readall', queryParameters: queryParameters);
  }

  // 群组相关
  Future<Response> createGroup(String groupName, List<int> memberIds) {
    return _dio.post('/groups', data: {
      'groupName': groupName,
      'memberIds': memberIds,
    });
  }

  Future<Response> getGroupList() {
    return _dio.get('/groups');
  }

  Future<Response> getGroupDetail(int groupId) {
    return _dio.get('/groups/$groupId');
  }

  Future<Response> addGroupMembers(int groupId, List<int> userIds) {
    return _dio.post('/groups/$groupId/members', data: {
      'userIds': userIds,
    });
  }

  Future<Response> removeGroupMember(int groupId, int userId) {
    return _dio.delete('/groups/$groupId/members/$userId');
  }

  Future<Response> getGroupMembers(int groupId) {
    return _dio.get('/groups/$groupId/members');
  }
}
