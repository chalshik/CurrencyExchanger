import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/currency_exchanger.dart';
import 'screens/superadmin_screen.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'db_helper.dart';
import 'screens/app_exit_handler.dart';

// Custom theme extension for additional text styling
class TextStyleExtension extends ThemeExtension<TextStyleExtension> {
  final TextStyle? regularText;
  final TextStyle? boldText;
  final TextStyle? subtitleText;

  TextStyleExtension({this.regularText, this.boldText, this.subtitleText});

  @override
  TextStyleExtension copyWith({
    TextStyle? regularText,
    TextStyle? boldText,
    TextStyle? subtitleText,
  }) {
    return TextStyleExtension(
      regularText: regularText ?? this.regularText,
      boldText: boldText ?? this.boldText,
      subtitleText: subtitleText ?? this.subtitleText,
    );
  }

  @override
  TextStyleExtension lerp(ThemeExtension<TextStyleExtension>? other, double t) {
    if (other is! TextStyleExtension) {
      return this;
    }
    return TextStyleExtension(
      regularText: TextStyle.lerp(regularText, other.regularText, t),
      boldText: TextStyle.lerp(boldText, other.boldText, t),
      subtitleText: TextStyle.lerp(subtitleText, other.subtitleText, t),
    );
  }
}

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Force portrait mode for all devices
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTranslations();
    });
  }

  _initializeTranslations() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    languageProvider.initializeTranslations();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Currency Converter',
      debugShowCheckedModeBanner: false,
      locale: languageProvider.currentLocale,
      supportedLocales: const [
        Locale('ky'), // Kyrgyz
        Locale('ru'), // Russian
        Locale('en'), // English
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: themeProvider.lightTheme.copyWith(
        extensions: <ThemeExtension<dynamic>>[
          TextStyleExtension(
            regularText: const TextStyle(color: Colors.black, fontSize: 16),
            boldText: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            subtitleText: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
      darkTheme: themeProvider.darkTheme.copyWith(
        extensions: <ThemeExtension<dynamic>>[
          TextStyleExtension(
            regularText: const TextStyle(color: Colors.white, fontSize: 16),
            boldText: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            subtitleText: TextStyle(color: Colors.grey.shade300, fontSize: 14),
          ),
        ],
      ),
      themeMode: themeProvider.themeMode,
      home: const AppExitHandler(child: SplashScreen()),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    // First check if we have saved credentials
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (rememberMe) {
        final username = prefs.getString('username');
        final password = prefs.getString('password');

        if (username != null && password != null) {
          // Wait a bit to show the splash screen
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;

          // Try to auto-login with local SQLite database
          final dbHelper = DatabaseHelper.instance;
          final user = await dbHelper.getUserByCredentials(username, password);

          if (user != null) {
            // Set the current user (using the global variable from login_screen.dart)
            currentUser = user;
            
            debugPrint('Auto-login successful, user role: ${user.role}');
            
            // Check user role and navigate accordingly
            if (user.role == 'superadmin') {
              debugPrint('Navigating to SuperadminScreen');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const SuperadminScreen(),
                ),
              );
            } else {
              // Navigate directly to the main app for admin and regular users
              debugPrint('Navigating to ResponsiveCurrencyConverter');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ResponsiveCurrencyConverter(),
                ),
              );
            }
            return;
          }
        }
      }

      // If auto-login failed or no saved credentials, go to login screen
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      debugPrint('Error in auto-login: $e');

      // If error, default to login screen
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with Theme to force light theme for splash screen
    return Theme(
      // Force light theme data
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: Colors.blue.shade700,
          secondary: Colors.blue.shade700,
        ),
      ),
      child: Scaffold(
        body: Container(
          color: Colors.white, // Force white background
          child: Column(
            children: [
              // Main content in center
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo/icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.currency_exchange,
                          size: 100,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // App name
                      Text(
                        "Currency Exchanger",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // "By" and logo at bottom
              Container(
                margin: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    // "BY" text
                    Text(
                      "BY",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.black87, // Force dark text color
                      ),
                    ),

                    const SizedBox(height: 16),

                    // User logo
                    Image.asset(
                      'assets/images/logo.png',
                      width: 250,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
