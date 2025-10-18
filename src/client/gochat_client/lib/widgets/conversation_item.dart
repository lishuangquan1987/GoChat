import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationItem({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          conversation.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 时间
                      if (conversation.lastTime != null)
                        Text(
                          _formatTime(conversation.lastTime!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
                          _getMessagePreview(conversation.lastMessage),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 未读消息数量
                      if (conversation.unreadCount > 0)
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
                              conversation.unreadCount > 99 
                                  ? '99+' 
                                  : conversation.unreadCount.toString(),
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
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF07C160),
          backgroundImage: conversation.avatar != null 
              ? NetworkImage(conversation.avatar!)
              : null,
          child: conversation.avatar == null
              ? Text(
                  conversation.title.isNotEmpty 
                      ? conversation.title[0] 
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : null,
        ),
        // 群组标识
        if (conversation.type == ConversationType.group)
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
