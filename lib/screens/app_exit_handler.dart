import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

// Widget to handle app exit confirmation
class AppExitHandler extends StatelessWidget {
  final Widget child;

  const AppExitHandler({super.key, required this.child});

  Future<bool> _onWillPop(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.translate('exit_app')),
        content: Text(languageProvider.translate('exit_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(languageProvider.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(languageProvider.translate('exit'), 
              style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: child,
    );
  }
} 