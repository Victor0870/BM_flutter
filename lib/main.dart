import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'firebase_options.dart';
import 'controllers/auth_provider.dart';
import 'controllers/product_provider.dart';
import 'controllers/sales_provider.dart';
import 'controllers/sales_return_provider.dart';
import 'controllers/purchase_provider.dart';
import 'controllers/branch_provider.dart';
import 'controllers/customer_provider.dart';
import 'core/routes.dart';
import 'core/route_observer.dart';
import 'views/main_scaffold.dart';
import 'views/auth/auth_screen.dart';
import 'views/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo sqflite_common_ffi cho desktop platforms (Windows, Linux, macOS)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory - QUAN TRỌNG: Phải set databaseFactory global
    databaseFactory = databaseFactoryFfi;
    if (kDebugMode) {
      debugPrint('✅ SQLite FFI initialized for desktop platform');
    }
  }
  
  try {
    // Khởi tạo Firebase với cấu hình từ firebase_options.dart
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
    // Có thể hiển thị lỗi cho người dùng hoặc fallback
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ProductProvider>(
          create: (context) => ProductProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, authProvider, previous) => ProductProvider(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, BranchProvider>(
          create: (context) => BranchProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, authProvider, previous) => BranchProvider(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SalesProvider>(
          create: (context) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            // Trong create, ProductProvider và BranchProvider đã sẵn sàng vì được khởi tạo trước
            final productProvider = Provider.of<ProductProvider>(context, listen: false);
            final branchProvider = Provider.of<BranchProvider>(context, listen: false);
            return SalesProvider(
              authProvider,
              branchProvider: branchProvider,
              productProvider: productProvider,
            );
          },
          update: (context, authProvider, previous) {
            // Trong update, tất cả providers đã sẵn sàng
            final productProvider = Provider.of<ProductProvider>(context, listen: false);
            final branchProvider = Provider.of<BranchProvider>(context, listen: false);
            return SalesProvider(
              authProvider,
              branchProvider: branchProvider,
              productProvider: productProvider,
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, PurchaseProvider>(
          create: (context) => PurchaseProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, authProvider, previous) => PurchaseProvider(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CustomerProvider>(
          create: (context) => CustomerProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, authProvider, previous) => CustomerProvider(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SalesReturnProvider>(
          create: (context) => SalesReturnProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, authProvider, previous) => SalesReturnProvider(authProvider),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BizMate POS',
        navigatorObservers: [routeObserver],
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // Hiển thị SplashScreen khi đang khởi tạo hệ thống
            if (authProvider.isInitializing) {
              return const SplashScreen();
            }

            // Sau khi khởi tạo hoàn tất, kiểm tra trạng thái đăng nhập
            if (authProvider.isAuthenticated) {
              // Đảm bảo Firebase đã sẵn sàng
              if (!authProvider.isFirebaseReady) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Đang khởi tạo Firebase...'),
                      ],
                    ),
                  ),
                );
              }

              // Hiển thị MainScaffold khi đã đăng nhập
              return const MainScaffold();
            }

            // Hiển thị AuthScreen khi chưa đăng nhập
            return const AuthScreen();
          },
        ),
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Các controller để lấy dữ liệu từ ô nhập liệu
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 600;

    return Scaffold(
      body: Center(
        child: Container(
          width: isDesktop ? 450 : size.width * 0.9, // PC thì thu gọn, Mobile thì tràn lề
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isDesktop ? [const BoxShadow(color: Colors.black12, blurRadius: 10)] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                "FPT eInvoice Login", // Tên hệ thống theo tài liệu [cite: 1, 6]
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              // Ô nhập Mã số thuế (Username) 
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Mã số thuế / Username",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Ô nhập Mật khẩu 
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Mật khẩu",
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              // Nút Đăng nhập
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Sau này sẽ gọi hàm đăng nhập API c_signin tại đây [cite: 108]
                    debugPrint("Username: ${_usernameController.text}");
                  },
                  child: const Text("ĐĂNG NHẬP"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}