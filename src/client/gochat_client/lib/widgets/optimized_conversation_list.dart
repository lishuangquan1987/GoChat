import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../providers/chat_provider.dart';
import '../utils/performance_monitor.dart';
import 'conversation_item.dart';

class OptimizedConversationList extends StatefulWidget {
  final Function(Conversation)? onConversationTap;
  final Function(Conversation)? onConversationLongPress;

  const OptimizedConversationList({
    Key? key,
    this.onConversationTap,
    this.onConversationLongPress,
  }) : super(key: key);

  @override
  State<OptimizedConversationList> createState() => _OptimizedConversationListState();
}

class _OptimizedConversationListState extends State<OptimizedConversationList>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final PerformanceMonitor _monitor = PerformanceMonitor();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupPerformanceMonitoring();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupPerformanceMonitoring() {
    if (kDebugMode) {
      _scrollController.addListener(() {
        _monitor.startTimer('conversation_list_scroll');
        
        // 延迟结束计时，确保滚动动画完成
        Future.delayed(const Duration(milliseconds: 100), () {
          _monitor.endTimer('conversation_list_scroll');
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final conversations = chatProvider.conversations;
        
        if (conversations.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  '暂无会话',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: conversations.length,
          // 使用缓存范围来提高性能
          cacheExtent: 1000,
          // 添加分隔符
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            
            return OptimizedConversationItem(
              key: ValueKey(conversation.id),
              conversation: conversation,
              onTap: () => widget.onConversationTap?.call(conversation),
              onLongPress: () => widget.onConversationLongPress?.call(conversation),
            );
          },
        );
      },
    );
  }
}

/// 优化的会话项组件
class OptimizedConversationItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const OptimizedConversationItem({
    Key? key,
    required this.conversation,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ConversationItem(
      conversation: conversation,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }


}

/// 会话列表性能统计组件
class ConversationListPerformanceStats extends StatelessWidget {
  const ConversationListPerformanceStats({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    
    final monitor = PerformanceMonitor();
    final report = monitor.getPerformanceReport();
    
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Performance Stats',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (report.containsKey('conversation_list_scroll'))
            Text(
              'Scroll: ${report['conversation_list_scroll']['average_ms']}ms avg',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          if (report.containsKey('memory'))
            Text(
              'Memory: ${report['memory']['current_mb']}MB',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          Text(
            'FPS: ${monitor.getAverageFPS().toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}