import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面通知工具类
/// 负责处理桌面平台的系统通知和任务栏提醒
class DesktopNotification {
  static bool _hasUnreadMessages = false;
  static int _totalUnreadCount = 0;

  /// 更新未读消息状态
  static Future<void> updateUnreadStatus({
    required int unreadCount,
    String? title,
    String? message,
  }) async {
    if (!_isDesktopPlatform()) return;

    _totalUnreadCount = unreadCount;
    final hadUnread = _hasUnreadMessages;
    _hasUnreadMessages = unreadCount > 0;

    try {
      // 更新窗口标题
      await _updateWindowTitle();

      // 如果有新的未读消息，显示系统通知
      if (!hadUnread && _hasUnreadMessages && title != null && message != null) {
        await _showSystemNotification(title, message);
      }

      // 更新任务栏状态
      await _updateTaskbarStatus();
    } catch (e) {
      debugPrint('Failed to update desktop notification: $e');
    }
  }

  /// 清除未读消息状态
  static Future<void> clearUnreadStatus() async {
    if (!_isDesktopPlatform()) return;

    _hasUnreadMessages = false;
    _totalUnreadCount = 0;

    try {
      await _updateWindowTitle();
      await _updateTaskbarStatus();
    } catch (e) {
      debugPrint('Failed to clear desktop notification: $e');
    }
  }

  /// 更新窗口标题
  static Future<void> _updateWindowTitle() async {
    try {
      String title = 'GoChat';
      if (_hasUnreadMessages) {
        title = 'GoChat ($_totalUnreadCount)';
      }
      await windowManager.setTitle(title);
    } catch (e) {
      debugPrint('Failed to update window title: $e');
    }
  }

  /// 显示系统通知
  static Future<void> _showSystemNotification(String title, String message) async {
    try {
      if (Platform.isWindows) {
        await _showWindowsNotification(title, message);
      } else if (Platform.isMacOS) {
        await _showMacOSNotification(title, message);
      } else if (Platform.isLinux) {
        await _showLinuxNotification(title, message);
      }
    } catch (e) {
      debugPrint('Failed to show system notification: $e');
    }
  }

  /// Windows 系统通知
  static Future<void> _showWindowsNotification(String title, String message) async {
    try {
      // 使用 PowerShell 显示 Windows 通知
      final result = await Process.run('powershell', [
        '-Command',
        '''
        Add-Type -AssemblyName System.Windows.Forms
        \$notification = New-Object System.Windows.Forms.NotifyIcon
        \$notification.Icon = [System.Drawing.SystemIcons]::Information
        \$notification.BalloonTipTitle = "$title"
        \$notification.BalloonTipText = "$message"
        \$notification.Visible = \$true
        \$notification.ShowBalloonTip(3000)
        Start-Sleep -Seconds 3
        \$notification.Dispose()
        '''
      ]);
      
      if (result.exitCode != 0) {
        debugPrint('Windows notification failed: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('Failed to show Windows notification: $e');
    }
  }

  /// macOS 系统通知
  static Future<void> _showMacOSNotification(String title, String message) async {
    try {
      final result = await Process.run('osascript', [
        '-e',
        'display notification "$message" with title "$title" sound name "default"'
      ]);
      
      if (result.exitCode != 0) {
        debugPrint('macOS notification failed: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('Failed to show macOS notification: $e');
    }
  }

  /// Linux 系统通知
  static Future<void> _showLinuxNotification(String title, String message) async {
    try {
      final result = await Process.run('notify-send', [
        title,
        message,
        '--icon=dialog-information',
        '--expire-time=3000'
      ]);
      
      if (result.exitCode != 0) {
        debugPrint('Linux notification failed: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('Failed to show Linux notification: $e');
    }
  }

  /// 更新任务栏状态
  static Future<void> _updateTaskbarStatus() async {
    try {
      if (Platform.isWindows) {
        await _updateWindowsTaskbar();
      } else if (Platform.isMacOS) {
        await _updateMacOSTaskbar();
      }
      // Linux 通常不需要特殊的任务栏处理
    } catch (e) {
      debugPrint('Failed to update taskbar status: $e');
    }
  }

  /// 更新 Windows 任务栏
  static Future<void> _updateWindowsTaskbar() async {
    try {
      if (_hasUnreadMessages) {
        await windowManager.setSkipTaskbar(false);
        
        // 增强的Windows任务栏闪烁效果
        await Process.run('powershell', [
          '-Command',
          '''
          Add-Type -TypeDefinition "
            using System;
            using System.Runtime.InteropServices;
            public class Win32 {
              [DllImport(\\"user32.dll\\")]
              public static extern bool FlashWindow(IntPtr hWnd, bool bInvert);
              [DllImport(\\"user32.dll\\")]
              public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
              [DllImport(\\"user32.dll\\")]
              public static extern bool FlashWindowEx(ref FLASHWINFO pwfi);
              [StructLayout(LayoutKind.Sequential)]
              public struct FLASHWINFO {
                public uint cbSize;
                public IntPtr hwnd;
                public uint dwFlags;
                public uint uCount;
                public uint dwTimeout;
              }
              public const uint FLASHW_ALL = 3;
              public const uint FLASHW_TIMERNOFG = 12;
            }
          "
          
          # 查找GoChat窗口
          \$hwnd = [Win32]::FindWindow(\$null, "GoChat*")
          if (\$hwnd -eq [IntPtr]::Zero) {
            \$hwnd = [Win32]::FindWindow(\$null, "*GoChat*")
          }
          
          if (\$hwnd -ne [IntPtr]::Zero) {
            # 使用FlashWindowEx进行更好的闪烁效果
            \$flash = New-Object Win32+FLASHWINFO
            \$flash.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf(\$flash)
            \$flash.hwnd = \$hwnd
            \$flash.dwFlags = [Win32]::FLASHW_ALL -bor [Win32]::FLASHW_TIMERNOFG
            \$flash.uCount = 5
            \$flash.dwTimeout = 0
            [Win32]::FlashWindowEx([ref]\$flash)
          }
          '''
        ]);
      }
    } catch (e) {
      debugPrint('Failed to update Windows taskbar: $e');
    }
  }

  /// 更新 macOS Dock
  static Future<void> _updateMacOSTaskbar() async {
    try {
      if (_hasUnreadMessages) {
        // macOS Dock 图标徽章
        await Process.run('osascript', [
          '-e',
          'tell application "System Events" to set the badge of (first application process whose name is "gochat_client") to "$_totalUnreadCount"'
        ]);
      } else {
        // 清除徽章
        await Process.run('osascript', [
          '-e',
          'tell application "System Events" to set the badge of (first application process whose name is "gochat_client") to ""'
        ]);
      }
    } catch (e) {
      debugPrint('Failed to update macOS dock: $e');
    }
  }

  /// 检查是否为桌面平台
  static bool _isDesktopPlatform() {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 请求通知权限（主要用于 macOS）
  static Future<bool> requestNotificationPermission() async {
    if (!_isDesktopPlatform()) return true;

    try {
      if (Platform.isMacOS) {
        // macOS 需要请求通知权限
        final result = await Process.run('osascript', [
          '-e',
          'tell application "System Events" to display dialog "GoChat 需要通知权限来显示新消息提醒" buttons {"取消", "允许"} default button "允许"'
        ]);
        
        return result.exitCode == 0 && result.stdout.toString().contains('允许');
      }
      
      return true; // Windows 和 Linux 通常不需要特殊权限
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
      return false;
    }
  }

  /// 测试系统通知
  static Future<void> testNotification() async {
    await _showSystemNotification('GoChat', '这是一条测试通知');
  }
}