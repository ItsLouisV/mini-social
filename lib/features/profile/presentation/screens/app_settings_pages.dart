import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  static const _keys = <String>[
    'viora_notif_messages',
    'viora_notif_social',
    'viora_notif_groups',
    'viora_notif_sound',
    'viora_notif_vibration',
  ];
  final Map<String, bool> _values = {
    'viora_notif_messages': true,
    'viora_notif_social': true,
    'viora_notif_groups': true,
    'viora_notif_sound': true,
    'viora_notif_vibration': true,
  };
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final key in _keys) {
        _values[key] = preferences.getBool(key) ?? true;
      }
      _loaded = true;
    });
  }

  Future<void> _update(String key, bool value) async {
    setState(() => _values[key] = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsPageFrame(
      title: 'Thông báo',
      child: Column(children: [
        _SettingsSection(title: 'LOẠI THÔNG BÁO', children: [
          _SettingsSwitchRow(
            icon: CupertinoIcons.chat_bubble_text_fill,
            title: 'Tin nhắn',
            subtitle: 'Thông báo khi có tin nhắn mới',
            value: _values[_keys[0]]!,
            enabled: _loaded,
            onChanged: (value) => _update(_keys[0], value),
          ),
          _SettingsDivider(color: theme.dividerColor),
          _SettingsSwitchRow(
            icon: CupertinoIcons.heart_fill,
            title: 'Tương tác',
            subtitle: 'Lượt thích, bình luận và người theo dõi mới',
            value: _values[_keys[1]]!,
            enabled: _loaded,
            onChanged: (value) => _update(_keys[1], value),
          ),
          _SettingsDivider(color: theme.dividerColor),
          _SettingsSwitchRow(
            icon: CupertinoIcons.person_2_fill,
            title: 'Nhóm',
            subtitle: 'Lời mời và hoạt động trong nhóm',
            value: _values[_keys[2]]!,
            enabled: _loaded,
            onChanged: (value) => _update(_keys[2], value),
          ),
        ]),
        _SettingsSection(title: 'CÁCH NHẬN THÔNG BÁO', children: [
          _SettingsSwitchRow(
            icon: CupertinoIcons.speaker_2_fill,
            title: 'Âm thanh',
            value: _values[_keys[3]]!,
            enabled: _loaded,
            onChanged: (value) => _update(_keys[3], value),
          ),
          _SettingsDivider(color: theme.dividerColor),
          _SettingsSwitchRow(
            icon: CupertinoIcons.hand_draw_fill,
            title: 'Rung',
            value: _values[_keys[4]]!,
            enabled: _loaded,
            onChanged: (value) => _update(_keys[4], value),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Text(
            'Tùy chọn được lưu trên thiết bị này. Quyền gửi thông báo của hệ điều hành vẫn được quản lý trong Cài đặt thiết bị.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor, fontSize: 12, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

class VioraAboutScreen extends StatelessWidget {
  const VioraAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsPageFrame(
      title: 'Về Viora',
      child: Column(
        children: [
          const SizedBox(height: 28),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(CupertinoIcons.sparkles,
                color: Colors.white, size: 44),
          ),
          const SizedBox(height: 18),
          Text(
            'Viora',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kết nối gần hơn, chia sẻ dễ dàng hơn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'PHIÊN BẢN 1.0.0',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _SettingsSection(
            title: 'VỀ ỨNG DỤNG',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Viora là không gian để bạn giữ liên lạc với bạn bè, chia sẻ những điều đang diễn ra và trò chuyện mỗi ngày.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'BẠN CÓ THỂ',
            children: [
              const _AboutFeatureRow(
                icon: CupertinoIcons.person_2_fill,
                title: 'Kết nối bạn bè',
                subtitle: 'Tìm bạn và cập nhật hoạt động của nhau.',
              ),
              _SettingsDivider(color: theme.dividerColor),
              const _AboutFeatureRow(
                icon: CupertinoIcons.photo_fill,
                title: 'Chia sẻ khoảnh khắc',
                subtitle: 'Đăng bài viết và hình ảnh của bạn.',
              ),
              _SettingsDivider(color: theme.dividerColor),
              const _AboutFeatureRow(
                icon: CupertinoIcons.chat_bubble_2_fill,
                title: 'Trò chuyện',
                subtitle: 'Nhắn tin riêng hoặc trò chuyện theo nhóm.',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: Text(
              '© Viora',
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPageFrame extends StatelessWidget {
  final String title;
  final Widget child;
  const _SettingsPageFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.chevron_back,
                  color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 4),
              Text('Cài đặt',
                  style: TextStyle(
                      color: theme.colorScheme.primary, fontSize: 16)),
            ],
          ),
        ),
        middle: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = theme.brightness == Brightness.dark
        ? const Color(0xFF8E8E93)
        : const Color(0xFF6C6C70);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(title, style: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ]),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Icon(icon, size: 19, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: TextStyle(fontSize: 12, color: theme.hintColor)),
              ),
          ]),
        ),
        CupertinoSwitch(value: value, onChanged: enabled ? onChanged : null),
      ]),
    );
  }
}

class _AboutFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _AboutFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: theme.hintColor, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  final Color color;
  const _SettingsDivider({required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 44),
        child: Divider(height: 1, thickness: 0.5, color: color.withValues(alpha: 0.35)),
      );
}
