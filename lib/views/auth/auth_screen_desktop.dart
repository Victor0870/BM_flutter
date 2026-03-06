import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/locale_provider.dart';
import '../../l10n/app_localizations.dart';

/// Màn hình đăng nhập/đăng ký cho Desktop (Windows/Mac/Linux/Web).
class AuthScreenDesktop extends StatefulWidget {
  const AuthScreenDesktop({super.key});

  @override
  State<AuthScreenDesktop> createState() => _AuthScreenDesktopState();
}

class _AuthScreenDesktopState extends State<AuthScreenDesktop> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _shopIdController = TextEditingController();

  bool _isLogin = true;
  bool _isOwner = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shopIdController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedCredentials() async {
    if (!mounted) return;
    try {
      final authProvider = context.read<AuthProvider>();
      final rememberedEmail = await authProvider.getRememberedEmail();
      if (rememberedEmail != null && rememberedEmail.isNotEmpty && mounted) {
        setState(() {
          _emailController.text = rememberedEmail;
          _rememberMe = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isFirebaseReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.firebaseNotReady),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_isLogin) {
      final success = await authProvider.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        rememberMe: _rememberMe,
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.loginSuccess),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? AppLocalizations.of(context)!.loginFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (_passwordController.text != _confirmPasswordController.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.passwordMismatch),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      bool success = false;
      if (_isOwner) {
        success = await authProvider.signUpOwnerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        if (_shopIdController.text.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.pleaseEnterShopIdDesktop),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        success = await authProvider.signUpStaffWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
          shopId: _shopIdController.text.trim(),
        );
      }
      if (mounted) {
        if (success) {
          final message = _isOwner
              ? AppLocalizations.of(context)!.registerSuccess
              : (authProvider.errorMessage ??
                  AppLocalizations.of(context)!.registerSuccessStaff);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? AppLocalizations.of(context)!.registerFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();
    final authProvider = context.read<AuthProvider>();
    bool loading = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Quên mật khẩu'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Nhập email đăng ký tài khoản. Chúng tôi sẽ gửi link đặt lại mật khẩu.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                        if (!v.contains('@')) return 'Email không hợp lệ';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => loading = true);
                        final success = await authProvider.sendPasswordResetEmail(emailController.text.trim());
                        if (!context.mounted) return;
                        setDialogState(() => loading = false);
                        if (success) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã gửi email đặt lại mật khẩu. Vui lòng kiểm tra hộp thư.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(authProvider.errorMessage ?? 'Gửi email thất bại'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Gửi link'),
              ),
            ],
          );
        },
      ),
    );
    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 450,
              constraints: const BoxConstraints(maxWidth: 450),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.store,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.appTitle,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? AppLocalizations.of(context)!.loginToAccount
                          : (_isOwner
                              ? AppLocalizations.of(context)!.registerOwner
                              : AppLocalizations.of(context)!.registerStaff),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (!_isLogin) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: Text(AppLocalizations.of(context)!.ownerChip),
                            selected: _isOwner,
                            onSelected: (_) => setState(() => _isOwner = true),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(AppLocalizations.of(context)!.staffChip),
                            selected: !_isOwner,
                            onSelected: (_) => setState(() => _isOwner = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.email,
                        hintText: AppLocalizations.of(context)!.emailHint,
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.pleaseEnterEmail;
                        if (!v.contains('@')) return AppLocalizations.of(context)!.invalidEmail;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!_isLogin && !_isOwner) ...[
                      TextFormField(
                        controller: _shopIdController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.shopId,
                          hintText: AppLocalizations.of(context)!.shopIdHintDesktop,
                          prefixIcon: const Icon(Icons.store),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.password,
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.pleaseEnterPassword;
                        if (!_isLogin && v.length < 6) return AppLocalizations.of(context)!.passwordMinLength;
                        return null;
                      },
                      onFieldSubmitted: (_) => _isLogin ? _handleSubmit() : null,
                    ),
                    const SizedBox(height: 16),
                    if (_isLogin) ...[
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v ?? false),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _rememberMe = !_rememberMe),
                              child: Text(
                                AppLocalizations.of(context)!.rememberAccount,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showForgotPasswordDialog(context),
                          child: const Text('Quên mật khẩu?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.confirmPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.pleaseConfirmPassword;
                          if (v != _passwordController.text) return AppLocalizations.of(context)!.passwordMismatch;
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) => ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _isLogin ? AppLocalizations.of(context)!.login : AppLocalizations.of(context)!.register,
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _passwordController.clear();
                          _confirmPasswordController.clear();
                          _shopIdController.clear();
                          if (!_isLogin) _isOwner = true;
                        });
                      },
                      child: Text(
                        _isLogin
                            ? AppLocalizations.of(context)!.noAccountRegister
                            : AppLocalizations.of(context)!.haveAccountLogin,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '🌐',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => context.read<LocaleProvider>().setLocale(const Locale('vi')),
                          child: Text('Tiếng Việt'),
                        ),
                        TextButton(
                          onPressed: () => context.read<LocaleProvider>().setLocale(const Locale('en')),
                          child: const Text('English'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
