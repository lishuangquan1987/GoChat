import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 优化的状态管理基类
abstract class OptimizedChangeNotifier extends ChangeNotifier {
  bool _disposed = false;
  bool _isNotifying = false;
  
  @override
  void notifyListeners() {
    if (_disposed || _isNotifying) return;
    
    _isNotifying = true;
    // 使用微任务延迟通知，避免同步调用时的性能问题
    scheduleMicrotask(() {
      if (!_disposed && _isNotifying) {
        _isNotifying = false;
        super.notifyListeners();
      }
    });
  }
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
  
  /// 批量更新，减少通知次数
  void batchUpdate(VoidCallback updates) {
    final wasNotifying = _isNotifying;
    _isNotifying = true;
    
    try {
      updates();
    } finally {
      _isNotifying = wasNotifying;
      if (!wasNotifying) {
        notifyListeners();
      }
    }
  }
}

/// 选择性重建的Consumer
class SelectiveConsumer<T extends Listenable> extends StatefulWidget {
  final T listenable;
  final bool Function(T)? selector;
  final Widget Function(BuildContext, T, Widget?) builder;
  final Widget? child;

  const SelectiveConsumer({
    Key? key,
    required this.listenable,
    required this.builder,
    this.selector,
    this.child,
  }) : super(key: key);

  @override
  State<SelectiveConsumer<T>> createState() => _SelectiveConsumerState<T>();
}

class _SelectiveConsumerState<T extends Listenable>
    extends State<SelectiveConsumer<T>> {
  bool _lastSelectorResult = false;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_listener);
    _lastSelectorResult = widget.selector?.call(widget.listenable) ?? true;
  }

  @override
  void didUpdateWidget(SelectiveConsumer<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_listener);
      widget.listenable.addListener(_listener);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_listener);
    super.dispose();
  }

  void _listener() {
    final shouldRebuild = widget.selector?.call(widget.listenable) ?? true;
    if (shouldRebuild != _lastSelectorResult) {
      _lastSelectorResult = shouldRebuild;
      if (shouldRebuild && mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.listenable, widget.child);
  }
}

/// 缓存的Widget构建器
class CachedBuilder extends StatefulWidget {
  final Widget Function() builder;
  final List<Object?> dependencies;
  final Duration? cacheDuration;

  const CachedBuilder({
    Key? key,
    required this.builder,
    required this.dependencies,
    this.cacheDuration,
  }) : super(key: key);

  @override
  State<CachedBuilder> createState() => _CachedBuilderState();
}

class _CachedBuilderState extends State<CachedBuilder> {
  Widget? _cachedWidget;
  List<Object?>? _lastDependencies;
  DateTime? _cacheTime;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final shouldRebuild = _shouldRebuild(now);

    if (shouldRebuild) {
      _cachedWidget = widget.builder();
      _lastDependencies = List.from(widget.dependencies);
      _cacheTime = now;
    }

    return _cachedWidget!;
  }

  bool _shouldRebuild(DateTime now) {
    // 首次构建
    if (_cachedWidget == null) return true;

    // 依赖项发生变化
    if (!listEquals(_lastDependencies, widget.dependencies)) return true;

    // 缓存过期
    if (widget.cacheDuration != null && _cacheTime != null) {
      if (now.difference(_cacheTime!) > widget.cacheDuration!) return true;
    }

    return false;
  }
}

/// 防抖重建的Widget
class DebouncedBuilder extends StatefulWidget {
  final Widget Function() builder;
  final Duration debounceTime;
  final List<Object?> dependencies;

  const DebouncedBuilder({
    Key? key,
    required this.builder,
    required this.dependencies,
    this.debounceTime = const Duration(milliseconds: 100),
  }) : super(key: key);

  @override
  State<DebouncedBuilder> createState() => _DebouncedBuilderState();
}

class _DebouncedBuilderState extends State<DebouncedBuilder> {
  Widget? _currentWidget;
  List<Object?>? _lastDependencies;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentWidget = widget.builder();
    _lastDependencies = List.from(widget.dependencies);
  }

  @override
  void didUpdateWidget(DebouncedBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (!listEquals(_lastDependencies, widget.dependencies)) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(widget.debounceTime, () {
        if (mounted) {
          setState(() {
            _currentWidget = widget.builder();
            _lastDependencies = List.from(widget.dependencies);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _currentWidget!;
  }
}

/// 内存优化的ListView
class OptimizedListView extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool reverse;
  final double? cacheExtent;

  const OptimizedListView({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.reverse = false,
    this.cacheExtent,
  }) : super(key: key);

  @override
  State<OptimizedListView> createState() => _OptimizedListViewState();
}

class _OptimizedListViewState extends State<OptimizedListView> {
  final Map<int, Widget> _cachedItems = {};
  static const int _maxCacheSize = 100;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding,
      reverse: widget.reverse,
      cacheExtent: widget.cacheExtent ?? 250.0,
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        // 使用缓存的Widget，避免重复构建
        if (_cachedItems.containsKey(index)) {
          return _cachedItems[index]!;
        }

        final item = widget.itemBuilder(context, index);
        
        // 缓存Widget，但限制缓存大小
        if (_cachedItems.length < _maxCacheSize) {
          _cachedItems[index] = item;
        } else {
          // 移除最旧的缓存项
          final oldestKey = _cachedItems.keys.first;
          _cachedItems.remove(oldestKey);
          _cachedItems[index] = item;
        }

        return item;
      },
    );
  }

  @override
  void didUpdateWidget(OptimizedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果itemCount发生变化，清理无效的缓存
    if (oldWidget.itemCount != widget.itemCount) {
      _cachedItems.removeWhere((index, _) => index >= widget.itemCount);
    }
  }
}

/// 性能监控Widget
class PerformanceOverlay extends StatefulWidget {
  final Widget child;
  final bool showOverlay;

  const PerformanceOverlay({
    Key? key,
    required this.child,
    this.showOverlay = kDebugMode,
  }) : super(key: key);

  @override
  State<PerformanceOverlay> createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay> {
  double _fps = 0.0;
  int _rebuilds = 0;
  final List<Duration> _frameTimes = [];

  @override
  void initState() {
    super.initState();
    if (widget.showOverlay) {
      WidgetsBinding.instance.addTimingsCallback(_onFrameTime);
    }
  }

  @override
  void dispose() {
    if (widget.showOverlay) {
      WidgetsBinding.instance.removeTimingsCallback(_onFrameTime);
    }
    super.dispose();
  }

  void _onFrameTime(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameTimes.add(timing.totalSpan);
      if (_frameTimes.length > 60) {
        _frameTimes.removeAt(0);
      }
    }

    if (_frameTimes.isNotEmpty) {
      final avgFrameTime = _frameTimes
          .map((d) => d.inMicroseconds)
          .reduce((a, b) => a + b) / _frameTimes.length;
      _fps = 1000000 / avgFrameTime;
    }

    if (mounted) {
      setState(() {
        _rebuilds++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showOverlay)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FPS: ${_fps.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'Rebuilds: $_rebuilds',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 延迟加载的Widget
class LazyWidget extends StatefulWidget {
  final Widget Function() builder;
  final Widget? placeholder;
  final Duration delay;

  const LazyWidget({
    Key? key,
    required this.builder,
    this.placeholder,
    this.delay = const Duration(milliseconds: 100),
  }) : super(key: key);

  @override
  State<LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<LazyWidget> {
  Widget? _builtWidget;
  bool _isBuilding = false;

  @override
  void initState() {
    super.initState();
    _scheduleBuilding();
  }

  void _scheduleBuilding() {
    if (_isBuilding) return;
    
    _isBuilding = true;
    Future.delayed(widget.delay, () {
      if (mounted && _builtWidget == null) {
        setState(() {
          _builtWidget = widget.builder();
        });
      }
      _isBuilding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _builtWidget ?? widget.placeholder ?? const SizedBox.shrink();
  }
}