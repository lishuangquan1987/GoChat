import 'package:dio/dio.dart';
import '../models/do_not_disturb.dart';
import 'storage_service.dart';

/// 免打扰服务
class DoNotDisturbService {
  static const String baseUrl = 'http://localhost:8080/api';
  late final Dio _dio;

  DoNotDisturbService() {
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
        final token = await _getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<String?> _getToken() async {
    return await StorageService.getToken();
  }

  /// 设置私聊免打扰
  Future<void> setPrivateDoNotDisturb({
    required int targetUserId,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      await _dio.post('/donotdisturb/private', data: {
        'targetUserId': targetUserId,
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
      });
    } catch (e) {
      throw Exception('设置私聊免打扰失败: $e');
    }
  }

  /// 设置群聊免打扰
  Future<void> setGroupDoNotDisturb({
    required int targetGroupId,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      await _dio.post('/donotdisturb/group', data: {
        'targetGroupId': targetGroupId,
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
      });
    } catch (e) {
      throw Exception('设置群聊免打扰失败: $e');
    }
  }

  /// 设置全局免打扰
  Future<void> setGlobalDoNotDisturb({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      await _dio.post('/donotdisturb/global', data: {
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
      });
    } catch (e) {
      throw Exception('设置全局免打扰失败: $e');
    }
  }

  /// 移除私聊免打扰
  Future<void> removePrivateDoNotDisturb(int targetUserId) async {
    try {
      await _dio.delete('/donotdisturb/private/$targetUserId');
    } catch (e) {
      throw Exception('移除私聊免打扰失败: $e');
    }
  }

  /// 移除群聊免打扰
  Future<void> removeGroupDoNotDisturb(int targetGroupId) async {
    try {
      await _dio.delete('/donotdisturb/group/$targetGroupId');
    } catch (e) {
      throw Exception('移除群聊免打扰失败: $e');
    }
  }

  /// 移除全局免打扰
  Future<void> removeGlobalDoNotDisturb() async {
    try {
      await _dio.delete('/donotdisturb/global');
    } catch (e) {
      throw Exception('移除全局免打扰失败: $e');
    }
  }

  /// 获取免打扰设置列表
  Future<List<DoNotDisturbSetting>> getDoNotDisturbSettings() async {
    try {
      final response = await _dio.get('/donotdisturb/settings');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data.map((json) => DoNotDisturbSetting.fromJson(json)).toList();
    } catch (e) {
      throw Exception('获取免打扰设置失败: $e');
    }
  }

  /// 检查免打扰状态
  Future<bool> checkDoNotDisturbStatus({
    int? targetUserId,
    int? targetGroupId,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (targetUserId != null) {
        params['targetUserId'] = targetUserId.toString();
      }
      if (targetGroupId != null) {
        params['targetGroupId'] = targetGroupId.toString();
      }

      final response = await _dio.get(
        '/donotdisturb/status',
        queryParameters: params,
      );
      return response.data['data']['isActive'] as bool;
    } catch (e) {
      throw Exception('检查免打扰状态失败: $e');
    }
  }

  /// 快速设置免打扰选项
  static List<DoNotDisturbOption> getQuickOptions() {
    return [
      DoNotDisturbOption(
        title: '1小时',
        duration: const Duration(hours: 1),
      ),
      DoNotDisturbOption(
        title: '4小时',
        duration: const Duration(hours: 4),
      ),
      DoNotDisturbOption(
        title: '8小时',
        duration: const Duration(hours: 8),
      ),
      DoNotDisturbOption(
        title: '24小时',
        duration: const Duration(hours: 24),
      ),
      DoNotDisturbOption(
        title: '永久',
        duration: null,
      ),
    ];
  }
}

/// 免打扰快速选项
class DoNotDisturbOption {
  final String title;
  final Duration? duration;

  DoNotDisturbOption({
    required this.title,
    this.duration,
  });

  /// 获取结束时间
  DateTime? get endTime {
    if (duration == null) return null;
    return DateTime.now().add(duration!);
  }

  /// 是否为永久免打扰
  bool get isPermanent => duration == null;
}