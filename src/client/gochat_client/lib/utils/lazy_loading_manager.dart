import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../utils/performance_monitor.dart';

class LazyLoadingManager {
  static final LazyLoadingManager _instance = LazyLoadingManager._internal();
  factory LazyLoadingManager() => _instance;
  LazyLoadingManager._internal();

  final ApiService _apiService = ApiService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  
  // 预加载缓存
  final Map<String, List<Message>> _preloadCache = {};
  final Set<String> _loadingConversations = {};
  
  // 配置参数
  static const int _pageSize = 20;
  static const int _preloadThreshold = 5; // 剩余消息数量阈值，触发预加载
  static const int _maxPreloadPages = 2; // 最多预加载的页数

  /// 智能预加载消息
  Future<void> preloadMessages({
    required String conversationId,
    required int currentPage,
    int? friendId,
    int? groupId,
  }) async {
    // 避免重复加载
    if (_loadingConversations.contains(conversationId)) {
      return;
    }

    _loadingConversations.add(conversationId);
    _performanceMonitor.startTimer('preload_messages_$conversationId');

    try {
      final futures = <Future<void>>[];
      
      // 预加载接下来的几页
      for (int i = 1; i <= _maxPreloadPages; i++) {
        final nextPage = currentPage + i;
        final cacheKey = '${conversationId}_page_$nextPage';
        
        // 如果已经缓存，跳过
        if (_preloadCache.containsKey(cacheKey)) {
          continue;
        }
        
        futures.add(_loadPage(
          conversationId: conversationId,
          page: nextPage,
          friendId: friendId,
          groupId: groupId,
          cacheKey: cacheKey,
        ));
      }
      
      await Future.wait(futures);
      
      if (kDebugMode) {
        debugPrint('Preloaded ${futures.length} pages for conversation: $conversationId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to preload messages for $conversationId: $e');
      }
    } finally {
      _loadingConversations.remove(conversationId);
      _performanceMonitor.endTimer('preload_messages_$conversationId');
    }
  }

  /// 加载单页消息
  Future<void> _loadPage({
    required String conversationId,
    required int page,
    int? friendId,
    int? groupId,
    required String cacheKey,
  }) async {
    try {
      final response = await _apiService.getChatHistory(
        friendId: friendId,
        groupId: groupId,
        page: page,
        pageSize: _pageSize,
      );

      if (response.data['code'] == 0) {
        final messages = (response.data['data']['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        
        _preloadCache[cacheKey] = messages;
        
        // 限制缓存大小，移除最旧的缓存
        if (_preloadCache.length > 20) {
          final oldestKey = _preloadCache.keys.first;
          _preloadCache.remove(oldestKey);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load page $page for $conversationId: $e');
      }
    }
  }

  /// 获取预加载的消息
  List<Message>? getPreloadedMessages(String conversationId, int page) {
    final cacheKey = '${conversationId}_page_$page';
    return _preloadCache[cacheKey];
  }

  /// 检查是否需要触发预加载
  bool shouldPreload({
    required String conversationId,
    required int currentMessageCount,
    required int currentPage,
    required bool hasMoreMessages,
  }) {
    if (!hasMoreMessages) return false;
    
    // 当剩余消息数量少于阈值时触发预加载
    final remainingInCurrentPage = _pageSize - (currentMessageCount % _pageSize);
    return remainingInCurrentPage <= _preloadThreshold;
  }

  /// 清理特定会话的缓存
  void clearConversationCache(String conversationId) {
    _preloadCache.removeWhere((key, _) => key.startsWith(conversationId));
    _loadingConversations.remove(conversationId);
  }

  /// 清理所有缓存
  void clearAllCache() {
    _preloadCache.clear();
    _loadingConversations.clear();
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_pages': _preloadCache.length,
      'loading_conversations': _loadingConversations.length,
      'cache_keys': _preloadCache.keys.toList(),
    };
  }
}

/// 懒加载配置
class LazyLoadingConfig {
  static const int defaultPageSize = 20;
  static const int preloadThreshold = 5;
  static const int maxPreloadPages = 2;
  static const int maxCacheSize = 20;
  
  // 根据设备性能调整配置
  static LazyLoadingConfig getOptimalConfig() {
    // 简化的设备性能检测
    // 在实际应用中可以根据设备内存、CPU等信息调整
    return LazyLoadingConfig._();
  }
  
  LazyLoadingConfig._();
}

/// 消息虚拟化管理器
class MessageVirtualizationManager {
  static const int _bufferSize = 20; // 缓冲区大小
  
  /// 计算应该渲染的消息范围
  static MessageRange calculateVisibleRange({
    required int totalMessages,
    required int firstVisibleIndex,
    required int lastVisibleIndex,
  }) {
    final start = (firstVisibleIndex - _bufferSize).clamp(0, totalMessages);
    final end = (lastVisibleIndex + _bufferSize).clamp(0, totalMessages);
    
    return MessageRange(
      start: start,
      end: end,
      total: totalMessages,
    );
  }
  
  /// 检查消息是否在可见范围内
  static bool isMessageVisible({
    required int messageIndex,
    required MessageRange visibleRange,
  }) {
    return messageIndex >= visibleRange.start && messageIndex <= visibleRange.end;
  }
}

/// 消息范围
class MessageRange {
  final int start;
  final int end;
  final int total;
  
  const MessageRange({
    required this.start,
    required this.end,
    required this.total,
  });
  
  int get length => end - start;
  
  bool contains(int index) => index >= start && index <= end;
  
  @override
  String toString() => 'MessageRange(start: $start, end: $end, total: $total)';
}