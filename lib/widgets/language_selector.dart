import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return DropdownButton<String>(
      value: languageProvider.currentLocale.languageCode,
      items: const [
        DropdownMenuItem(
          value: 'ky',
          child: Text('Кыргызча'),
        ),
        DropdownMenuItem(
          value: 'ru',
          child: Text('Русский'),
        ),
        DropdownMenuItem(
          value: 'en',
          child: Text('English'),
        ),
      ],
      onChanged: (String? languageCode) {
        if (languageCode != null) {
          languageProvider.setLanguage(languageCode);
        }
      },
    );
  }
} 