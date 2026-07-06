import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/document_detail_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),
      ],
      child: Consumer<ApiService>(
        builder: (context, apiService, _) {
          return MaterialApp(
            title: 'AnnotateHub',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0F0F1A),
              colorScheme: const ColorScheme.dark(
                primary: Colors.deepPurpleAccent,
                secondary: Colors.purpleAccent,
                surface: Color(0xFF16162A),
                error: Colors.redAccent,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF16162A),
                elevation: 0,
              ),
              cardTheme: CardThemeData(
                color: const Color(0xFF16162A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF2C2C4E)),
                ),
              ),
            ),
            initialRoute: '/',
            onGenerateRoute: onGenerateRoute,
          );
        },
      ),
    );
  }
}

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';
  final uri = Uri.parse(name);

  if (uri.path == '/login') {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const LoginScreen(),
    );
  }

  if (uri.path == '/signup') {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const SignUpScreen(),
    );
  }

  if (uri.path == '/dashboard') {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const DashboardScreen(),
    );
  }

  if (uri.path == '/document') {
    final documentId = uri.queryParameters['id'] ?? (settings.arguments as String?);
    if (documentId != null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => DocumentDetailScreen(documentId: documentId),
      );
    }
  }

  // Default initial auth check launcher
  return MaterialPageRoute(
    settings: settings,
    builder: (_) => const InitialAuthCheck(),
  );
}

class InitialAuthCheck extends StatelessWidget {
  const InitialAuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    return FutureBuilder<bool>(
      future: _checkAuthStatus(apiService),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
            ),
          );
        }
        
        final isLoggedIn = snapshot.data == true;
        if (isLoggedIn) {
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }

  Future<bool> _checkAuthStatus(ApiService apiService) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return apiService.token != null && apiService.currentUser != null;
  }
}
