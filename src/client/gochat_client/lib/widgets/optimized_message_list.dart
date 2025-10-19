import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../providers/group_provider.dart';
import '../utils/lazy_loading_manager.dart';
import '../utils/performance_monitor.dart';
import 'message_bubble.dart';

class OptimizedMessageList extends StatefulWidget {
  final String conversationId;
  final bool isGroupChat;
  final int? groupId;
  final Function()? onLoadMore;
  final Function(Message)? onRetryMessage;

  const OptimizedMessageList({
    Key? key,
    required this.conversationId,
    this.isGroupChat = false,
    this.groupId,
    this.onLoadMore,
    this.onRetryMessage,
  }) : super(key: key);

  @override
  State<OptimizedMessageList> createState() => OptimizedMessageListState();
}

class OptimizedMessageListState extends State<OptimizedMessageList>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final LazyLoadingManager _lazyLoadingManager = LazyLoadingManager();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _lazyLoadingManager.clearConversationCache(widget.conversationId);
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      _performanceMonitor.startTimer('message_list_scroll');
      
      // 当滚动到顶部附近时触发加载更多
      if (_scrollController.position.pixels <= 100 && 
          !_isLoadingMore && 
          widget.onLoadMore != null) {
        _loadMore();
      }
      
      // 检查是否需要预加载
      _checkPreloadTrigger();
      
      // 延迟结束计时
      Future.delayed(const Duration(milliseconds: 50), () {
        _performanceMonitor.endTimer('message_list_scroll');
      });
    });
  }

  void _checkPreloadTrigger() {
    final chatProvider = context.read<ChatProvider>();
    final messages = chatProvider.getMessages(widget.conversationId) ?? [];
    final currentPage = chatProvider.getCurrentPage(widget.conversationId);
    final hasMore = chatProvider.hasMoreMessages(widget.conversationId);
    
    if (_lazyLoadingManager.shouldPreload(
      conversationId: widget.conversationId,
      currentMessageCount: messages.length,
      currentPage: currentPage,
      hasMoreMessages: hasMore,
    )) {
      _triggerPreload();
    }
  }

  void _triggerPreload() {
    final chatProvider = context.read<ChatProvider>();
    final currentPage = chatProvider.getCurrentPage(widget.conversationId);
    
    _lazyLoadingManager.preloadMessages(
      conversationId: widget.conversationId,
      currentPage: currentPage,
      friendId: widget.isGroupChat ? null : widget.groupId,
      groupId: widget.isGroupChat ? widget.groupId : null,
    );
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      await widget.onLoadMore?.call();
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    
    if (animated) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer3<ChatProvider, UserProvider, GroupProvider>(
      builder: (context, chatProvider, userProvider, groupProvider, child) {
        final messages = chatProvider.getMessages(widget.conversationId) ?? [];
        final hasMore = chatProvider.hasMoreMessages(widget.conversationId);
        final isLoadingMore = chatProvider.isLoadingMore(widget.conversationId);

        if (messages.isEmpty) {
          return Center(
            child: Text(
              '暂无消息',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          // 反向显示，最新消息在底部
          reverse: true,
          // 使用缓存范围来提高性能
          cacheExtent: 1000,
          itemCount: messages.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // 由于reverse=true，需要调整索引
            if (index == messages.length && hasMore) {
              // 显示加载更多指示器
              return Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: isLoadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '上拉加载更多',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
              );
            }

            // 反向索引
            final messageIndex = messages.length - 1 - index;
            final message = messages[messageIndex];
            final isMine = message.fromUserId == userProvider.currentUser?.id;

            // 获取发送者昵称（用于群聊）
            String? senderNickname;
            if (widget.isGroupChat && !isMine && widget.groupId != null) {
              final members = groupProvider.getGroupMembers(widget.groupId!);
              if (members != null) {
                try {
                  final sender = members.firstWhere((m) => m.id == message.fromUserId);
                  senderNickname = sender.nickname;
                } catch (e) {
                  senderNickname = '用户${message.fromUserId}';
                }
              }
            }

            return MessageBubbleWrapper(
              key: ValueKey(message.msgId),
              message: message,
              isMine: isMine,
              isGroupChat: widget.isGroupChat,
              senderNickname: senderNickname,
              onRetry: message.status == MessageStatus.failed && isMine
                  ? () => widget.onRetryMessage?.call(message)
                  : null,
            );
          },
        );
      },
    );
  }
}

// 包装器组件，用于优化重建
class MessageBubbleWrapper extends StatelessWidget {
  final Message message;
  final bool isMine;
  final bool isGroupChat;
  final String? senderNickname;
  final VoidCallback? onRetry;

  const MessageBubbleWrapper({
    Key? key,
    required this.message,
    required this.isMine,
    required this.isGroupChat,
    this.senderNickname,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MessageBubble(
      message: message,
      isMine: isMine,
      isGroupChat: isGroupChat,
      senderNickname: senderNickname,
      onRetry: onRetry,
    );
  }


}