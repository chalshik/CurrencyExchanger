import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';

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

  // Determine if running on a tablet
  final size = WidgetsBinding.instance.window.physicalSize;
  final devicePixelRatio = WidgetsBinding.instance.window.devicePixelRatio;
  final width = size.width / devicePixelRatio;
  final isTablet = width >= 600;

  // Only force portrait on phones, allow both orientations on tablets
  if (!isTablet) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } else {
    // Allow all orientations on tablets
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
      home: const SplashScreen(),
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
    // Simulate loading time for 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Navigate to the login screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.currency_exchange,
                  size: 72,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 32),

              // App name
              Text(
                "Currency Changer",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),

              const SizedBox(height: 12),

              // Brand watermark
              Text(
                "By Boz Zat",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 48),

              // Loading indicator
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
