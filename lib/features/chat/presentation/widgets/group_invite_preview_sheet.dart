import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../providers/chat_provider.dart';

class GroupInvitePreviewSheet extends ConsumerStatefulWidget {
  final String inviteCode;

  const GroupInvitePreviewSheet({super.key, required this.inviteCode});

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    String inviteCode,
  ) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupInvitePreviewSheet(inviteCode: inviteCode),
    );
  }

  @override
  ConsumerState<GroupInvitePreviewSheet> createState() =>
      _GroupInvitePreviewSheetState();
}

class _GroupInvitePreviewSheetState
    extends ConsumerState<GroupInvitePreviewSheet> {
  late Future<Map<String, dynamic>> _preview;
  // Danh sách answer controller tương ứng với từng câu hỏi
  List<TextEditingController> _answerControllers = [];
  int _page = 0;
  bool _acceptedRules = false;
  bool _isSubmitting = false;

  /// Parse join_question (cách nhau bằng '\n---\n') thành danh sách câu hỏi.
  static List<String> _parseQuestions(String raw) {
    if (raw.trim().isEmpty) return [];
    return raw
        .split('\n---\n')
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _preview = ref
        .read(chatRepositoryProvider)
        .getGroupInvitePreview(widget.inviteCode)
        .then((data) {
      final questions =
          _parseQuestions(data['join_question'] as String? ?? '');
      _syncAnswerControllers(questions);
      return data;
    });
  }

  @override
  void dispose() {
    for (final c in _answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool _needsRequest(Map<String, dynamic> data) =>
      data['approval_required'] == true ||
      (data['join_rules'] as String? ?? '').trim().isNotEmpty ||
      (data['join_question'] as String? ?? '').trim().isNotEmpty;

  /// Đảm bảo _answerControllers khớp với số câu hỏi.
  void _syncAnswerControllers(List<String> questions) {
    if (_answerControllers.length == questions.length) return;
    for (var i = questions.length; i < _answerControllers.length; i++) {
      _answerControllers[i].dispose();
    }
    if (_answerControllers.length > questions.length) {
      _answerControllers = _answerControllers.sublist(0, questions.length);
    } else {
      while (_answerControllers.length < questions.length) {
        _answerControllers.add(TextEditingController());
      }
    }
  }

  bool _canContinue(Map<String, dynamic> data) {
    if (_page == 0) return true;
    final rules = (data['join_rules'] as String? ?? '').trim();
    final questions = _parseQuestions(data['join_question'] as String? ?? '');
    if (rules.isNotEmpty && !_acceptedRules) return false;
    if (questions.isNotEmpty) {
      if (_answerControllers.length != questions.length) return false;
      if (_answerControllers.any((c) => c.text.trim().isEmpty)) return false;
    }
    return true;
  }

  Future<void> _continue(Map<String, dynamic> data) async {
    if (_isSubmitting) return;
    final conversationId = data['conversation_id'] as String?;
    if (conversationId == null) return;

    if (data['already_member'] == true) {
      Navigator.of(context).pop({
        'status': 'joined',
        'conversation_id': conversationId,
        'already_member': true,
      });
      return;
    }
    if (data['request_pending'] == true) {
      Navigator.of(context).pop({'status': 'pending'});
      return;
    }
    if (_page == 0 && _needsRequest(data)) {
      setState(() => _page = 1);
      return;
    }
    if (_page == 1) {
      if (!_canContinue(data)) return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_needsRequest(data)) {
        final questions =
            _parseQuestions(data['join_question'] as String? ?? '');
        final answerParts = <String>[];
        for (var i = 0; i < questions.length; i++) {
          final ans = i < _answerControllers.length
              ? _answerControllers[i].text.trim()
              : '';
          if (ans.isNotEmpty) {
            if (questions.length == 1) {
              answerParts.add(ans);
            } else {
              answerParts.add('Câu ${i + 1}: $ans');
            }
          }
        }
        final combinedAnswer = answerParts.join('\n\n');

        final result = await ref
            .read(chatRepositoryProvider)
            .submitGroupJoinRequest(
              inviteCode: widget.inviteCode,
              answer: combinedAnswer,
              acceptedRules: _acceptedRules,
            );
        if (!mounted) return;
        final status = result['status'] as String?;
        Navigator.of(context).pop({
          'status': status == 'pending' ? 'pending' : 'joined',
          'conversation_id': result['conversation_id'] as String?,
          'already_member': false,
        });
      } else {
        final result = await ref
            .read(chatRepositoryProvider)
            .joinGroupByInvite(widget.inviteCode);
        if (!mounted) return;
        if (result['requires_request'] == true) {
          final refreshed = await ref
              .read(chatRepositoryProvider)
              .getGroupInvitePreview(widget.inviteCode);
          if (!mounted) return;
          final questions =
              _parseQuestions(refreshed['join_question'] as String? ?? '');
          _syncAnswerControllers(questions);
          setState(() {
            _preview = Future.value(refreshed);
            _page = 1;
          });
          return;
        }
        Navigator.of(context).pop({
          'status': 'joined',
          'conversation_id': result['conversation_id'] as String?,
          'already_member': result['already_member'] as bool? ?? false,
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tham gia nhóm: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _createdTime(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Đã tạo';
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'Đã tạo hôm nay';
    if (days == 1) return 'Đã tạo 1 ngày trước';
    if (days < 30) return 'Đã tạo $days ngày trước';
    final months = days ~/ 30;
    if (months == 1) return 'Đã tạo 1 tháng trước';
    if (months < 12) return 'Đã tạo $months tháng trước';
    final years = days ~/ 365;
    return years == 1 ? 'Đã tạo 1 năm trước' : 'Đã tạo $years năm trước';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _preview,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                        child: CupertinoActivityIndicator(
                            color: colorScheme.primary));
                  }
                  if (snapshot.hasError) {
                    return _errorContent(context, snapshot.error);
                  }
                  final data = snapshot.data ?? const <String, dynamic>{};
                  return _page == 0
                      ? _buildPreview(context, scrollController, data)
                      : _buildRequirements(context, scrollController, data);
                },
              ),
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: _preview,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.hasError) {
                  return const SizedBox.shrink();
                }
                return _buildBottomAction(context, snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(
    BuildContext context,
    ScrollController controller,
    Map<String, dynamic> data,
  ) {
    final theme = Theme.of(context);
    final name = data['group_name'] as String? ?? 'Nhóm trò chuyện';
    final avatar = data['avatar_url'] as String?;
    final creatorName = data['creator_name'] as String? ?? 'Thành viên';
    final creatorAvatar = data['creator_avatar_url'] as String?;
    final members = (data['member_count'] as num?)?.toInt() ?? 0;
    final friendsCount = (data['friends_count'] as num?)?.toInt() ?? 0;
    final friends = (data['friends'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF818CF8)]),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: AppAvatar(imageUrl: avatar, name: name, radius: 46),
          ),
        ),
        const SizedBox(height: 14),
        Text(name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text('$members thành viên',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        _infoRow(
          context,
          icon: CupertinoIcons.person_crop_circle,
          avatarUrl: creatorAvatar,
          title: 'Nhóm của $creatorName',
        ),
        const SizedBox(height: 12),
        _infoRow(
          context,
          icon: CupertinoIcons.calendar,
          title: _createdTime(data['created_at']),
        ),
        if (friends.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('$friendsCount bạn trong nhóm',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: friends.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final friend = friends[index];
                final friendName = friend['name'] as String? ?? '';
                return Tooltip(
                  message: friendName,
                  child: AppAvatar(
                    imageUrl: friend['avatar_url'] as String?,
                    name: friendName,
                    radius: 22,
                  ),
                );
              },
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Text('Chưa có bạn bè nào của bạn trong nhóm này',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }

  Widget _buildRequirements(
    BuildContext context,
    ScrollController controller,
    Map<String, dynamic> data,
  ) {
    final theme = Theme.of(context);
    final rules = data['join_rules'] as String? ?? '';
    final rawQuestion = data['join_question'] as String? ?? '';
    final questions = _parseQuestions(rawQuestion);
    _syncAnswerControllers(questions);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Row(children: [
          IconButton(
            onPressed: () => setState(() => _page = 0),
            icon: const Icon(CupertinoIcons.chevron_back),
          ),
          Expanded(
            child: Text(
              'Điều kiện tham gia',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 48),
        ]),
        const SizedBox(height: 16),
        if (rules.trim().isNotEmpty) ...[
          Text(
            'Quy định nhóm',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(rules, style: const TextStyle(height: 1.45)),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptedRules,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (value) =>
                setState(() => _acceptedRules = value ?? false),
            title: const Text('Tôi đã đọc và đồng ý với quy định'),
          ),
          const SizedBox(height: 12),
        ],
        if (questions.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Câu hỏi tham gia',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${questions.length} câu',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Vui lòng trả lời các câu hỏi để quản trị viên duyệt yêu cầu của bạn.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...List.generate(questions.length, (i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Câu hỏi ${i + 1}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    questions[i],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _answerControllers[i],
                    onChanged: (_) => setState(() {}),
                    minLines: 2,
                    maxLines: null,
                    maxLength: 500,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: 'Nhập câu trả lời cho câu ${i + 1}...',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 8),
        Text(
          'Yêu cầu tham gia sẽ chờ trưởng nhóm hoặc phó nhóm duyệt.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildBottomAction(BuildContext context, Map<String, dynamic> data) {
    final alreadyMember = data['already_member'] == true;
    final pending = data['request_pending'] == true;
    final requirements = _page == 1;
    final canContinue = _canContinue(data);
    final label = alreadyMember
        ? 'Mở cuộc trò chuyện'
        : pending
            ? 'Đang chờ duyệt'
            : requirements
                ? 'Gửi yêu cầu tham gia'
                : 'Tham gia';

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: _isSubmitting || pending || !canContinue
              ? null
              : () => _continue(data),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: _isSubmitting
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    String? avatarUrl,
    required String title,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (avatarUrl != null && avatarUrl.isNotEmpty)
          AppAvatar(imageUrl: avatarUrl, name: title, radius: 15)
        else
          Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _errorContent(BuildContext context, Object? error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(CupertinoIcons.exclamationmark_triangle,
              size: 38, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          const Text('Không tải được thông tin nhóm',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
