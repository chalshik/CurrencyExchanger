import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool mini;
  
  const ThemeToggleButton({
    super.key,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final size = mini ? 40.0 : 60.0;
    
    return InkWell(
      onTap: () => themeProvider.toggleTheme(),
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        padding: const EdgeInsets.all(2),
        height: size,
        width: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            isDarkMode ? Icons.light_mode : Icons.dark_mode,
            size: size * 0.6,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
} 