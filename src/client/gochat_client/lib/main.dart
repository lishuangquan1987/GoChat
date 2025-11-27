import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/friend_provider.dart';
import 'providers/group_provider.dart';
import 'providers/settings_provider.dart' as settings_provider;
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/user_switcher_page.dart';
import 'services/storage_service.dart';
import 'utils/performance_monitor.dart';
import 'utils/image_cache_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器（仅桌面平台）
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      windowButtonVisibility: true,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 初始化存储服务
  await StorageService.init();

  // 初始化设置
  final settingsProvider = settings_provider.SettingsProvider();
  await settingsProvider.initialize();

  // 初始化图片缓存管理器
  ImageCacheManager().initialize();

  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 启动性能监控（仅在调试模式下）
  if (kDebugMode) {
    final monitor = PerformanceMonitor();

    // 定期检查内存使用
    Timer.periodic(const Duration(seconds: 30), (_) {
      monitor.checkMemoryUsage();
    });

    // 监控帧率
    WidgetsBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        monitor.recordFrameTime(timing.totalSpan);
      }
    });
  }

  runApp(MyApp(settingsProvider: settingsProvider));
}

class MyApp extends StatelessWidget {
  final settings_provider.SettingsProvider settingsProvider;

  const MyApp({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: Consumer<settings_provider.SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'GoChat',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(settings, false),
            darkTheme: _buildTheme(settings, true),
            themeMode: _getThemeMode(settings.themeMode),
            home: const SplashPage(),
            routes: {
              '/login': (context) => const LoginPage(),
              '/home': (context) => const HomePage(),
            },
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(
      settings_provider.SettingsProvider settings, bool isDark) {
    final primaryColor = settings.primaryColor;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    return ThemeData(
      brightness: brightness,
      primarySwatch: _createMaterialColor(primaryColor),
      primaryColor: primaryColor,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEDEDED),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        brightness: brightness,
        surface: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        onSurface: isDark ? Colors.white : Colors.black87,
      ),
      useMaterial3: true,
    );
  }

  MaterialColor _createMaterialColor(Color color) {
    final strengths = <double>[.05];
    final swatch = <int, Color>{};
    final int r = (color.r * 255.0).round() & 0xff;
    final int g = (color.g * 255.0).round() & 0xff;
    final int b = (color.b * 255.0).round() & 0xff;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }

    for (final strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }

    return MaterialColor(color.toARGB32(), swatch);
  }

  ThemeMode _getThemeMode(settings_provider.ThemeMode mode) {
    switch (mode) {
      case settings_provider.ThemeMode.system:
        return ThemeMode.system;
      case settings_provider.ThemeMode.light:
        return ThemeMode.light;
      case settings_provider.ThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

// 启动页，检查登录状态
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    _timer = Timer(const Duration(seconds: 1), () async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 检查是否有多个用户
      final allUsers = await userProvider.getAllUsers();

      if (allUsers.length > 1) {
        // 有多个用户，显示用户选择页面
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const UserSwitcherPage()),
          );
        }
        return;
      }

      // 只有一个或没有用户，按原逻辑处理
      final isLoggedIn = await userProvider.checkLoginStatus();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                isLoggedIn ? const HomePage() : const LoginPage(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07C160),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 100,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 20),
            const Text(
              'GoChat',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
