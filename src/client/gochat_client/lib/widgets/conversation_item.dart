import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../utils/state_optimization.dart';
import '../utils/image_cache_manager.dart';

class ConversationItem extends StatefulWidget {
  final Conversation conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ConversationItem({
    super.key,
    required this.conversation,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends State<ConversationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _flashAnimation;
  int _lastUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _lastUnreadCount = widget.conversation.unreadCount;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _flashAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(ConversationItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 检查是否有新的未读消息
    if (widget.conversation.unreadCount > _lastUnreadCount) {
      _triggerFlashAnimation();
    }
    _lastUnreadCount = widget.conversation.unreadCount;
  }

  void _triggerFlashAnimation() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CachedBuilder(
      dependencies: [
        widget.conversation.id,
        widget.conversation.unreadCount,
        widget.conversation.lastMessage?.msgId,
        widget.conversation.lastTime,
      ],
      builder: () => AnimatedBuilder(
        animation: _flashAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _flashAnimation.value,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.conversation.unreadCount > 0 
                      ? Colors.grey[50] 
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 头像
                    _buildAvatar(),
                    const SizedBox(width: 12),
                    // 会话信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 会话标题
                              Expanded(
                                child: Text(
                                  widget.conversation.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: widget.conversation.unreadCount > 0 
                                        ? FontWeight.w600 
                                        : FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // 时间
                              if (widget.conversation.lastTime != null)
                                Text(
                                  _formatTime(widget.conversation.lastTime!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.conversation.unreadCount > 0 
                                        ? const Color(0xFF07C160) 
                                        : Colors.grey[600],
                                    fontWeight: widget.conversation.unreadCount > 0 
                                        ? FontWeight.w500 
                                        : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // 最后一条消息预览
                              Expanded(
                                child: Text(
                                  _getMessagePreview(widget.conversation.lastMessage),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: widget.conversation.unreadCount > 0 
                                        ? Colors.grey[800] 
                                        : Colors.grey[600],
                                    fontWeight: widget.conversation.unreadCount > 0 
                                        ? FontWeight.w500 
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // 未读消息数量
                              if (widget.conversation.unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.conversation.unreadCount > 99 
                                          ? '99+' 
                                          : widget.conversation.unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }



  Widget _buildAvatar() {
    return Stack(
      children: [
        widget.conversation.avatar != null
            ? ClipOval(
                child: OptimizedNetworkImage(
                  imageUrl: widget.conversation.avatar!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  enableMemoryCache: true,
                ),
              )
            : CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF07C160),
                child: Text(
                  widget.conversation.title.isNotEmpty 
                      ? widget.conversation.title[0] 
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
        // 群组标识
        if (widget.conversation.type == ConversationType.group)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(
                Icons.group,
                size: 14,
                color: Color(0xFF07C160),
              ),
            ),
          ),
        // 未读消息红点
        if (widget.conversation.unreadCount > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  String _getMessagePreview(Message? message) {
    if (message == null) {
      return '暂无消息';
    }

    switch (message.msgType) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        return '[图片]';
      case MessageType.video:
        return '[视频]';
      case MessageType.file:
        return '[文件]';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      // 今天，显示时间
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // 昨天
      return '昨天';
    } else if (difference.inDays < 7) {
      // 一周内，显示星期
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    } else if (difference.inDays < 365) {
      // 一年内，显示月/日
      return '${time.month}/${time.day}';
    } else {
      // 超过一年，显示年/月/日
      return '${time.year}/${time.month}/${time.day}';
    }
  }
}
