import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String _passcode = '';
  String _errorMessage = '';
  int _failedAttempts = 0;
  late PasscodeMode _currentMode;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String key) {
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
    if (_passcode.isNotEmpty && !_shakeController.isAnimating) {
      setState(() {
        _passcode = _passcode.substring(0, _passcode.length - 1);
        _errorMessage = '';
      });
    }
  }

  Future<void> _onComplete() async {
    final enteredPasscode = _passcode;
    
    if (_currentMode == PasscodeMode.setup) {
      // Set new passcode
      await ref.read(hiddenChatProvider.notifier).setPasscode(enteredPasscode);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      // Verify passcode
      final isValid = await ref.read(hiddenChatProvider.notifier).verifyPasscode(enteredPasscode);
      if (!mounted) return;
      
      if (isValid) {
        Navigator.of(context).pop(true);
      } else {
        _failedAttempts++;
        setState(() {
          _errorMessage = 'Mã PIN không chính xác';
        });
        _shakeController.forward();
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final passwordController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final success = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        String? authError;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return CupertinoAlertDialog(
              title: const Text('Xác thực tài khoản'),
              content: Column(
                children: [
                  const SizedBox(height: 8),
                  const Text('Vui lòng nhập mật khẩu đăng nhập Mini Social để đặt lại mã PIN.'),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: passwordController,
                    obscureText: true,
                    placeholder: 'Mật khẩu tài khoản',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  if (authError != null) ...[
                    const SizedBox(height: 8),
                    Text(authError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                  ]
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Huỷ'),
                  onPressed: () {
                    if (!isLoading) Navigator.pop(ctx, false);
                  },
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: isLoading ? null : () async {
                    if (passwordController.text.isEmpty) return;
                    
                    setStateDialog(() {
                      isLoading = true;
                      authError = null;
                    });
                    
                    try {
                      final email = Supabase.instance.client.auth.currentUser?.email;
                      if (email == null) throw Exception('Không tìm thấy Email');
                      
                      await Supabase.instance.client.auth.signInWithPassword(
                        email: email,
                        password: passwordController.text,
                      );
                      
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setStateDialog(() {
                        isLoading = false;
                        authError = 'Mật khẩu không đúng. Vui lòng thử lại.';
                      });
                    }
                  },
                  child: isLoading 
                      ? const CupertinoActivityIndicator() 
                      : const Text('Xác nhận'),
                ),
              ],
            );
          }
        );
      }
    );

    passwordController.dispose();

    if (success == true && mounted) {
      // Xoá mã PIN cũ
      await ref.read(hiddenChatProvider.notifier).removePasscode();
      // Chuyển sang màn hình setup
      setState(() {
        _currentMode = PasscodeMode.setup;
        _passcode = '';
        _errorMessage = '';
        _failedAttempts = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xoá mã PIN. Vui lòng thiết lập mã PIN mới.')),
        );
      }
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
                    ? Colors.black.withValues(alpha: 0.6) 
                    : Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
          
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
                  height: 64, // Đủ chiều cao cho cả 2
                  child: Column(
                    children: [
                      if (_errorMessage.isNotEmpty)
                        Text(
                          _errorMessage,
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                        ),
                      if (_failedAttempts >= 3 && _currentMode == PasscodeMode.verify)
                        GestureDetector(
                          onTap: _showForgotPasswordDialog,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Quên mã PIN?',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
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
                          _buildNumKey('1', '', isDark),
                          _buildNumKey('2', 'A B C', isDark),
                          _buildNumKey('3', 'D E F', isDark),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumKey('4', 'G H I', isDark),
                          _buildNumKey('5', 'J K L', isDark),
                          _buildNumKey('6', 'M N O', isDark),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumKey('7', 'P Q R S', isDark),
                          _buildNumKey('8', 'T U V', isDark),
                          _buildNumKey('9', 'W X Y Z', isDark),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Fake empty key to balance the row
                          const SizedBox(width: 76, height: 76),
                          _buildNumKey('0', '', isDark),
                          _buildDeleteKey(isDark),
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

  Widget _buildNumKey(String number, String letters, bool isDark) {
    return GestureDetector(
      onTap: () => _onKeyPress(number),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.1,
              ),
            ),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                  letterSpacing: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteKey(bool isDark) {
    return GestureDetector(
      onTap: _onDelete,
      child: Container(
        width: 76,
        height: 76,
        color: Colors.transparent, // to make the whole 76x76 clickable
        child: Center(
          child: Text(
            'Xoá',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
