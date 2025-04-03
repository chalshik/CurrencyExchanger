import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/login_screen.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currency Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
