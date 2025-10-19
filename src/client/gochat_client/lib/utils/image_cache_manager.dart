import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  factory ImageCacheManager() => _instance;
  ImageCacheManager._internal();

  // 自定义缓存管理器
  static const String _cacheKey = 'gochat_images';
  late final CacheManager _cacheManager;

  void initialize() {
    _cacheManager = CacheManager(
      Config(
        _cacheKey,
        stalePeriod: const Duration(days: 7), // 缓存7天
        maxNrOfCacheObjects: 1000, // 最多缓存1000个图片
        repo: JsonCacheInfoRepository(databaseName: _cacheKey),
        fileService: HttpFileService(),
      ),
    );
  }

  CacheManager get cacheManager => _cacheManager;

  /// 预加载图片
  Future<void> preloadImage(String imageUrl) async {
    try {
      await _cacheManager.downloadFile(imageUrl);
      if (kDebugMode) {
        debugPrint('Preloaded image: $imageUrl');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to preload image $imageUrl: $e');
      }
    }
  }

  /// 批量预加载图片
  Future<void> preloadImages(List<String> imageUrls) async {
    final futures = imageUrls.map((url) => preloadImage(url));
    await Future.wait(futures);
  }

  /// 清理过期缓存
  Future<void> cleanupCache() async {
    try {
      await _cacheManager.emptyCache();
      if (kDebugMode) {
        debugPrint('Image cache cleaned up');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to cleanup image cache: $e');
      }
    }
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    try {
      // 这是一个简化的实现，实际应该遍历所有缓存文件
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// 检查图片是否已缓存
  Future<bool> isImageCached(String imageUrl) async {
    try {
      final file = await _cacheManager.getFileFromCache(imageUrl);
      return file != null;
    } catch (e) {
      return false;
    }
  }

  /// 移除特定图片缓存
  Future<void> removeFromCache(String imageUrl) async {
    try {
      await _cacheManager.removeFile(imageUrl);
      if (kDebugMode) {
        debugPrint('Removed from cache: $imageUrl');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to remove from cache $imageUrl: $e');
      }
    }
  }
}

/// 优化的网络图片组件
class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final bool enableMemoryCache;

  const OptimizedNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableMemoryCache = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: ImageCacheManager().cacheManager,
      memCacheWidth: enableMemoryCache ? (width?.toInt() ?? 400) : null,
      memCacheHeight: enableMemoryCache ? (height?.toInt() ?? 400) : null,
      placeholder: placeholder ?? 
        (BuildContext context, String url) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      errorWidget: errorWidget ?? 
        (BuildContext context, String url, dynamic error) => Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, size: 32),
        ),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
    );
  }
}

/// 图片预加载器
class ImagePreloader {
  static final ImagePreloader _instance = ImagePreloader._internal();
  factory ImagePreloader() => _instance;
  ImagePreloader._internal();

  final Set<String> _preloadingUrls = {};
  final ImageCacheManager _cacheManager = ImageCacheManager();

  /// 智能预加载：根据消息列表预加载即将显示的图片
  Future<void> preloadImagesForMessages(List<String> imageUrls) async {
    final urlsToPreload = imageUrls
        .where((url) => !_preloadingUrls.contains(url))
        .take(5) // 限制同时预加载的数量
        .toList();

    for (final url in urlsToPreload) {
      _preloadingUrls.add(url);
      
      // 异步预加载，不阻塞UI
      _cacheManager.preloadImage(url).then((_) {
        _preloadingUrls.remove(url);
      }).catchError((e) {
        _preloadingUrls.remove(url);
        if (kDebugMode) {
          debugPrint('Failed to preload image: $e');
        }
      });
    }
  }

  /// 清理预加载状态
  void clearPreloadingState() {
    _preloadingUrls.clear();
  }
}