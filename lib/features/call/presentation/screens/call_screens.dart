import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../data/call_audio_service.dart';
import '../../domain/call_model.dart';
import '../../providers/call_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../chat/providers/chat_provider.dart';
import '../../../../core/services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OutgoingCallScreen — Màn hình đang gọi đi
// ─────────────────────────────────────────────────────────────────────────────
class OutgoingCallScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String calleeId;
  final String calleeName;
  final String? calleeAvatarUrl;
  final bool isVideo;

  /// Callback khi người kia nhấc máy / từ chối / timeout
  final VoidCallback? onCancel;

  const OutgoingCallScreen({
    super.key,
    required this.conversationId,
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatarUrl,
    this.isVideo = false,
    this.onCancel,
  });

  @override
  ConsumerState<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends ConsumerState<OutgoingCallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse1;
  late final Animation<double> _pulse2;
  late final Animation<double> _pulse3;

  int _elapsed = 0;
  bool _connecting = false; // true = đã kết nối, đang chuyển màn hình
  late final AnimationController _connectCtrl;
  Timer? _timer;

  static const _autoConnectSec = 10; // Giả lập kết nối sau 10s

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _connectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulse1 = Tween(begin: 1.0, end: 1.6).animate(CurvedAnimation(
      parent: _pulseCtrl,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));
    _pulse2 = Tween(begin: 1.0, end: 1.9).animate(CurvedAnimation(
      parent: _pulseCtrl,
      curve: const Interval(0.15, 0.95, curve: Curves.easeOut),
    ));
    _pulse3 = Tween(begin: 1.0, end: 2.2).animate(CurvedAnimation(
      parent: _pulseCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    // Rung liên tục avatar (dùng delayed để giãn cách)
    Future.doWhile(() async {
      if (!mounted) return false;
      await _pulseCtrl.forward();
      _pulseCtrl.reset();
      await Future.delayed(const Duration(milliseconds: 600));
      return mounted;
    });

    // Phát dialtone gọi đi
    CallAudioService().playDialtone();

    // Call API: create call
    _initCall();

    // Bắt đầu đếm thời gian
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      setState(() => _elapsed++);
      
      if (_elapsed >= 60) {
        _timer?.cancel();
        if (_currentCall != null) {
          await ref.read(callRepositoryProvider).updateStatus(_currentCall!.id, CallStatus.missed);
        }
        _sendLogAndPop(widget.isVideo ? 'Cuộc gọi video nhỡ' : 'Cuộc gọi thoại nhỡ');
      }
    });
  }

  CallModel? _currentCall;

  Future<void> _initCall() async {
    try {
      final repo = ref.read(callRepositoryProvider);
      final call = await repo.createCall(
        conversationId: widget.conversationId,
        calleeId: widget.calleeId,
        isVideo: widget.isVideo,
      );
      if (mounted) {
        setState(() => _currentCall = call);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể gọi: $e')));
        context.pop();
      }
    }
  }

  Future<void> _onConnected(CallModel call) async {
    if (!mounted || _connecting) return;
    setState(() => _connecting = true);
    _timer?.cancel();

    // Dừng dialtone khi kết nối
    await CallAudioService().stop();

    // Flash animation
    await _connectCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));

    // Chuyển sang màn hình Active (thay thế màn hình hiện tại)
    if (mounted) {
      context.pushReplacement('/call/active', extra: {
        'callModel': call,
        'otherName': widget.calleeName,
        'avatarUrl': widget.calleeAvatarUrl,
        'isVideo': widget.isVideo,
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _connectCtrl.dispose();
    _timer?.cancel();
    CallAudioService().stop(); // đảm bảo dừng âm thanh khi out
    super.dispose();
  }

  String get _elapsedStr {
    final m = _elapsed ~/ 60;
    final s = _elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool _logSent = false;

  void _sendLogAndPop(String content) {
    if (_logSent) return;
    _logSent = true;
    CallAudioService().stop();
    if (_currentCall != null) {
      ref.read(chatRepositoryProvider)
         .sendMessage(widget.conversationId, content, messageType: 'call_log');
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentCall != null) {
      ref.listen<AsyncValue<CallModel>>(callStateProvider(_currentCall!.id), (prev, next) {
        if (next.hasValue) {
          final call = next.value!;
          if (call.status == CallStatus.accepted && !_connecting) {
            _onConnected(call);
          } else if (call.status == CallStatus.declined) {
            _sendLogAndPop(widget.isVideo ? 'Cuộc gọi video bị từ chối' : 'Cuộc gọi thoại bị từ chối');
          } else if (call.status == CallStatus.missed) {
            _sendLogAndPop(widget.isVideo ? 'Cuộc gọi video nhỡ' : 'Cuộc gọi thoại nhỡ');
          } else if (call.status == CallStatus.ended) {
            _sendLogAndPop(widget.isVideo ? 'Cuộc gọi video đã kết thúc' : 'Cuộc gọi thoại đã kết thúc');
          }
        }
      });
    }

    const avatarRadius = 56.0;

    // Đường dẫn ảnh nền tuỳ chỉnh (sau này bạn thêm file thì đổi giá trị null thành 'assets/images/tên_file.jpg')
    const String? customBackgroundPath = 'assets/images/outgoing.jpg';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background (Ảnh tuỳ chỉnh hoặc ảnh avatar làm mờ)
          if (customBackgroundPath != null)
            Image.asset(customBackgroundPath, fit: BoxFit.cover)
          else if (widget.calleeAvatarUrl != null)
            Image.network(widget.calleeAvatarUrl!, fit: BoxFit.cover)
          else
            Container(color: const Color(0xFF1A2940)),
            
          // 2. Lớp phủ
          if (customBackgroundPath == null)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          
          // 3. Nội dung chính
          SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _connecting
                              ? Row(
                                  key: const ValueKey('connecting'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Đang kết nối...',
                                      key: const ValueKey('connecting_text'),
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  widget.isVideo ? 'Gọi video...' : 'Đang gọi...',
                                  key: const ValueKey('ringing'),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 15,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _connecting
                              ? const SizedBox.shrink(key: ValueKey('no_timer'))
                              : Text(
                                  _elapsedStr,
                                  key: const ValueKey('timer'),
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Avatar + tên
                  Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ripple rings
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (_, __) => Stack(
                              alignment: Alignment.center,
                              children: [
                                _Ring(scale: _pulse3.value, opacity: (1 - _pulse3.value / 2.2).clamp(0, 0.12)),
                                _Ring(scale: _pulse2.value, opacity: (1 - _pulse2.value / 1.9).clamp(0, 0.18)),
                                _Ring(scale: _pulse1.value, opacity: (1 - _pulse1.value / 1.6).clamp(0, 0.25)),
                              ],
                            ),
                          ),
                          // Glowing ring xung quanh avatar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: avatarRadius * 2 + 20,
                        height: avatarRadius * 2 + 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _connecting
                                ? AppColors.success.withValues(alpha: 0.8)
                                : AppColors.primary.withValues(alpha: 0.5),
                            width: _connecting ? 3 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_connecting ? AppColors.success : AppColors.primary)
                                  .withValues(alpha: 0.4),
                              blurRadius: _connecting ? 50 : 30,
                              spreadRadius: _connecting ? 12 : 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: AppAvatar(
                            imageUrl: widget.calleeAvatarUrl,
                            name: widget.calleeName,
                            radius: avatarRadius,
                          ),
                        ),
                      ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.calleeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.isVideo ? 'Video call' : 'Cuộc gọi thoại',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  // Nút huỷ (mờ dần khi kết nối)
                  AnimatedOpacity(
                    opacity: _connecting ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: _CallActionButton(
                        icon: CupertinoIcons.phone_down_fill,
                        label: 'Huỷ',
                        color: AppColors.error,
                        onTap: _connecting
                            ? null
                            : () async {
                                if (_currentCall != null) {
                                  await ref.read(callRepositoryProvider).updateStatus(_currentCall!.id, CallStatus.cancelled);
                                }
                                widget.onCancel?.call();
                                _sendLogAndPop(widget.isVideo ? 'Cuộc gọi video đã hủy' : 'Cuộc gọi thoại đã hủy');
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ), // SafeArea close
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IncomingCallScreen — Màn hình nhận cuộc gọi
// ─────────────────────────────────────────────────────────────────────────────
class IncomingCallScreen extends ConsumerStatefulWidget {
  final CallModel? callModel;
  final String callerName;
  final String? callerAvatarUrl;
  final bool isVideo;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const IncomingCallScreen({
    super.key,
    this.callModel,
    required this.callerName,
    this.callerAvatarUrl,
    this.isVideo = false,
    this.onAccept,
    this.onDecline,
  });

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Rung nhẹ icon điện thoại
    Future.doWhile(() async {
      if (!mounted) return false;
      await _shakeCtrl.forward();
      _shakeCtrl.reset();
      await Future.delayed(const Duration(milliseconds: 800));
      return mounted;
    });

    // Phát cộng chuông gọi đến
    CallAudioService().playRingtone();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    CallAudioService().stop(); // dừng cộng chuông
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.callModel != null) {
      ref.listen<AsyncValue<CallModel>>(callStateProvider(widget.callModel!.id), (prev, next) {
        if (next.hasValue) {
          final call = next.value!;
          if (call.status == CallStatus.cancelled || call.status == CallStatus.missed) {
            CallAudioService().stop();
            if (mounted) context.pop();
          }
        }
      });
    }

    // Đường dẫn ảnh nền tuỳ chỉnh (sau này bạn thêm file thì đổi giá trị null thành 'assets/images/tên_file.jpg')
    const String? customBackgroundPath = 'assets/images/incoming.jpg';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background (Ảnh tuỳ chỉnh hoặc ảnh avatar làm mờ)
          if (customBackgroundPath != null)
            Image.asset(customBackgroundPath, fit: BoxFit.cover)
          else if (widget.callerAvatarUrl != null)
            Image.network(widget.callerAvatarUrl!, fit: BoxFit.cover)
          else
            Container(color: const Color(0xFF1A2940)),
            
          // 2. Lớp phủ
          if (customBackgroundPath == null)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          
          // 3. Nội dung chính
          SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Incoming label
              AnimatedBuilder(
                animation: _shake,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shake.value, 0),
                  child: child,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isVideo
                          ? CupertinoIcons.videocam_fill
                          : CupertinoIcons.phone_fill,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isVideo
                          ? 'Cuộc gọi video đến'
                          : 'Cuộc gọi thoại đến',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Avatar
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(
                          alpha: (0.4 * (1 - _pulseCtrl.value)).clamp(0.05, 0.4),
                        ),
                        blurRadius: 30 + 20 * _pulseCtrl.value,
                        spreadRadius: 5 + 10 * _pulseCtrl.value,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: AppAvatar(
                  imageUrl: widget.callerAvatarUrl,
                  name: widget.callerName,
                  radius: 64,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                widget.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isVideo ? 'Muốn video call với bạn' : 'Đang gọi điện cho bạn',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),

              const Spacer(),

              // Nút decline & accept
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 56),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Từ chối
                    Column(
                      children: [
                        _CallActionButton(
                          icon: CupertinoIcons.phone_down_fill,
                          label: 'Từ chối',
                          color: AppColors.error,
                          size: 64,
                          onTap: () async {
                            CallAudioService().stop();
                            if (widget.callModel != null) {
                              await ref.read(callRepositoryProvider).updateStatus(widget.callModel!.id, CallStatus.declined);
                            }
                            widget.onDecline?.call();
                            if (mounted) context.pop();
                          },
                        ),
                      ],
                    ),

                    // Nhấc máy
                    Column(
                      children: [
                        _CallActionButton(
                          icon: widget.isVideo
                              ? CupertinoIcons.videocam_fill
                              : CupertinoIcons.phone_fill,
                          label: 'Nhấc máy',
                          color: AppColors.success,
                          size: 64,
                          onTap: () async {
                            CallAudioService().stop();
                            if (widget.callModel != null) {
                              await ref.read(callRepositoryProvider).updateStatus(widget.callModel!.id, CallStatus.accepted);
                            }
                            widget.onAccept?.call();
                            if (mounted) {
                              context.pushReplacement('/call/active', extra: {
                                'callModel': widget.callModel,
                                'otherName': widget.callerName,
                                'avatarUrl': widget.callerAvatarUrl,
                                'isVideo': widget.isVideo,
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          ), // SafeArea close
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ActiveCallScreen — Màn hình đang trong cuộc gọi
// ─────────────────────────────────────────────────────────────────────────────
class ActiveCallScreen extends ConsumerStatefulWidget {
  final CallModel? callModel;
  final String otherName;
  final String? otherAvatarUrl;
  final bool isVideo;
  final VoidCallback? onEnd;

  const ActiveCallScreen({
    super.key,
    this.callModel,
    required this.otherName,
    this.otherAvatarUrl,
    this.isVideo = false,
    this.onEnd,
  });

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  Room? _room;
  LocalParticipant? _localParticipant;

  bool _muted = false;
  bool _speakerOn = false;
  bool _cameraOff = false;
  bool _controlsVisible = true;

  int _seconds = 0;
  Timer? _timer;

  bool _logSent = false;

  void _sendLog(CallModel call) {
    if (_logSent) return;
    final currentUser = ref.read(supabaseServiceProvider).client.auth.currentUser;
    if (currentUser != null && call.callerId == currentUser.id) {
      _logSent = true;
      final typeStr = widget.isVideo ? 'video' : 'thoại';
      ref.read(chatRepositoryProvider)
         .sendMessage(call.conversationId, 'Cuộc gọi $typeStr - $_durationStr', messageType: 'call_log');
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    if (widget.callModel == null) return;

    try {
      debugPrint('==== BẮT ĐẦU KẾT NỐI LIVEKIT ====');
      debugPrint('1. Đang lấy token cho room: ${widget.callModel!.roomName}');
      // 1. Fetch token
      final token = await ref.read(callRepositoryProvider).getLiveKitToken(widget.callModel!.roomName);
      debugPrint('👉 Đã lấy token thành công! Token (50 ký tự đầu): ${token.length > 50 ? token.substring(0, 50) : token}...');

      debugPrint('2. Đang tạo Room và xin quyền...');
      // 2. Connect
      final room = Room();
      
      // Request permissions
      if (!kIsWeb) {
        await [Permission.camera, Permission.microphone].request();
      }

      final url = ref.read(callRepositoryProvider).getLiveKitUrl();
      debugPrint('3. Đang gọi room.connect tới URL: $url');
      
      await room.connect(
        url,
        token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      
      debugPrint('👉 Đã kết nối WebRTC thành công!');

      debugPrint('4. Đang bật microphone/camera...');
      // 3. Enable tracks
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (widget.isVideo) {
        await room.localParticipant?.setCameraEnabled(true);
      }

      if (mounted) {
        setState(() {
          _room = room;
          _localParticipant = room.localParticipant;
        });

        // Listen for participants
        _room?.addListener(_onRoomEvent);
        debugPrint('==== HOÀN TẤT SETUP KHÔNG CÓ LỖI ====');
      }
    } catch (e, stackTrace) {
      debugPrint('❌❌ LiveKit connection error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi kết nối phòng gọi: $e')));
        _endCall();
      }
    }
  }

  void _onRoomEvent() {
    if (mounted) setState(() {});
  }

  Future<void> _endCall() async {
    _room?.disconnect();
    
    if (widget.callModel != null) {
      final call = widget.callModel!;
      _sendLog(call);
      await ref.read(callRepositoryProvider).updateStatus(call.id, CallStatus.ended);
    }
    
    widget.onEnd?.call();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _room?.removeListener(_onRoomEvent);
    _room?.disconnect();
    super.dispose();
  }

  String get _durationStr {
    final h = _seconds ~/ 3600;
    final m = (_seconds % 3600) ~/ 60;
    final s = _seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.callModel != null) {
      ref.listen<AsyncValue<CallModel>>(callStateProvider(widget.callModel!.id), (prev, next) {
        if (next.hasValue) {
          final call = next.value!;
          if (call.status == CallStatus.ended || call.status == CallStatus.declined) {
            _sendLog(call);
            _room?.disconnect();
            if (mounted) context.pop();
          }
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background — khi là voice call hiện avatar lớn blur
            if (!widget.isVideo) _buildVoiceBackground(),

            // Remote video
            if (widget.isVideo && _room != null) _buildRemoteVideo(),

            // Header — thời gian
            _buildHeader(),

            // Local video thumbnail (góc trên phải — chỉ video call)
            if (widget.isVideo)
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                right: 26,
                child: _buildLocalVideoThumbnail(),
              ),

            // Control bar ở dưới
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: _controlsVisible ? 0 : -180,
              left: 0,
              right: 0,
              child: _buildControlBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceBackground({bool showType = true}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Hình nền blur từ avatar
        if (widget.otherAvatarUrl != null)
          Image.network(
            widget.otherAvatarUrl!,
            fit: BoxFit.cover,
          )
        else
          Container(color: const Color(0xFF1A2940)),
        
        // Phủ mờ và lớp màu tối
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),

        // Avatar và tên ở giữa
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.1),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: AppAvatar(
                  imageUrl: widget.otherAvatarUrl,
                  name: widget.otherName,
                  radius: 70,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.otherName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              if (showType) ...[
                const SizedBox(height: 8),
                const Text(
                  'Cuộc gọi thoại',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteVideo() {
    final participants = _room?.remoteParticipants.values;
    if (participants == null || participants.isEmpty) {
      return _buildVoiceBackground(showType: false);
    }
    final remoteParticipant = participants.first;
    final trackPub = remoteParticipant.videoTrackPublications.firstOrNull;
    
    if (trackPub != null && trackPub.track != null && !trackPub.muted) {
      return VideoTrackRenderer(trackPub.track as VideoTrack);
    }
    return _buildVoiceBackground(showType: false);
  }

  Widget _buildLocalVideoThumbnail() {
    final user = ref.read(supabaseServiceProvider).client.auth.currentUser;
    final myAvatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final myName = user?.userMetadata?['full_name'] as String? ?? 'Me';

    if (_localParticipant == null) {
      return Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const CupertinoActivityIndicator(),
      );
    }

    final trackPub = _localParticipant!.videoTrackPublications.firstOrNull;
    
    Widget child;
    if (trackPub != null && trackPub.track != null && !_cameraOff) {
      child = VideoTrackRenderer(trackPub.track as VideoTrack);
    } else {
      child = Container(
        color: const Color(0xFF1A2940),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (myAvatarUrl != null)
              Image.network(myAvatarUrl, fit: BoxFit.cover),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            Center(
              child: AppAvatar(
                imageUrl: myAvatarUrl,
                name: myName,
                radius: 28,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 100,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 26,
      left: 26,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _durationStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _muted ? CupertinoIcons.mic_slash_fill : CupertinoIcons.mic_fill,
                    label: _muted ? 'Bật mic' : 'Tắt mic',
                    active: _muted,
                    onTap: () {
                      _localParticipant?.setMicrophoneEnabled(_muted);
                      setState(() => _muted = !_muted);
                    },
                  ),
                  if (widget.isVideo)
                    _ControlButton(
                      icon: _cameraOff ? CupertinoIcons.video_camera_solid : CupertinoIcons.video_camera,
                      label: _cameraOff ? 'Bật cam' : 'Tắt cam',
                      active: _cameraOff,
                      onTap: () async {
                        await _localParticipant?.setCameraEnabled(_cameraOff);
                        setState(() => _cameraOff = !_cameraOff);
                      },
                    ),
                  _ControlButton(
                    icon: _speakerOn
                        ? CupertinoIcons.speaker_3_fill
                        : CupertinoIcons.speaker_fill,
                    label: _speakerOn ? 'Loa ngoài' : 'Loa trong',
                    active: _speakerOn,
                    onTap: () => setState(() => _speakerOn = !_speakerOn),
                  ),
                  _CallActionButton(
                    icon: CupertinoIcons.phone_down_fill,
                    label: 'Kết thúc',
                    color: AppColors.error,
                    size: 56,
                    onTap: _endCall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Nút hành động lớn (nhấc / gác máy)
class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const _CallActionButton({
    required this.icon,
    required this.color,
    this.label,
    this.size = 60,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: size * 0.42,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(
              label!,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nút điều khiển nhỏ trong ActiveCallScreen (mute, camera, speaker)
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active ? Colors.black : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Vòng tròn ripple cho OutgoingCallScreen
class _Ring extends StatelessWidget {
  final double scale;
  final double opacity;

  const _Ring({required this.scale, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 148,
        height: 148,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: opacity),
            width: 2,
          ),
        ),
      ),
    );
  }
}
