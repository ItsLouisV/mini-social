import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/logger_service.dart';
import '../../../../core/services/toast_service.dart';
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
// Premium Social Login Card
// ─────────────────────────────────────────────────────────────────────────────

class _SocialLoginCard extends StatefulWidget {
  final FaIconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onPressed;
  final bool isLight;

  const _SocialLoginCard({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.onPressed,
    this.isLight = false,
  });

  @override
  State<_SocialLoginCard> createState() => _SocialLoginCardState();
}

class _SocialLoginCardState extends State<_SocialLoginCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isHovered = true);
        _pressCtrl.forward();
      },
      onTapUp: (_) {
        setState(() => _isHovered = false);
        _pressCtrl.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () {
        setState(() => _isHovered = false);
        _pressCtrl.reverse();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: widget.isLight
                ? (_isHovered
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.92))
                : (_isHovered
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isLight
                  ? Colors.white
                  : Colors.white.withValues(alpha: _isHovered ? 0.35 : 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                widget.icon,
                size: 18,
                color: widget.isLight ? widget.iconColor : Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isLight
                      ? const Color(0xFF0F172A)
                      : Colors.white.withValues(alpha: 0.95),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Login Screen
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailKey = GlobalKey<_ModernGlassInputState>();
  final _passwordKey = GlobalKey<_ModernGlassInputState>();
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    final emailError = _emailKey.currentState?.runValidation();
    final passwordError = _passwordKey.currentState?.runValidation();
    return emailError == null && passwordError == null;
  }

  Future<void> _login() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            emailOrUsername: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } catch (e, stack) {
      CoreLogger.error('Lỗi đăng nhập: $e', stackTrace: stack, tag: 'Auth');
      if (mounted) ToastService.showError(context, _parseError(e.toString()), title: 'Đăng nhập thất bại');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e, stack) {
      CoreLogger.error('Google login error: $e', stackTrace: stack, tag: 'Auth');
      if (mounted) ToastService.showError(context, 'Đăng nhập bằng Google thất bại');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
    } catch (e, stack) {
      CoreLogger.error('Apple login error: $e', stackTrace: stack, tag: 'Auth');
      if (mounted) ToastService.showError(context, 'Đăng nhập bằng Apple thất bại');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Email/Username hoặc mật khẩu không đúng!';
    } else if (error.contains('Email not confirmed')) {
      return 'Email chưa được xác nhận. Vui lòng kiểm tra hộp thư!';
    } else if (error.contains('Tên người dùng không tồn tại')) {
      return 'Username không tồn tại!';
    }
    return 'Đăng nhập thất bại. Vui lòng thử lại sau!';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;

    return Theme(
      // Authentication has its own dark visual identity and must not follow
      // the light/dark preference used by the signed-in application.
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
                        // ── Logo & Title Header OUTSIDE Glass Card ───────────
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo-viora.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // App Title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFC7D2FE)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds),
                          child: const Text(
                            'Viora',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Chào mừng bạn trở lại! Đăng nhập để tiếp tục',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 22),

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
                                      key: _emailKey,
                                      label: 'Email or Username',
                                      hint: 'Email or Username...',
                                      icon: CupertinoIcons.person_fill,
                                      controller: _emailController,
                                      validator: Validators.emailOrUsername,
                                      keyboardType: TextInputType.emailAddress,
                                    ),

                                    const SizedBox(height: 16),

                                    _ModernGlassInput(
                                      key: _passwordKey,
                                      label: 'Mật khẩu',
                                      hint: '••••••••',
                                      icon: CupertinoIcons.lock_fill,
                                      controller: _passwordController,
                                      validator: Validators.password,
                                      obscure: true,
                                      textInputAction: TextInputAction.done,
                                      onEditingComplete: _login,
                                    ),

                                    const SizedBox(height: 12),

                                    // Forgot password link
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: GestureDetector(
                                        onTap: () => context.push('/forgot-password'),
                                        child: const Text(
                                          'Quên mật khẩu?',
                                          style: TextStyle(
                                            color: Color(0xFFA5B4FC),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    // Main Login Button
                                    _GradientGlowButton(
                                      label: 'Đăng nhập',
                                      onPressed: _isLoading ? null : _login,
                                      isLoading: _isLoading,
                                    ),

                                    const SizedBox(height: 22),

                                    // Divider
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            thickness: 1,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          child: Text(
                                            'hoặc',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.4),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            thickness: 1,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 18),

                                    // Social Buttons Row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SocialLoginCard(
                                            icon: FontAwesomeIcons.google,
                                            label: 'Google',
                                            iconColor: const Color(0xFFEA4335),
                                            isLight: true,
                                            onPressed: _isLoading ? null : _loginWithGoogle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _SocialLoginCard(
                                            icon: FontAwesomeIcons.apple,
                                            label: 'Apple',
                                            iconColor: Colors.white,
                                            isLight: false,
                                            onPressed: _isLoading ? null : _loginWithApple,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 22),

                                    // Register Link
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Chưa có tài khoản? ',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.55),
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => context.push('/register'),
                                          child: const Text(
                                            'Đăng ký ngay',
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
        ],
        ),
      ),
    );
  }
}
