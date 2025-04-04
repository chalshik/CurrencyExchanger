import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  static const String _themeModeKey = 'theme_mode';

  ThemeProvider() {
    _loadSavedTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeModeKey);
      if (savedTheme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedTheme,
          orElse: () => ThemeMode.light,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.toString());
      _themeMode = mode;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  void toggleTheme() {
    setThemeMode(
      _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }

  // Light theme data (Black & White)
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.black,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: Colors.black,
        secondary: Colors.black87,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        background: Colors.white,
        surface: const Color(0xFFF5F5F5),
        error: Colors.red[700]!,
        onError: Colors.white,
        brightness: Brightness.light,
        // Add subtle accent
        tertiary: Colors.grey[800],
      ),
      textTheme: const TextTheme(
        // Title styles
        titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        titleSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),

        // Body styles
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black),
        bodySmall: TextStyle(color: Colors.black87),

        // Display styles
        displayLarge: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),

        // Other styles
        labelLarge: TextStyle(color: Colors.black),
        labelMedium: TextStyle(color: Colors.black),
        labelSmall: TextStyle(color: Colors.black),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        color: Colors.white,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.black87),
      ),
      iconTheme: IconThemeData(color: Colors.grey[850], size: 24),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[600],
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[300],
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey[700]),
        hintStyle: TextStyle(color: Colors.grey[500]),
        prefixIconColor: Colors.grey[700],
        suffixIconColor: Colors.grey[700],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.black87;
          }
          return Colors.grey[300];
        }),
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white;
          }
          return Colors.grey[50];
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.black;
          }
          return Colors.grey[300];
        }),
        checkColor: MaterialStateProperty.all(Colors.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.black;
          }
          return Colors.grey[400];
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: Colors.black,
        circularTrackColor: Colors.grey[200],
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.white,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey[850],
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: Colors.white70,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: Colors.black87,
        textColor: Colors.black,
        selectedTileColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.black87,
        disabledColor: Colors.grey[200],
        labelStyle: const TextStyle(color: Colors.black87),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
        ),
      ),
    );
  }

  // Dark theme data (Black & White)
  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.white,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.dark(
        primary: Colors.white,
        secondary: Colors.grey[300]!,
        onPrimary: const Color(0xFF121212),
        onSecondary: const Color(0xFF121212),
        background: const Color(0xFF121212),
        surface: const Color(0xFF1E1E1E),
        error: Colors.redAccent[100]!,
        onError: Colors.white,
        brightness: Brightness.dark,
        // Add subtle accent color
        tertiary: Colors.grey[400],
      ),
      textTheme: const TextTheme(
        // Title styles
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        titleSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),

        // Body styles
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white70),

        // Display styles
        displayLarge: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),

        // Other styles
        labelLarge: TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Colors.white70),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        elevation: 4,
        color: const Color(0xFF1E1E1E),
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[200],
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.grey[300]),
      ),
      iconTheme: IconThemeData(color: Colors.grey[300], size: 24),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey[600],
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[800],
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF262626),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.grey[500]),
        prefixIconColor: Colors.grey[400],
        suffixIconColor: Colors.grey[400],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.grey[300];
          }
          return Colors.grey[800];
        }),
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white;
          }
          return Colors.grey[400];
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white;
          }
          return Colors.grey[700];
        }),
        checkColor: MaterialStateProperty.all(Colors.black),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white;
          }
          return Colors.grey[600];
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: Colors.grey[300],
        circularTrackColor: Colors.grey[800],
      ),
      dialogTheme: DialogTheme(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.black,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey[800],
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: Colors.grey[300],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: Colors.grey[300],
        textColor: Colors.white,
        selectedTileColor: Colors.grey[800],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF262626),
        selectedColor: Colors.grey[300],
        disabledColor: Colors.grey[800],
        labelStyle: const TextStyle(color: Colors.white),
        secondaryLabelStyle: const TextStyle(color: Colors.black),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[700]!, width: 0.5),
        ),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!, width: 2),
          ),
        ),
      ),
    );
  }
}
