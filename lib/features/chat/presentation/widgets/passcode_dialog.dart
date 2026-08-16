import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../providers/hidden_chat_provider.dart';

enum PasscodeMode { setup, verify }

/// Returns [true] if successfully setup/verified.
/// Returns [false] or [null] if canceled or failed permanently.
class PasscodeDialog extends ConsumerStatefulWidget {
  final PasscodeMode mode;
  final String? title;

  const PasscodeDialog({
    super.key,
    required this.mode,
    this.title,
  });

  static Future<bool?> show(BuildContext context, {required PasscodeMode mode, String? title}) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Passcode',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PasscodeDialog(mode: mode, title: title);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends ConsumerState<PasscodeDialog> with SingleTickerProviderStateMixin {
  // Toàn cục lưu số lần thử sai và thời điểm hết khóa trong phiên làm việc
  static int _globalFailedAttempts = 0;
  static DateTime? _globalLockoutEndTime;

  String _passcode = '';
  String _errorMessage = '';
  late PasscodeMode _currentMode;
  Timer? _countdownTimer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  bool get _isLockedOut {
    if (_globalLockoutEndTime == null) return false;
    return DateTime.now().isBefore(_globalLockoutEndTime!);
  }

  Duration get _remainingLockout {
    if (_globalLockoutEndTime == null) return Duration.zero;
    final diff = _globalLockoutEndTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
        setState(() {
          _passcode = '';
        });
      }
    });

    if (_isLockedOut) {
      _startCountdownTimer();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isLockedOut) {
        timer.cancel();
        setState(() {
          _errorMessage = '';
        });
      } else {
        setState(() {});
      }
    });
  }

  void _onKeyPress(String key) {
    if (_isLockedOut) return;
    if (_passcode.length < 6 && !_shakeController.isAnimating) {
      setState(() {
        _passcode += key;
        _errorMessage = '';
      });

      if (_passcode.length == 6) {
        _onComplete();
      }
    }
  }

  void _onDelete() {
    if (_isLockedOut) return;
    if (_passcode.isNotEmpty && !_shakeController.isAnimating) {
      setState(() {
        _passcode = _passcode.substring(0, _passcode.length - 1);
        _errorMessage = '';
      });
    }
  }

  Future<void> _onComplete() async {
    if (_isLockedOut) return;
    final enteredPasscode = _passcode;

    if (_currentMode == PasscodeMode.setup) {
      // Thiết lập mã PIN mới
      await ref.read(hiddenChatProvider.notifier).setPasscode(enteredPasscode);
      _globalFailedAttempts = 0;
      _globalLockoutEndTime = null;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      // Xác thực mã PIN
      final isValid = await ref.read(hiddenChatProvider.notifier).verifyPasscode(enteredPasscode);
      if (!mounted) return;

      if (isValid) {
        _globalFailedAttempts = 0;
        _globalLockoutEndTime = null;
        Navigator.of(context).pop(true);
      } else {
        _globalFailedAttempts++;
        final attempts = _globalFailedAttempts;

        Duration? lockoutDuration;
        if (attempts == 5) {
          lockoutDuration = const Duration(minutes: 1); // Sai 5 lần -> Chờ 1 phút
        } else if (attempts == 6) {
          lockoutDuration = const Duration(minutes: 5); // Sai tiếp -> Chờ 5 phút
        } else if (attempts == 7) {
          lockoutDuration = const Duration(minutes: 30); // Sai tiếp -> Chờ 30 phút
        } else if (attempts >= 8) {
          lockoutDuration = const Duration(hours: 1); // Sai tiếp -> Chờ 1 tiếng+
        }

        if (lockoutDuration != null) {
          _globalLockoutEndTime = DateTime.now().add(lockoutDuration);
          _startCountdownTimer();
        }

        setState(() {
          if (attempts < 5) {
            _errorMessage = 'Mã PIN không chính xác (Còn ${5 - attempts} lần thử)';
          } else {
            _errorMessage = '';
          }
        });
        _shakeController.forward();
      }
    }
  }

  /// Khôi phục PIN bằng Email/Username + Mật khẩu tài khoản.
  /// Đã khóa/vô hiệu hóa luồng gửi mã OTP qua Email.
  Future<void> _showForgotPasswordDialog() async {
    final emailOrUsernameController = TextEditingController();
    final passwordController = TextEditingController();
    final theme = Theme.of(context);

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isLoading = false;
        bool obscurePassword = true;
        String? error;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Xác minh tài khoản', textAlign: TextAlign.center),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.lock_shield, size: 44, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Nhập Email/Tên đăng nhập và Mật khẩu tài khoản để đặt lại mã PIN.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: emailOrUsernameController,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email hoặc Tên đăng nhập',
                          hintText: 'Nhập email hoặc username',
                          prefixIcon: Icon(CupertinoIcons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu tài khoản',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(CupertinoIcons.lock),
                          suffixIcon: IconButton(
                            tooltip: obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                            onPressed: () => setStateDialog(() => obscurePassword = !obscurePassword),
                            icon: Icon(obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash),
                          ),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Huỷ'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final input = emailOrUsernameController.text.trim();
                          final password = passwordController.text;
                          if (input.isEmpty || password.isEmpty) {
                            setStateDialog(() => error = 'Vui lòng nhập Email/Tên đăng nhập và Mật khẩu.');
                            return;
                          }
                          setStateDialog(() {
                            isLoading = true;
                            error = null;
                          });
                          try {
                            final authRepo = ref.read(authRepositoryProvider);
                            final response = await authRepo.signIn(
                              emailOrUsername: input,
                              password: password,
                            );

                            final currentUser = Supabase.instance.client.auth.currentUser;
                            if (response.user == null || response.user!.id != currentUser?.id) {
                              throw const AuthException('Tài khoản xác minh không trùng khớp với tài khoản hiện tại.');
                            }

                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            if (!ctx.mounted) return;
                            setStateDialog(() {
                              isLoading = false;
                              error = e is AuthException
                                  ? e.message
                                  : 'Email/Tên đăng nhập hoặc mật khẩu không chính xác.';
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Xác minh'),
                ),
              ],
            );
          },
        );
      },
    );

    emailOrUsernameController.dispose();
    passwordController.dispose();

    if (verified == true && mounted) {
      await ref.read(hiddenChatProvider.notifier).removePasscode();
      _globalFailedAttempts = 0;
      _globalLockoutEndTime = null;
      _countdownTimer?.cancel();

      setState(() {
        _currentMode = PasscodeMode.setup;
        _passcode = '';
        _errorMessage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xác thực thành công. Vui lòng thiết lập mã PIN mới.')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _getLockoutMessage() {
    if (!_isLockedOut) return _errorMessage;
    final formatted = _formatDuration(_remainingLockout);
    final attempts = _globalFailedAttempts;
    if (attempts == 5) {
      return 'Nhập sai 5 lần. Vui lòng thử lại sau $formatted';
    } else if (attempts == 6) {
      return 'Nhập sai tiếp. Vui lòng thử lại sau $formatted';
    } else if (attempts == 7) {
      return 'Nhập sai tiếp. Vui lòng thử lại sau $formatted';
    } else {
      return 'Thử quá nhiều lần. Vui lòng thử lại sau $formatted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String displayTitle = widget.title ?? '';
    if (displayTitle.isEmpty) {
      if (_currentMode == PasscodeMode.setup) {
        displayTitle = 'Thiết lập mã PIN';
      } else {
        displayTitle = 'Nhập mã PIN';
      }
    }

    final textColor = isDark ? Colors.white : Colors.black87;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: CupertinoButton(
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Huỷ',
                style: TextStyle(
                  fontSize: 17,
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Main Layout
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Icon
                Icon(
                  _currentMode == PasscodeMode.setup
                      ? CupertinoIcons.lock_shield
                      : CupertinoIcons.lock,
                  size: 40,
                  color: textColor,
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  displayTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentMode == PasscodeMode.setup
                      ? 'Mã PIN này sẽ bảo vệ trò chuyện của bạn.'
                      : 'Vui lòng xác thực để mở khoá.',
                  style: TextStyle(
                    color: theme.hintColor,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Dots Container
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final isFilled = index < _passcode.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled ? primaryColor : Colors.transparent,
                              border: isFilled
                                  ? null
                                  : Border.all(
                                      color: isDark ? Colors.white54 : Colors.black54,
                                      width: 1.5,
                                    ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Error Text & Forgot Passcode
                SizedBox(
                  height: 72,
                  child: Column(
                    children: [
                      if (_isLockedOut || _errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _getLockoutMessage(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (_currentMode == PasscodeMode.verify) ...[
                        const SizedBox(height: 4),
                        CupertinoButton(
                          onPressed: _showForgotPasswordDialog,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          child: Text(
                            'Quên mã PIN?',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // iOS Style Numpad
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _PasscodeNumKey(number: '1', letters: '', isDark: isDark, onTap: () => _onKeyPress('1')),
                          _PasscodeNumKey(number: '2', letters: 'A B C', isDark: isDark, onTap: () => _onKeyPress('2')),
                          _PasscodeNumKey(number: '3', letters: 'D E F', isDark: isDark, onTap: () => _onKeyPress('3')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _PasscodeNumKey(number: '4', letters: 'G H I', isDark: isDark, onTap: () => _onKeyPress('4')),
                          _PasscodeNumKey(number: '5', letters: 'J K L', isDark: isDark, onTap: () => _onKeyPress('5')),
                          _PasscodeNumKey(number: '6', letters: 'M N O', isDark: isDark, onTap: () => _onKeyPress('6')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _PasscodeNumKey(number: '7', letters: 'P Q R S', isDark: isDark, onTap: () => _onKeyPress('7')),
                          _PasscodeNumKey(number: '8', letters: 'T U V', isDark: isDark, onTap: () => _onKeyPress('8')),
                          _PasscodeNumKey(number: '9', letters: 'W X Y Z', isDark: isDark, onTap: () => _onKeyPress('9')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Fake empty key to balance the row
                          const SizedBox(width: 76, height: 76),
                          _PasscodeNumKey(number: '0', letters: '', isDark: isDark, onTap: () => _onKeyPress('0')),
                          _PasscodeDeleteKey(isDark: isDark, onTap: _onDelete),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasscodeNumKey extends StatefulWidget {
  final String number;
  final String letters;
  final bool isDark;
  final VoidCallback onTap;

  const _PasscodeNumKey({
    required this.number,
    required this.letters,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PasscodeNumKey> createState() => _PasscodeNumKeyState();
}

class _PasscodeNumKeyState extends State<_PasscodeNumKey> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _squashAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.90, // Y-axis shrinks to 90%
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _squashAnimation = Tween<double>(
      begin: 1.0,
      end: 0.94, // X-axis shrinks to 94% (creates liquid squash effect)
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final normalBgColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    final pressedBgColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.24)
        : Colors.black.withValues(alpha: 0.12);

    _colorAnimation = ColorTween(
      begin: normalBgColor,
      end: pressedBgColor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    _playRebound();
    widget.onTap();
  }

  void _handleTapCancel() {
    _playRebound();
  }

  void _playRebound() {
    // Spring physics rebound for fluid elastic iOS feel
    final spring = SpringDescription(
      mass: 1.0,
      stiffness: 450,
      damping: 18,
    );
    final simulation = SpringSimulation(
      spring,
      _controller.value,
      0.0, // target is normal size
      _controller.velocity,
    );
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final subTextColor = widget.isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(_squashAnimation.value, _scaleAnimation.value, 1.0),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _colorAnimation.value,
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.75,
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.number,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w400,
                color: textColor,
                height: 1.1,
              ),
            ),
            if (widget.letters.isNotEmpty)
              Text(
                widget.letters,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: subTextColor,
                  letterSpacing: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PasscodeDeleteKey extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _PasscodeDeleteKey({
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PasscodeDeleteKey> createState() => _PasscodeDeleteKeyState();
}

class _PasscodeDeleteKeyState extends State<_PasscodeDeleteKey> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.4,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    _playRebound();
    widget.onTap();
  }

  void _handleTapCancel() {
    _playRebound();
  }

  void _playRebound() {
    final spring = SpringDescription(
      mass: 1.0,
      stiffness: 450,
      damping: 18,
    );
    final simulation = SpringSimulation(
      spring,
      _controller.value,
      0.0,
      _controller.velocity,
    );
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: child,
            ),
          );
        },
        child: Container(
          width: 76,
          height: 76,
          color: Colors.transparent, // to make the whole 76x76 clickable
          child: Center(
            child: Text(
              'Xoá',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
