import 'package:flutter/material.dart';

class EmojiPicker extends StatefulWidget {
  final Function(String) onEmojiSelected;

  const EmojiPicker({
    super.key,
    required this.onEmojiSelected,
  });

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // 表情包分类
  final List<EmojiCategory> _categories = [
    EmojiCategory(
      name: '笑脸',
      icon: '😀',
      emojis: [
        '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
        '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩',
        '😘', '😗', '☺️', '😚', '😙', '🥲', '😋', '😛',
        '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
      ],
    ),
    EmojiCategory(
      name: '手势',
      icon: '👋',
      emojis: [
        '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤌', '🤏',
        '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆',
        '🖕', '👇', '☝️', '👍', '👎', '👊', '✊', '🤛',
        '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️',
      ],
    ),
    EmojiCategory(
      name: '动物',
      icon: '🐶',
      emojis: [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
        '🐨', '🐯', '🦁', '🐮', '🐷', '🐽', '🐸', '🐵',
        '🙈', '🙉', '🙊', '🐒', '🐔', '🐧', '🐦', '🐤',
        '🐣', '🐥', '🦆', '🦅', '🦉', '🦇', '🐺', '🐗',
      ],
    ),
    EmojiCategory(
      name: '食物',
      icon: '🍎',
      emojis: [
        '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓',
        '🫐', '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝',
        '🍅', '🍆', '🥑', '🥦', '🥬', '🥒', '🌶️', '🫑',
        '🌽', '🥕', '🫒', '🧄', '🧅', '🥔', '🍠', '🥐',
      ],
    ),
    EmojiCategory(
      name: '活动',
      icon: '⚽',
      emojis: [
        '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉',
        '🥏', '🎱', '🪀', '🏓', '🏸', '🏒', '🏑', '🥍',
        '🏏', '🪃', '🥅', '⛳', '🪁', '🏹', '🎣', '🤿',
        '🥊', '🥋', '🎽', '🛹', '🛷', '⛸️', '🥌', '🎿',
      ],
    ),
    EmojiCategory(
      name: '符号',
      icon: '❤️',
      emojis: [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
        '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
        '💘', '💝', '💟', '☮️', '✝️', '☪️', '🕉️', '☸️',
        '✡️', '🔯', '🕎', '☯️', '☦️', '🛐', '⛎', '♈',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标签栏
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFF07C160),
              labelColor: const Color(0xFF07C160),
              unselectedLabelColor: Colors.grey[600],
              tabs: _categories.map((category) => Tab(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              )).toList(),
            ),
          ),
          // 表情网格
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) => _buildEmojiGrid(category)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(EmojiCategory category) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: category.emojis.length,
      itemBuilder: (context, index) {
        final emoji = category.emojis[index];
        return InkWell(
          onTap: () => widget.onEmojiSelected(emoji),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      },
    );
  }
}

class EmojiCategory {
  final String name;
  final String icon;
  final List<String> emojis;

  EmojiCategory({
    required this.name,
    required this.icon,
    required this.emojis,
  });
}