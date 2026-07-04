import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/chat_provider.dart';
import '../widgets/full_screen_image_viewer.dart';

class SharedMediaScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const SharedMediaScreen({super.key, required this.conversationId});

  @override
  ConsumerState<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

class _SharedMediaScreenState extends ConsumerState<SharedMediaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final messagesAsync = ref.watch(realtimeMessagesProvider(widget.conversationId));
    final allMessages = messagesAsync.valueOrNull?.messages ?? [];

    final imageMessages = allMessages
        .where((m) => m.isImage || (m.mediaUrl != null && m.mediaUrl!.isNotEmpty))
        .toList();

    // Currently the app doesn't have video upload, so this is empty by default
    final videoMessages = allMessages.where((m) => m.messageType == 'video').toList();

    final bgColor = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF6F8FA);
    final cardBgColor = isDark ? const Color(0xFF1E1E2F) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Kho lưu trữ phương tiện',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.left_chevron, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: theme.scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.hintColor,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(text: 'Ảnh (${imageMessages.length})'),
                Tab(text: 'Video (${videoMessages.length})'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Photos ────────────────────────────────────────────────
          _buildPhotosTab(imageMessages, cardBgColor, theme),

          // ── Tab 2: Videos ────────────────────────────────────────────────
          _buildVideosTab(videoMessages, cardBgColor, theme),
        ],
      ),
    );
  }

  Widget _buildPhotosTab(List<dynamic> imageMessages, Color cardBgColor, ThemeData theme) {
    if (imageMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.photo_on_rectangle, size: 50, color: theme.hintColor.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Chưa chia sẻ hình ảnh nào',
              style: TextStyle(color: theme.hintColor, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: imageMessages.length,
      itemBuilder: (context, index) {
        final msg = imageMessages[index];
        return GestureDetector(
          onTap: () => _openFullScreenImage(context, msg.mediaUrl!),
          child: Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Hero(
                tag: msg.mediaUrl!,
                child: CachedNetworkImage(
                  imageUrl: msg.mediaUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(child: CupertinoActivityIndicator()),
                  errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 30),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideosTab(List<dynamic> videoMessages, Color cardBgColor, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.videocam_circle, size: 50, color: theme.hintColor.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Chưa chia sẻ video nào',
            style: TextStyle(color: theme.hintColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    FullScreenImageViewer.open(context, imageUrl);
  }
}
