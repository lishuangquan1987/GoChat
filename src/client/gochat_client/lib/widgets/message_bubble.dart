import 'package:flutter/material.dart';
import '../models/message.dart';
import 'package:intl/intl.dart';
import 'image_preview.dart';
import '../utils/image_cache_manager.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final VoidCallback? onRetry;
  final String? senderNickname;
  final bool isGroupChat;
  final VoidCallback? onRecall;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final int? currentUserId;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMine,
    this.onRetry,
    this.senderNickname,
    this.isGroupChat = false,
    this.onRecall,
    this.onCopy,
    this.onDelete,
    this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) _buildAvatar(),
          if (!isMine) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isGroupChat && !isMine && senderNickname != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      senderNickname!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                _buildMessageContent(context),
                const SizedBox(height: 4),
                _buildMessageInfo(),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 8),
          if (isMine) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[300],
      child: Icon(Icons.person, color: Colors.grey[600], size: 24),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    // 如果消息已撤回，显示撤回提示
    if (message.isRevoked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              isMine ? '你撤回了一条消息' : '对方撤回了一条消息',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showMessageMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF95EC69) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildContent(context),
      ),
    );
  }

  void _showMessageMenu(BuildContext context) {
    final List<PopupMenuEntry> items = [];

    // 复制文本消息
    if (message.msgType == MessageType.text && onCopy != null) {
      items.add(
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 8),
              Text('复制'),
            ],
          ),
        ),
      );
    }

    // 撤回消息（仅自己发送的，2分钟内）
    if (isMine && 
        currentUserId != null && 
        message.canRecall(currentUserId!) && 
        onRecall != null) {
      items.add(
        const PopupMenuItem(
          value: 'recall',
          child: Row(
            children: [
              Icon(Icons.undo, size: 20),
              SizedBox(width: 8),
              Text('撤回'),
            ],
          ),
        ),
      );
    }

    // 删除消息
    if (onDelete != null) {
      items.add(
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) return;

    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 100, 100),
      items: items,
    ).then((value) {
      if (value == 'copy' && onCopy != null) {
        onCopy!();
      } else if (value == 'recall' && onRecall != null) {
        _confirmRecall(context);
      } else if (value == 'delete' && onDelete != null) {
        _confirmDelete(context);
      }
    });
  }

  void _confirmRecall(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤回消息'),
        content: const Text('确定要撤回这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onRecall != null) {
                onRecall!();
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定要删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onDelete != null) {
                onDelete!();
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.msgType) {
      case MessageType.text:
        return Text(
          message.content,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        );
      case MessageType.image:
        return _buildImageContent();
      case MessageType.video:
        return _buildVideoContent();
    }
  }

  Widget _buildImageContent() {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ImagePreviewPage(imageUrl: message.content),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: OptimizedNetworkImage(
              imageUrl: message.content,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              enableMemoryCache: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoContent() {
    return GestureDetector(
      onTap: () {
        // TODO: 实现视频播放
      },
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Video',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.createTime),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        if (isMine) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(),
        ],
      ],
    );
  }

  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: Colors.grey[600]);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: Colors.grey[600]);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF95EC69));
      case MessageStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: const Icon(Icons.error_outline, size: 14, color: Colors.red),
        );
    }
  }

  String _formatTime(DateTime time) {
    // 使用任务要求的格式：yyyy-MM-dd HH:mm:ss
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
  }
}
