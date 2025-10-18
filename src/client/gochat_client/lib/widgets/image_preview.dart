import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImagePreviewPage extends StatelessWidget {
  final String imageUrl;

  const ImagePreviewPage({
    Key? key,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: 实现图片下载
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('下载功能暂未实现')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => const Icon(
              Icons.error,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
