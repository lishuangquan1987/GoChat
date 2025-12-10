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
  final VoidCallback? onQuote;
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
    this.onQuote,
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
                GestureDetector(
                  onLongPress: () {
                    _showContextMenu(context);
                  },
                  child: _buildMessageContent(context),
                ),
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

  void _showContextMenu(BuildContext context) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(offset, offset.translate(box.size.width, box.size.height)),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: [
        // 复制消息
        if (message.msgType == MessageType.text)
          PopupMenuItem(
            value: 'copy',
            child: Row(
              children: const [
                Icon(Icons.content_copy, size: 16),
                SizedBox(width: 8),
                Text('复制'),
              ],
            ),
          ),
        // 引用消息
        PopupMenuItem(
          value: 'quote',
          child: Row(
            children: const [
              Icon(Icons.format_quote, size: 16),
              SizedBox(width: 8),
              Text('引用'),
            ],
          ),
        ),
        // 删除消息
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: const [
              Icon(Icons.delete, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        // 撤回消息（仅自己发送的消息，且在2分钟内）
        if (isMine && message.canRecall(currentUserId ?? 0))
          PopupMenuItem(
            value: 'recall',
            child: Row(
              children: const [
                Icon(Icons.undo, size: 16),
                SizedBox(width: 8),
                Text('撤回'),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'copy':
            onCopy?.call();
            break;
          case 'quote':
            onQuote?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
          case 'recall':
            onRecall?.call();
            break;
        }
      }
    });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget contentWidget;

    switch (message.msgType) {
      case MessageType.text:
        contentWidget = Text(
          message.content,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        );
        break;
      case MessageType.image:
        contentWidget = _buildImageContent();
        break;
      case MessageType.video:
        contentWidget = _buildVideoContent();
        break;
      case MessageType.file:
        contentWidget = _buildFileContent();
        break;
    }

    // 如果有引用消息，显示引用
    if (message.quotedMsgId != null && message.quotedContent != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A3A3A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_quote, color: Colors.grey, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    message.quotedContent!, 
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          contentWidget,
        ],
      );
    }

    return contentWidget;
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

  Widget _buildFileContent() {
    // 解析文件内容：格式为 文件名|文件URL
    final parts = message.content.split('|');
    final fileName = parts.isNotEmpty ? parts[0] : '未知文件';
    final fileUrl = parts.length > 1 ? parts[1] : '';

    return GestureDetector(
      onTap: () {
        // TODO: 实现文件下载
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.insert_drive_file, size: 24, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '点击下载',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download, size: 16, color: Colors.blue),
                  onPressed: () {
                    // TODO: 实现文件下载
                  },
                ),
              ],
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
