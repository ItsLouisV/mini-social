import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/toast_service.dart';
import '../../providers/chat_provider.dart';

class GroupInviteLinkScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const GroupInviteLinkScreen({
    super.key,
    required this.conversationId,
  });

  @override
  ConsumerState<GroupInviteLinkScreen> createState() =>
      _GroupInviteLinkScreenState();
}

class _GroupInviteLinkScreenState extends ConsumerState<GroupInviteLinkScreen> {
  late Future<Map<String, dynamic>> _linkFuture;
  final _rulesController = TextEditingController();
  // Tối đa 3 câu hỏi, mỗi câu hỏi là một controller riêng
  final List<TextEditingController> _questionControllers = [
    TextEditingController(),
  ];
  bool _isUpdating = false;
  bool _isSavingRequirements = false;
  bool _approvalRequired = false;

  @override
  void initState() {
    super.initState();
    _linkFuture = Future.microtask(() => ref
            .read(chatRepositoryProvider)
            .getGroupInviteLink(widget.conversationId))
        .then((data) {
      _rulesController.text = data['join_rules'] as String? ?? '';
      // join_question được lưu là chuỗi, mỗi câu hỏi cách nhau bằng '\n---\n'
      final raw = data['join_question'] as String? ?? '';
      final questions = raw.isEmpty
          ? <String>[]
          : raw.split('\n---\n').map((q) => q.trim()).where((q) => q.isNotEmpty).toList();
      // Đặt tối đa 3 câu hỏi vào controllers
      for (var i = 0; i < _questionControllers.length; i++) {
        _questionControllers[i].text = i < questions.length ? questions[i] : '';
      }
      // Thêm controllers còn thiếu nếu dữ liệu có nhiều hơn 1 câu hỏi
      for (var i = _questionControllers.length; i < questions.length && i < 3; i++) {
        _questionControllers.add(TextEditingController(text: questions[i]));
      }
      _approvalRequired = data['approval_required'] as bool? ?? false;
      return data;
    });
  }

  @override
  void dispose() {
    _rulesController.dispose();
    for (final c in _questionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveRequirements() async {
    if (_isSavingRequirements) return;
    setState(() => _isSavingRequirements = true);
    try {
      final result = await ref.read(chatRepositoryProvider)
          .configureGroupInviteRequirements(
        widget.conversationId,
        approvalRequired: _approvalRequired,
        joinRules: _rulesController.text.trim(),
        // Ghép các câu hỏi thành chuỗi phân cách bằng '\n---\n'
        joinQuestion: _questionControllers
            .map((c) => c.text.trim())
            .where((q) => q.isNotEmpty)
            .join('\n---\n'),
      );
      if (!mounted) return;
      setState(() {
        _linkFuture = Future.value(result);
      });
      ToastService.showSuccess(context, 'Đã lưu điều kiện tham gia nhóm');
    } catch (error) {
      if (mounted) ToastService.showError(context, 'Không thể lưu điều kiện: $error');
    } finally {
      if (mounted) setState(() => _isSavingRequirements = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .setGroupInviteLinkEnabled(widget.conversationId, enabled: enabled);
      if (!mounted) return;
      setState(() {
        _linkFuture = Future.value(result);
      });
      ToastService.showSuccess(
        context,
        enabled ? 'Đã bật link mời vào nhóm' : 'Đã tắt link mời vào nhóm',
      );
    } catch (error) {
      if (mounted) {
        ToastService.showError(context, 'Không thể cập nhật link nhóm: $error');
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) ToastService.showSuccess(context, 'Đã sao chép link nhóm');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final conversation = ref
        .watch(conversationsProvider)
        .valueOrNull
        ?.where((item) => item.id == widget.conversationId)
        .firstOrNull;
    final groupName = conversation?.groupName ?? 'Nhóm trò chuyện';
    final pageColor =
        isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FB);
    final cardColor = isDark ? const Color(0xFF1E1E2F) : Colors.white;

    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: pageColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(CupertinoIcons.chevron_back,
              color: theme.colorScheme.primary, size: 24),
        ),
        title: const Text('Link nhóm',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _linkFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (snapshot.hasError) {
            return _buildError(context, snapshot.error);
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final isEnabled = data['is_enabled'] as bool? ?? false;
          final isOwner = data['is_owner'] as bool? ?? false;
          final inviteCode = data['invite_code'] as String?;
          final inviteLink =
              inviteCode == null ? null : 'viora://group/$inviteCode';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(CupertinoIcons.link,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            isEnabled ? 'Link đang hoạt động' : 'Link đang tắt',
                            style: TextStyle(
                              color: isEnabled
                                  ? const Color(0xFF34C759)
                                  : theme.hintColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOwner && _isUpdating)
                      const CupertinoActivityIndicator()
                    else if (isOwner)
                      Switch.adaptive(
                        value: isEnabled,
                        activeTrackColor: AppColors.primary,
                        onChanged: _setEnabled,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.08),
                  ),
                ),
                child: isEnabled && inviteLink != null
                    ? Column(
                        children: [
                          Text(
                            'Mời mọi người tham gia',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Quét mã QR hoặc sao chép link để chia sẻ.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: theme.hintColor, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: inviteLink,
                              size: 220,
                              version: QrVersions.auto,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF0F172A),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF28283A)
                                  : const Color(0xFFF4F6FA),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    inviteLink,
                                    maxLines: 2,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.9)
                                          : const Color(0xFF243047),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Sao chép link',
                                  onPressed: () => _copyLink(inviteLink),
                                  icon: const Icon(CupertinoIcons.doc_on_doc,
                                      color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(0xFFF3F5F8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CupertinoIcons.qrcode,
                                color: theme.hintColor, size: 30),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isOwner
                                ? 'Bật link để tạo mã QR'
                                : 'Trưởng nhóm đã tắt chức năng này',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isOwner
                                ? 'Khi tắt, link cũ cũng sẽ mất hiệu lực. Bật lại sẽ tạo link mới.'
                                : 'Hãy liên hệ với trưởng nhóm để tạo mã QR và link tham gia cho nhóm này.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: theme.hintColor, fontSize: 13),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(CupertinoIcons.info_circle_fill,
                        color: AppColors.primary, size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isOwner
                            ? 'Người có link có thể gửi yêu cầu tham gia. Bạn có thể yêu cầu họ đồng ý quy định, trả lời câu hỏi và chờ trưởng nhóm hoặc phó nhóm duyệt.'
                            : 'Người có link có thể gửi yêu cầu tham gia theo điều kiện nhóm. Trưởng nhóm và phó nhóm duyệt yêu cầu.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.8),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Điều kiện tham gia',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Duyệt thành viên mới'),
                        subtitle: const Text(
                            'Trưởng nhóm hoặc phó nhóm cần duyệt trước khi họ vào nhóm.'),
                        value: _approvalRequired,
                        activeTrackColor: AppColors.primary,
                        onChanged: (value) =>
                            setState(() => _approvalRequired = value),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _rulesController,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 4000,
                        decoration: const InputDecoration(
                          labelText: 'Quy định nhóm (không bắt buộc)',
                          hintText: 'Người xin tham gia cần đọc và đồng ý...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ── Câu hỏi khi xin vào (tối đa 3 câu hỏi) ──────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Câu hỏi khi xin vào (tối đa 3)',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_questionControllers.length < 3)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _questionControllers.add(
                                        TextEditingController(),
                                      );
                                    });
                                  },
                                  icon: const Icon(
                                    CupertinoIcons.plus_circle_fill,
                                    size: 16,
                                  ),
                                  label: const Text('Thêm câu hỏi'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...List.generate(_questionControllers.length, (i) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TextField(
                                controller: _questionControllers[i],
                                // Multi-line: Enter xuống dòng, không giới hạn dòng
                                minLines: 2,
                                maxLines: null,
                                maxLength: 500,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                decoration: InputDecoration(
                                  labelText: 'Câu hỏi ${i + 1}',
                                  hintText: i == 0
                                      ? 'Ví dụ: Bạn biết nhóm từ đâu?'
                                      : i == 1
                                          ? 'Ví dụ: Bạn đồng ý với nội quy nhóm?'
                                          : 'Ví dụ: Giới thiệu bản thân ngắn gọn...',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: _questionControllers.length > 1
                                      ? IconButton(
                                          tooltip: 'Xóa câu hỏi này',
                                          icon: const Icon(
                                            CupertinoIcons.minus_circle_fill,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _questionControllers[i]
                                                  .dispose();
                                              _questionControllers.removeAt(i);
                                            });
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSavingRequirements ? null : _saveRequirements,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.45),
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.8),
                          ),
                          child: _isSavingRequirements
                              ? const CupertinoActivityIndicator()
                              : const Text('Lưu điều kiện tham gia'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Yêu cầu duyệt, quy định hoặc câu hỏi sẽ khiến người quét link gửi đơn xin tham gia. Phó nhóm có thể duyệt đơn trong mục Quản lý nhóm.',
                        style: TextStyle(color: theme.hintColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, Object? error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.lock_shield_fill,
                size: 38, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text(
              'Bạn cần là thành viên của nhóm để xem link nhóm.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.hintColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
