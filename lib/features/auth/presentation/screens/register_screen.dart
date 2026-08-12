import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/logger_service.dart';
import '../../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design System & Palette
// ─────────────────────────────────────────────────────────────────────────────

class _Design {
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6366F1), // Electric Indigo
      Color(0xFF8B5CF6), // Purple Accent
      Color(0xFF06B6D4), // Cyan Glow
    ],
  );

  static const accentGlow = Color(0xFF6366F1);
  static const cardBg = Color(0xFF0F111E);
  static const inputBg = Color(0xFF181A2A);
  static const error = Color(0xFFFF5252);
  static const success = Color(0xFF10B981);
}

// ─────────────────────────────────────────────────────────────────────────────
// Modern Glass Input Field
// ─────────────────────────────────────────────────────────────────────────────

class _ModernGlassInput extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final VoidCallback? onEditingComplete;

  const _ModernGlassInput({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.validator,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onEditingComplete,
  });

  @override
  State<_ModernGlassInput> createState() => _ModernGlassInputState();
}

class _ModernGlassInputState extends State<_ModernGlassInput>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _focusProgress;
  late final FocusNode _focusNode;
  bool _obscureText = true;
  bool _isFocused = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscure;
    _focusNode = FocusNode();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _focusProgress = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  String? runValidation() {
    final result = widget.validator?.call(widget.controller.text);
    setState(() => _errorMessage = result);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorMessage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Field Label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            widget.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),

        // Input Container
        AnimatedBuilder(
          animation: _focusProgress,
          builder: (context, child) {
            final glowColor = hasError
                ? _Design.error
                : Color.lerp(
                    Colors.transparent,
                    _Design.accentGlow,
                    _focusProgress.value,
                  )!;

            final borderColor = hasError
                ? _Design.error.withValues(alpha: 0.8)
                : Color.lerp(
                    Colors.white.withValues(alpha: 0.12),
                    _Design.accentGlow.withValues(alpha: 0.9),
                    _focusProgress.value,
                  )!;

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isFocused || hasError
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: hasError ? 0.3 : 0.25),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      color: _Design.inputBg.withValues(
                        alpha: 0.55 + 0.15 * _focusProgress.value,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                        width: _isFocused || hasError ? 1.6 : 1.2,
                      ),
                    ),
                    child: TextFormField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      obscureText: widget.obscure ? _obscureText : false,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      onEditingComplete: widget.onEditingComplete,
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: const Color(0xFFA5B4FC),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                        ),
                        // Prefix Icon with soft background badge
                        prefixIcon: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _isFocused
                                  ? _Design.accentGlow.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 18,
                              color: _isFocused
                                  ? const Color(0xFFA5B4FC)
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        suffixIcon: widget.obscure
                            ? IconButton(
                                splashRadius: 20,
                                icon: Icon(
                                  _obscureText
                                      ? CupertinoIcons.eye_slash
                                      : CupertinoIcons.eye,
                                  size: 19,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                onPressed: () {
                                  setState(() => _obscureText = !_obscureText);
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        errorStyle: const TextStyle(height: 0, fontSize: 0),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Error message popup
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(left: 6, top: 6),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_circle_fill,
                        size: 13,
                        color: _Design.error,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: _Design.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vibrant Glowing Gradient Primary Button
// ─────────────────────────────────────────────────────────────────────────────

class _GradientGlowButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GradientGlowButton({
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_GradientGlowButton> createState() => _GradientGlowButtonState();
}

class _GradientGlowButtonState extends State<_GradientGlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null && !widget.isLoading;

    return GestureDetector(
      onTapDown: (_) {
        if (!isDisabled) {
          setState(() => _isPressed = true);
          _scaleCtrl.forward();
        }
      },
      onTapUp: (_) {
        if (!isDisabled) {
          setState(() => _isPressed = false);
          _scaleCtrl.reverse();
          widget.onPressed?.call();
        }
      },
      onTapCancel: () {
        if (!isDisabled) {
          setState(() => _isPressed = false);
          _scaleCtrl.reverse();
        }
      },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 56,
          decoration: BoxDecoration(
            gradient: isDisabled
                ? LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  )
                : _Design.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDisabled ? 0.1 : 0.35),
              width: 1.2,
            ),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: _Design.accentGlow.withValues(
                        alpha: _isPressed ? 0.25 : 0.45,
                      ),
                      blurRadius: _isPressed ? 14 : 26,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        CupertinoIcons.arrow_right,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Register Screen
// ─────────────────────────────────────────────────────────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _nameKey = GlobalKey<_ModernGlassInputState>();
  final _emailKey = GlobalKey<_ModernGlassInputState>();
  final _passwordKey = GlobalKey<_ModernGlassInputState>();
  final _confirmKey = GlobalKey<_ModernGlassInputState>();

  bool _isLoading = false;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    ));

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    final nameError = _nameKey.currentState?.runValidation();
    final emailError = _emailKey.currentState?.runValidation();
    final passwordError = _passwordKey.currentState?.runValidation();
    final confirmError = _confirmKey.currentState?.runValidation();

    return nameError == null &&
        emailError == null &&
        passwordError == null &&
        confirmError == null;
  }

  Future<void> _register() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          );

      // Sign out để user đăng nhập lại bằng thông tin mới
      await ref.read(authRepositoryProvider).signOut();

      if (mounted) {
        _showToast('Đăng ký thành công! Hãy đăng nhập để tiếp tục.', isError: false);
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        _showToast(_parseError(e.toString()), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? CupertinoIcons.exclamationmark_triangle_fill
                  : CupertinoIcons.checkmark_alt_circle_fill,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFF1E1B2E) : _Design.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError
                ? _Design.error.withValues(alpha: 0.5)
                : _Design.success,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        elevation: 8,
      ),
    );
  }

  String _parseError(String error) {
    CoreLogger.error('Lỗi khi đăng ký: $error', tag: 'Auth');

    if (error.contains('already registered') ||
        error.contains('User already registered')) {
      return 'Email này đã được sử dụng. Vui lòng chọn email khác!';
    }

    return 'Đăng ký thất bại. Vui lòng thử lại!';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;

    return Theme(
      // Keep auth screens consistently dark regardless of the app theme.
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _Design.accentGlow,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF090A10),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF090A10),
        resizeToAvoidBottomInset: true,
        body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Fullscreen Wallpaper ─────────────────────────────────────
          Image.asset(
            'assets/images/bg2.jpg',
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
          ),

          // ── 2. Atmospheric Ambient Overlay ───────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.4),
                radius: 1.2,
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.25),
                  const Color(0xFF090A14).withValues(alpha: 0.75),
                  const Color(0xFF05050A).withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),

          // Ambient glowing orb top-right
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                    blurRadius: 90,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          // Ambient glowing orb bottom-left
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                    blurRadius: 80,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Main Centered Glass Card Content ──────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),

                        // Section Header
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFC7D2FE)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds),
                          child: const Text(
                            'Tạo tài khoản',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Tham gia cộng đồng Viora ngay hôm nay',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Glass Form Sheet (Sát mép màn hình) ──────────────
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                                decoration: BoxDecoration(
                                  color: _Design.cardBg.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      blurRadius: 40,
                                      spreadRadius: 4,
                                      offset: const Offset(0, 16),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                      blurRadius: 30,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ── Form Fields ─────────────────────────────
                                    _ModernGlassInput(
                                      key: _nameKey,
                                      label: 'Họ và tên',
                                      hint: 'Nguyễn Văn A',
                                      icon: CupertinoIcons.person_fill,
                                      controller: _nameController,
                                      validator: Validators.fullName,
                                    ),

                                    const SizedBox(height: 16),

                                    _ModernGlassInput(
                                      key: _emailKey,
                                      label: 'Email',
                                      hint: 'example@email.com',
                                      icon: CupertinoIcons.mail_solid,
                                      controller: _emailController,
                                      validator: Validators.email,
                                      keyboardType: TextInputType.emailAddress,
                                    ),

                                    const SizedBox(height: 16),

                                    _ModernGlassInput(
                                      key: _passwordKey,
                                      label: 'Mật khẩu',
                                      hint: 'Ít nhất 6 ký tự',
                                      icon: CupertinoIcons.lock_fill,
                                      controller: _passwordController,
                                      validator: Validators.password,
                                      obscure: true,
                                    ),

                                    const SizedBox(height: 16),

                                    _ModernGlassInput(
                                      key: _confirmKey,
                                      label: 'Xác nhận mật khẩu',
                                      hint: '••••••••',
                                      icon: CupertinoIcons.shield_fill,
                                      controller: _confirmController,
                                      validator: (v) => Validators.confirmPassword(
                                        v,
                                        _passwordController.text,
                                      ),
                                      obscure: true,
                                      textInputAction: TextInputAction.done,
                                      onEditingComplete: _register,
                                    ),

                                    const SizedBox(height: 26),

                                    // Main Register Button
                                    _GradientGlowButton(
                                      label: 'Tạo tài khoản',
                                      onPressed: _isLoading ? null : _register,
                                      isLoading: _isLoading,
                                    ),

                                    const SizedBox(height: 22),

                                    // Navigation to Login
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Đã có tài khoản? ',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.55),
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            if (context.canPop()) {
                                              context.pop();
                                            } else {
                                              context.go('/login');
                                            }
                                          },
                                          child: const Text(
                                            'Đăng nhập ngay',
                                            style: TextStyle(
                                              color: Color(0xFFA5B4FC),
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 4. Fixed Top-Left Back Button (Always on Top of Stack) ───────
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 12),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          CupertinoIcons.chevron_back,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/login');
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
