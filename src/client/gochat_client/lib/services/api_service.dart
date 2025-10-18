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
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // 统一错误处理
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
