import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, DateTime> _startTimes = {};
  final Map<String, List<int>> _durations = {};
  
  // 内存使用监控
  int _lastMemoryUsage = 0;
  final List<int> _memoryUsageHistory = [];

  /// 开始性能监控
  void startTimer(String operation) {
    _startTimes[operation] = DateTime.now();
  }

  /// 结束性能监控并记录耗时
  void endTimer(String operation) {
    final startTime = _startTimes[operation];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      if (!_durations.containsKey(operation)) {
        _durations[operation] = [];
      }
      _durations[operation]!.add(duration);
      
      // 只保留最近100次记录
      if (_durations[operation]!.length > 100) {
        _durations[operation]!.removeAt(0);
      }
      
      _startTimes.remove(operation);
      
      if (kDebugMode) {
        debugPrint('Performance: $operation took ${duration}ms');
      }
    }
  }

  /// 获取操作的平均耗时
  double getAverageTime(String operation) {
    final durations = _durations[operation];
    if (durations == null || durations.isEmpty) return 0.0;
    
    final sum = durations.reduce((a, b) => a + b);
    return sum / durations.length;
  }

  /// 获取操作的最大耗时
  int getMaxTime(String operation) {
    final durations = _durations[operation];
    if (durations == null || durations.isEmpty) return 0;
    
    return durations.reduce((a, b) => a > b ? a : b);
  }

  /// 监控内存使用
  Future<void> checkMemoryUsage() async {
    try {
      // 在实际应用中，可以使用更精确的内存监控方法
      // 这里使用简化的方法
      final info = await _getMemoryInfo();
      _lastMemoryUsage = info;
      _memoryUsageHistory.add(info);
      
      // 只保留最近50次记录
      if (_memoryUsageHistory.length > 50) {
        _memoryUsageHistory.removeAt(0);
      }
      
      if (kDebugMode && info > 100 * 1024 * 1024) { // 100MB
        debugPrint('Warning: High memory usage: ${(info / 1024 / 1024).toStringAsFixed(1)}MB');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to check memory usage: $e');
      }
    }
  }

  Future<int> _getMemoryInfo() async {
    // 简化的内存信息获取
    // 在实际应用中可以使用更精确的方法
    return _memoryUsageHistory.isNotEmpty ? _memoryUsageHistory.last + 1024 : 50 * 1024 * 1024;
  }

  /// 获取性能报告
  Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};
    
    for (final operation in _durations.keys) {
      report[operation] = {
        'average_ms': getAverageTime(operation).toStringAsFixed(2),
        'max_ms': getMaxTime(operation),
        'count': _durations[operation]!.length,
      };
    }
    
    report['memory'] = {
      'current_mb': (_lastMemoryUsage / 1024 / 1024).toStringAsFixed(1),
      'peak_mb': _memoryUsageHistory.isNotEmpty 
          ? (_memoryUsageHistory.reduce((a, b) => a > b ? a : b) / 1024 / 1024).toStringAsFixed(1)
          : '0.0',
    };
    
    return report;
  }

  /// 清理性能数据
  void clearData() {
    _startTimes.clear();
    _durations.clear();
    _memoryUsageHistory.clear();
    _lastMemoryUsage = 0;
  }

  /// 记录帧率
  void recordFrameTime(Duration frameTime) {
    final ms = frameTime.inMicroseconds / 1000;
    
    if (!_durations.containsKey('frame_time')) {
      _durations['frame_time'] = [];
    }
    
    _durations['frame_time']!.add(ms.round());
    
    // 只保留最近1000帧的数据
    if (_durations['frame_time']!.length > 1000) {
      _durations['frame_time']!.removeAt(0);
    }
    
    // 警告：帧时间超过16.67ms（60fps）
    if (kDebugMode && ms > 16.67) {
      debugPrint('Warning: Frame time ${ms.toStringAsFixed(2)}ms (${(1000/ms).toStringAsFixed(1)} fps)');
    }
  }

  /// 获取平均帧率
  double getAverageFPS() {
    final frameTimes = _durations['frame_time'];
    if (frameTimes == null || frameTimes.isEmpty) return 0.0;
    
    final avgFrameTime = frameTimes.reduce((a, b) => a + b) / frameTimes.length;
    return 1000 / avgFrameTime;
  }
}

/// 性能监控装饰器
class PerformanceWrapper extends StatefulWidget {
  final Widget child;
  final String operationName;

  const PerformanceWrapper({
    Key? key,
    required this.child,
    required this.operationName,
  }) : super(key: key);

  @override
  State<PerformanceWrapper> createState() => _PerformanceWrapperState();
}

class _PerformanceWrapperState extends State<PerformanceWrapper> {
  final _monitor = PerformanceMonitor();

  @override
  void initState() {
    super.initState();
    _monitor.startTimer('${widget.operationName}_build');
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _monitor.endTimer('${widget.operationName}_build');
    });
    
    return widget.child;
  }
}