import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/toast_service.dart';
import '../../../../core/utils/media_save_service.dart';
import '../../domain/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../utils/chat_link_utils.dart';
import '../widgets/full_screen_image_viewer.dart';

class _SharedArchiveItem {
  final String title;
  final String url;
  final bool isFile;

  const _SharedArchiveItem({
    required this.title,
    required this.url,
    required this.isFile,
  });
}

class SharedMediaScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const SharedMediaScreen({super.key, required this.conversationId});

  @override
  ConsumerState<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

class _SharedMediaScreenState extends ConsumerState<SharedMediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final messagesAsync =
        ref.watch(realtimeMessagesProvider(widget.conversationId));
    final allMessages = messagesAsync.valueOrNull?.messages ?? [];
    final imageMessages = allMessages.where((message) => message.isImage).toList();
    final videoMessages = allMessages
        .where((message) => message.isVideo || message.messageType == 'video')
        .toList();
    final archiveItems = _buildArchiveItems(allMessages);

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
          icon: Icon(CupertinoIcons.chevron_back,
              color: theme.colorScheme.primary, size: 24),
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
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(text: 'Ảnh (${imageMessages.length})'),
                Tab(text: 'Video (${videoMessages.length})'),
                Tab(text: 'File/Link (${archiveItems.length})'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPhotosTab(imageMessages, cardBgColor, theme),
          _buildVideosTab(videoMessages, theme),
          _buildArchiveTab(archiveItems, cardBgColor, theme),
        ],
      ),
    );
  }

  List<_SharedArchiveItem> _buildArchiveItems(List<MessageModel> messages) {
    final items = <_SharedArchiveItem>[];
    for (final message in messages) {
      if (message.isFile) {
        for (final url in message.mediaUrls) {
          items.add(_SharedArchiveItem(
            title: message.content?.trim().isNotEmpty == true
                ? message.content!.trim()
                : 'Tệp đính kèm',
            url: url,
            isFile: true,
          ));
        }
      } else if (message.isText) {
        for (final link in ChatLinkUtils.findLinks(message.content ?? '')) {
          items.add(_SharedArchiveItem(
            title: link.text,
            url: link.url,
            isFile: false,
          ));
        }
      }
    }
    return items.reversed.toList();
  }

  Widget _buildPhotosTab(
    List<MessageModel> imageMessages,
    Color cardBgColor,
    ThemeData theme,
  ) {
    if (imageMessages.isEmpty) {
      return _buildEmptyState(
        CupertinoIcons.photo_on_rectangle,
        'Chưa chia sẻ hình ảnh nào',
        theme,
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
        final message = imageMessages[index];
        final url = message.firstMediaUrl;
        if (url == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => FullScreenImageViewer.open(context, url),
          child: Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Hero(
                tag: url,
                child: kIsWeb
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(CupertinoIcons.photo, size: 30),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const Center(child: CupertinoActivityIndicator()),
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const Center(child: CupertinoActivityIndicator()),
                        errorWidget: (_, __, ___) =>
                            const Icon(CupertinoIcons.photo, size: 30),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideosTab(List<MessageModel> videoMessages, ThemeData theme) {
    if (videoMessages.isEmpty) {
      return _buildEmptyState(
        CupertinoIcons.videocam_circle,
        'Chưa chia sẻ video nào',
        theme,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: videoMessages.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final message = videoMessages[index];
        final url = message.firstMediaUrl;
        if (url == null) return const SizedBox.shrink();
        return ListTile(
          leading: const Icon(CupertinoIcons.play_rectangle_fill),
          title: Text(message.content?.trim().isNotEmpty == true
              ? message.content!.trim()
              : 'Video'),
          subtitle: const Text('Video đã chia sẻ'),
          onTap: () => _openUrl(url),
          trailing: IconButton(
            tooltip: 'Lưu video',
            icon: const Icon(CupertinoIcons.arrow_down_to_line),
            onPressed: () => _saveUrl(url, 'video'),
          ),
        );
      },
    );
  }

  Widget _buildArchiveTab(
    List<_SharedArchiveItem> items,
    Color cardBgColor,
    ThemeData theme,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        CupertinoIcons.doc_text,
        'Chưa có file hoặc link nào được chia sẻ',
        theme,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final item = items[index];
        final icon = item.isFile
            ? CupertinoIcons.doc_fill
            : CupertinoIcons.link;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(item.isFile ? 'Tệp đính kèm' : 'Liên kết'),
          onTap: () => _openUrl(item.url),
          trailing: item.isFile
              ? IconButton(
                  tooltip: 'Lưu file',
                  icon: Icon(CupertinoIcons.arrow_down_to_line,
                      color: theme.colorScheme.primary),
                  onPressed: () => _saveUrl(
                    item.url,
                    item.title,
                    preferredFileName: item.title,
                  ),
                )
              : Icon(CupertinoIcons.arrow_up_right,
                  color: theme.hintColor, size: 18),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50, color: theme.hintColor.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: theme.hintColor, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ToastService.showError(context, 'Không thể mở liên kết này');
      }
    }
  }

  Future<void> _saveUrl(
    String url,
    String name, {
    String? preferredFileName,
  }) async {
    try {
      await MediaSaveService.saveUrls(
        [url],
        fallbackBaseName: name,
        preferredFileNames:
            preferredFileName == null ? null : [preferredFileName],
      );
    } catch (error) {
      if (mounted) {
        ToastService.showError(context, 'Không thể lưu file. Vui lòng thử lại.');
      }
    }
  }
}
