import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flag/flag.dart';
import '../providers/language_provider.dart';

class FlagLanguageSelector extends StatelessWidget {
  final bool mini;
  
  const FlagLanguageSelector({
    super.key, 
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLocale.languageCode;
    
    // Map language codes to country codes and next language in cycle
    final Map<String, Map<String, dynamic>> languageMap = {
      'ky': {'country': 'KG', 'next': 'en'},
      'en': {'country': 'GB', 'next': 'ru'},
      'ru': {'country': 'RU', 'next': 'ky'},
    };
    
    // Get the current country code based on language
    final currentCountry = languageMap[currentLanguage]?['country'] ?? 'KG';
    final nextLanguage = languageMap[currentLanguage]?['next'] ?? 'en';
    
    return _buildFlagButton(
      context,
      currentCountry,
      nextLanguage,
    );
  }
  
  Widget _buildFlagButton(
    BuildContext context,
    String countryCode,
    String nextLanguageCode,
  ) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final double size = mini ? 25.0 : 40.0;
    
    return InkWell(
      onTap: () => languageProvider.setLanguage(nextLanguageCode),
      borderRadius: BorderRadius.circular(size / 2),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Flag.fromString(
            countryCode,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
} 