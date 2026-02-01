import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';

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
          const SnackBar(
            content: Text('Firebase chưa sẵn sàng. Vui lòng thử lại sau.'),
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
            const SnackBar(
              content: Text('Đăng nhập thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Đăng nhập thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (_passwordController.text != _confirmPasswordController.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mật khẩu xác nhận không khớp'),
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
              const SnackBar(
                content: Text('Vui lòng nhập Shop ID của cửa hàng'),
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
              ? 'Đăng ký thành công! Đang tạo cửa hàng...'
              : (authProvider.errorMessage ??
                  'Đăng ký thành công, vui lòng đợi Admin phê duyệt.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Đăng ký thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
                      'BizMate POS',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? 'Đăng nhập vào tài khoản'
                          : (_isOwner
                              ? 'Đăng ký Chủ cửa hàng'
                              : 'Đăng ký Nhân viên'),
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
                            label: const Text('Chủ shop'),
                            selected: _isOwner,
                            onSelected: (_) => setState(() => _isOwner = true),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Nhân viên'),
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
                        labelText: 'Email',
                        hintText: 'example@email.com',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                        if (!v.contains('@')) return 'Email không hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!_isLogin && !_isOwner) ...[
                      TextFormField(
                        controller: _shopIdController,
                        decoration: InputDecoration(
                          labelText: 'Shop ID',
                          hintText: 'Nhập Shop ID cửa hàng',
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
                        labelText: 'Mật khẩu',
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
                        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mật khẩu';
                        if (!_isLogin && v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
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
                                'Ghi nhớ tài khoản',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu',
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
                          if (v == null || v.trim().isEmpty) return 'Vui lòng xác nhận mật khẩu';
                          if (v != _passwordController.text) return 'Mật khẩu xác nhận không khớp';
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
                                _isLogin ? 'Đăng nhập' : 'Đăng ký',
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
                            ? 'Chưa có tài khoản? Đăng ký ngay'
                            : 'Đã có tài khoản? Đăng nhập',
                      ),
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
