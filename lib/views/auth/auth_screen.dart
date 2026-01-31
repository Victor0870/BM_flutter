import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../controllers/auth_provider.dart';
import '../../widgets/responsive_container.dart';

/// Màn hình đăng nhập và đăng ký
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _shopIdController = TextEditingController();
  
  bool _isLogin = true;
  bool _isOwner = true; // true: Chủ shop, false: Nhân viên
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false; // Checkbox "Ghi nhớ mật khẩu"
  bool _isScanning = false;

  /// Chỉ trên Mobile (Android/iOS) mới lưu/điền mật khẩu
  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    // Tự động điền email (và mật khẩu trên Mobile) đã lưu khi mở màn hình
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

  /// Tải email (và mật khẩu trên Mobile) đã ghi nhớ từ SharedPreferences
  Future<void> _loadRememberedCredentials() async {
    if (!mounted) return;
    try {
      final authProvider = context.read<AuthProvider>();
      final rememberedEmail = await authProvider.getRememberedEmail();
      if (rememberedEmail != null && rememberedEmail.isNotEmpty) {
        if (_isMobile) {
          final rememberedPassword = await authProvider.getRememberedPassword();
          if (mounted) {
            setState(() {
              _emailController.text = rememberedEmail;
              if (rememberedPassword != null && rememberedPassword.isNotEmpty) {
                _passwordController.text = rememberedPassword;
              }
              _rememberMe = true;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _emailController.text = rememberedEmail;
              _rememberMe = true;
            });
          }
        }
      }
    } catch (e) {
      // Bỏ qua lỗi khi load
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    // Kiểm tra Firebase đã sẵn sàng
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
      // Đăng nhập (áp dụng cho cả Chủ shop và Nhân viên)
      final success = await authProvider.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        rememberMe: _rememberMe, // Truyền giá trị checkbox
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
              content: Text(
                authProvider.errorMessage ?? 'Đăng nhập thất bại',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Đăng ký
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
        // Đăng ký Chủ shop
        success = await authProvider.signUpOwnerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        // Đăng ký Nhân viên -> yêu cầu Shop ID
        if (_shopIdController.text.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vui lòng nhập hoặc quét Shop ID của cửa hàng'),
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
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                authProvider.errorMessage ?? 'Đăng ký thất bại',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Mở camera quét QR để lấy Shop ID
  Future<void> _scanShopQr() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quét mã QR cửa hàng'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: MobileScanner(
              onDetect: (capture) {
                final barcode = capture.barcodes.first;
                final rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _shopIdController.text = rawValue;
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final useWideLayout = !isMobile(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: useWideLayout ? 450 : double.infinity,
              constraints: const BoxConstraints(maxWidth: 450),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
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

                    // Toggle Chủ shop / Nhân viên (chỉ hiện khi đăng ký)
                    if (!_isLogin) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Chủ shop'),
                            selected: _isOwner,
                            onSelected: (selected) {
                              setState(() {
                                _isOwner = true;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Nhân viên'),
                            selected: !_isOwner,
                            onSelected: (selected) {
                              setState(() {
                                _isOwner = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập email';
                        }
                        if (!value.contains('@')) {
                          return 'Email không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Shop ID (chỉ cho đăng ký Nhân viên)
                    if (!_isLogin && !_isOwner) ...[
                      TextFormField(
                        controller: _shopIdController,
                        decoration: InputDecoration(
                          labelText: 'Shop ID',
                          hintText: 'Nhập hoặc quét Shop ID',
                          prefixIcon: const Icon(Icons.store),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: 'Quét mã QR cửa hàng',
                            onPressed: _scanShopQr,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Mật khẩu
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: _isLogin
                          ? TextInputAction.done
                          : TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        if (!_isLogin && value.length < 6) {
                          return 'Mật khẩu phải có ít nhất 6 ký tự';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _isLogin ? _handleSubmit() : null,
                    ),
                    const SizedBox(height: 16),

                    // Checkbox "Ghi nhớ mật khẩu" (chỉ hiện khi đăng nhập)
                    if (_isLogin) ...[
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _rememberMe = !_rememberMe;
                                });
                              },
                              child: Text(
                                _isMobile
                                    ? 'Ghi nhớ mật khẩu'
                                    : 'Ghi nhớ tài khoản',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Xác nhận mật khẩu (chỉ hiện khi đăng ký)
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
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng xác nhận mật khẩu';
                          }
                          if (value != _passwordController.text) {
                            return 'Mật khẩu xác nhận không khớp';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Nút đăng nhập/đăng ký
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        return ElevatedButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : _handleSubmit,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Đăng nhập' : 'Đăng ký',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Chuyển đổi giữa đăng nhập và đăng ký
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _passwordController.clear();
                          _confirmPasswordController.clear();
                          _shopIdController.clear();
                          // Reset về Chủ shop khi chuyển sang đăng ký
                          if (!_isLogin) {
                            _isOwner = true;
                          }
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

