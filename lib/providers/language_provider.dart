import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'language_code';
  Locale _currentLocale = const Locale('ky'); // Default to Kyrgyz
  Map<String, dynamic> _translations = {};

  Locale get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString(_languageKey);
    if (languageCode != null) {
      _currentLocale = Locale(languageCode);
    }
    await _loadTranslations();
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (_currentLocale.languageCode == languageCode) return;

    _currentLocale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    await _loadTranslations();
    notifyListeners();
  }

  Future<void> _loadTranslations() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/translations/${_currentLocale.languageCode}.json',
      );
      _translations = json.decode(jsonString);
    } catch (e) {
      debugPrint('Error loading translations: $e');
      _translations = {};
    }
  }

  String translate(String key) {
    return _translations[key] ?? key;
  }

  // Method to preload translations at app startup
  Future<void> initializeTranslations() async {
    await _loadTranslations();
    notifyListeners();
  }

  Map<String, Map<String, String>> get translations => {
    'en': {
      // ... other translations ... 
      'group_by': 'Group by',
      'daily': 'Daily',
      'weekly': 'Weekly', 
      'monthly': 'Monthly',
      'week_of': 'Week of',
      // ... other translations ...
    },
    // Add to other languages as well (if the app has multiple languages)
  };
}
