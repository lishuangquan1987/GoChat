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

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMine,
    this.onRetry,
    this.senderNickname,
    this.isGroupChat = false,
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
    return Container(
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
