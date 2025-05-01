import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import '../db_helper.dart';
import '../models/currency.dart';
import '../models/user.dart';
import '../screens/login_screen.dart';
import '../widgets/language_selector.dart';
import '../providers/language_provider.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:media_scanner/media_scanner.dart';
import '../services/export_service.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ExportService _exportService = ExportService();
  List<CurrencyModel> _currencies = [];
  List<UserModel> _users = [];
  final TextEditingController _newCurrencyCodeController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  bool _showCurrencyManagement = false;
  bool _showUserManagement = false;
  bool _showExportSection = false;
  Timer? _autoRefreshTimer;
  bool _isAdmin = false;
  final _currencyController = TextEditingController();
  final TextEditingController _somController = TextEditingController();
  final TextEditingController _defaultBuyRateController =
      TextEditingController();
  final TextEditingController _defaultSellRateController =
      TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  // Add new property for export
  String _selectedFormat = 'excel';
  String _exportType = 'history'; // Add export type variable

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _loadUsers();
    _checkAdminStatus();
  }

  void _checkAdminStatus() {
    setState(() {
      _isAdmin = currentUser?.role == 'admin';
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when the screen becomes visible
    if (_showCurrencyManagement) {
      _loadCurrencies();
      _startAutoRefresh();
    } else if (_showUserManagement) {
      _loadUsers();
    } else {
      // Also refresh when first navigating to this screen
      _loadCurrencies();
      _loadUsers();
    }
  }

  void _startAutoRefresh() {
    // Cancel any existing timer
    _autoRefreshTimer?.cancel();

    // Set up a timer to refresh currencies every 3 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_showCurrencyManagement && mounted) {
        _loadCurrencies();
      } else if (_showUserManagement && mounted) {
        _loadUsers();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _newCurrencyCodeController.dispose();
    _quantityController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _roleController.dispose();
    _currencyController.dispose();
    _somController.dispose();
    _defaultBuyRateController.dispose();
    _defaultSellRateController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencies() async {
    try {
      List<CurrencyModel> currencies;
      
      // Get currencies from the appropriate collection based on user context
      if (currentUser?.companyId != null) {
        // For company users, get currencies from the company collection
        currencies = await _dbHelper.getAllCurrencies(companyId: currentUser!.companyId);
        debugPrint('Loaded ${currencies.length} currencies from company ${currentUser!.companyId}');
      } else {
        // Fallback to root currencies collection for legacy support
        currencies = await _dbHelper.getAllCurrencies();
        debugPrint('WARNING: Loading currencies from root collection (legacy)');
      }
      
      if (!mounted) return;
      setState(() {
        // Ensure proper quantity parsing for all currencies
        _currencies =
            currencies.map((currency) {
              // Ensure quantity is properly parsed as double
              return CurrencyModel(
                id: currency.id,
                code: currency.code,
                quantity:
                    currency.quantity is double
                        ? currency.quantity
                        : double.tryParse(currency.quantity.toString()) ?? 0.0,
                updatedAt: currency.updatedAt,
                defaultBuyRate: currency.defaultBuyRate,
                defaultSellRate: currency.defaultSellRate,
              );
            }).toList();
      });
    } catch (e) {
      debugPrint('Error loading currencies: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      List<UserModel> users;
      if (currentUser?.companyId != null) {
        // For company users, get users from the company
        users = await _dbHelper.getCompanyUsers(currentUser!.companyId!);
        debugPrint('Loaded ${users.length} users from company ${currentUser!.companyId}');
      } else if (currentUser?.role == 'superadmin') {
        // For superadmins, get root users
        users = await _dbHelper.getAllUsers();
        debugPrint('Loaded ${users.length} users as superadmin');
      } else {
        // Fallback to root users for legacy support
        users = await _dbHelper.getAllUsers();
        debugPrint('WARNING: Loading users from root collection (legacy)');
      }
      
      if (!mounted) return;
      setState(() {
        _users = users;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  String _getTranslatedText(String key, [Map<String, String>? params]) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    String text = languageProvider.translate(key);
    if (params != null) {
      params.forEach((key, value) {
        text = text.replaceAll('{$key}', value);
      });
    }
    return text;
  }

  Future<void> _resetAllData() async {
    bool shouldBackup = true; // Default to true for safety
    
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(_getTranslatedText('reset_all_data')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTranslatedText('reset_warning'),
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: shouldBackup,
                    onChanged: (value) {
                      setState(() {
                        shouldBackup = value ?? true;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      _getTranslatedText('backup_before_reset'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_getTranslatedText('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                _getTranslatedText('reset_everything'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        // If backup is selected, create a backup first
        if (shouldBackup) {
          debugPrint('Creating backup before reset...');
          await _dbHelper.backupStatistics();
        }

        // Perform the reset
        await _dbHelper.resetAllData();

        // Close loading indicator
        if (!mounted) return;
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getTranslatedText('reset_success')),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the data
        await _loadCurrencies();
        await _loadUsers();

        // Return to main settings page
        setState(() {
          _showCurrencyManagement = false;
          _showUserManagement = false;
        });
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getTranslatedText('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddCurrencyDialog(BuildContext context) async {
    _newCurrencyCodeController.clear();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _getTranslatedText('add_new_currency'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newCurrencyCodeController,
                decoration: InputDecoration(
                  labelText: _getTranslatedText('currency_code'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                _getTranslatedText('cancel'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_newCurrencyCodeController.text.isNotEmpty) {
                  try {
                    final currencyCode = _newCurrencyCodeController.text.toUpperCase();
                    final newCurrency = CurrencyModel(
                      code: currencyCode,
                    );

                    if (currentUser?.companyId != null) {
                      // Add currency to company-specific collection
                      await _dbHelper.insertCurrency(
                        newCurrency, 
                        companyId: currentUser!.companyId
                      );
                      debugPrint('Added currency $currencyCode to company ${currentUser!.companyId}');
                    } else {
                      // Fallback to root collection (legacy)
                      await _dbHelper.insertCurrency(newCurrency);
                      debugPrint('WARNING: Added currency $currencyCode to root collection (legacy)');
                    }
                    
                    await _loadCurrencies();
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${_getTranslatedText('error')}: ${e.toString()}',
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _getTranslatedText('add'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showAddUserDialog(BuildContext context) async {
    _usernameController.clear();
    _passwordController.clear();
    _roleController.text = 'user'; // Default role

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _getTranslatedText('add_new_user'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: _getTranslatedText('username'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: _getTranslatedText('password'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                _getTranslatedText('cancel'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_usernameController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty) {
                  try {
                    final username = _usernameController.text;
                    final password = _passwordController.text;
                    
                    if (currentUser?.companyId != null) {
                      // Check if username exists in the company
                      final exists = await _dbHelper.companyUsernameExists(
                        currentUser!.companyId!,
                        username,
                      );
                      
                      if (exists) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_getTranslatedText('username_exists')),
                          ),
                        );
                        return;
                      }
                      
                      // Create user in the company
                      await _dbHelper.createCompanyUser(
                        currentUser!.companyId!,
                        username,
                        password,
                        'user', // Always create regular users
                      );
                      debugPrint('Created user in company ${currentUser!.companyId}');
                    } else {
                      // Check if username exists in root collection (legacy)
                      final exists = await _dbHelper.usernameExists(username);
                      
                      if (exists) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_getTranslatedText('username_exists')),
                          ),
                        );
                        return;
                      }
                      
                      // Create user in root collection (legacy)
                      final newUser = UserModel(
                        username: username,
                        password: password,
                        role: 'user',
                      );
                      
                      await _dbHelper.createUser(newUser);
                      debugPrint('WARNING: Created user in root collection (legacy)');
                    }
                    
                    await _loadUsers();
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_getTranslatedText('user_created')),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${_getTranslatedText('error')}: ${e.toString()}',
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _getTranslatedText('add'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCurrency(int? id, String code) async {
    if (id == null || code == 'SOM') return;

    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_getTranslatedText('confirm_delete_currency', {'code': code})),
            content: Text(_getTranslatedText('confirm_delete_currency_message', {'code': code})),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_getTranslatedText('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  _getTranslatedText('delete'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        if (currentUser?.companyId != null) {
          // Delete from company-specific collection
          await _dbHelper.deleteCurrency(code, companyId: currentUser!.companyId);
          debugPrint('Deleted currency $code from company ${currentUser!.companyId}');
        } else {
          // Fallback to root collection (legacy)
          await _dbHelper.deleteCurrency(code);
          debugPrint('WARNING: Deleted currency $code from root collection (legacy)');
        }
        
        await _loadCurrencies();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getTranslatedText('currency_deleted', {'code': code}))));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getTranslatedText('error_deleting_currency', {'code': code}))),
        );
      }
    }
  }

  Future<void> _deleteUser(String? id, String username) async {
    if (id == null) return;
    
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_getTranslatedText('confirm_delete')),
            content: Text(_getTranslatedText('confirm_delete_user', {'username': username})),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_getTranslatedText('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  _getTranslatedText('delete'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        if (currentUser?.companyId != null) {
          // Delete from company-specific collection
          await _dbHelper.deleteUser(id, companyId: currentUser!.companyId);
          debugPrint('Deleted user $username from company ${currentUser!.companyId}');
        } else {
          // Fallback to root collection (legacy)
          await _dbHelper.deleteUser(id);
          debugPrint('WARNING: Deleted user $username from root collection (legacy)');
        }
        
        await _loadUsers();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getTranslatedText('user_deleted', {'username': username}))));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_getTranslatedText('error')}: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary content based on what's selected
              if (_showCurrencyManagement)
                _buildCurrencyManagement()
              else if (_showUserManagement)
                _buildUserManagement()
              else if (_showExportSection)
                _buildExportSection()
              else
                _buildSettings(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettings() {
    // Check if user is admin
    final bool isAdmin = currentUser?.role == 'admin';
    final themeProvider = Provider.of<ThemeProvider>(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  title: Text(
                    _getTranslatedText('language'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  leading: Icon(
                    Icons.language,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  trailing: const LanguageSelector(),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  title: Text(
                    _getTranslatedText('theme'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  leading: Icon(
                    themeProvider.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  title: Text(
                    _getTranslatedText('currency_settings'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  leading: Icon(
                    Icons.currency_exchange,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 20),
                  onTap: () {
                    setState(() {
                      _showCurrencyManagement = true;
                      _showUserManagement = false;
                      _showExportSection = false;
                      _startAutoRefresh();
                    });
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                if (isAdmin) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    title: Text(
                      _getTranslatedText('export_data'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    leading: Icon(
                      Icons.file_download,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 20),
                    onTap: () {
                      setState(() {
                        _showExportSection = true;
                        _showCurrencyManagement = false;
                        _showUserManagement = false;
                      });
                    },
                  ),
                ],
                if (isAdmin) ...[
                  Divider(height: 1, color: Colors.grey.shade200),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    title: Text(
                      _getTranslatedText('user_settings'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    leading: Icon(
                      Icons.people,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 20),
                    onTap: () {
                      setState(() {
                        _showUserManagement = true;
                        _showCurrencyManagement = false;
                        _showExportSection = false;
                      });
                    },
                  ),
                ],
                if (isAdmin) ...[
                  Divider(height: 1, color: Colors.grey.shade200),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    title: Text(
                      _getTranslatedText('reset_all_data'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                      size: 28,
                    ),
                    onTap: _resetAllData,
                  ),
                ],
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  title: Text(
                    _getTranslatedText('logout'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.red,
                    size: 28,
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),

          // Watermark / Made by section
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Column(
              children: [
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.copyright,
                      size: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Made by Boz Zat",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "v2.1.0",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Logout function
  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_getTranslatedText('logout')),
            content: Text(_getTranslatedText('logout_confirmation')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_getTranslatedText('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  _getTranslatedText('logout'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldLogout == true) {
      try {
        // Clear remember me if enabled
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', false);

        // Clear the current user
        currentUser = null;

        if (!mounted) return;

        // Navigate back to login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // Remove all previous routes
        );
      } catch (e) {
        debugPrint('Error during logout: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getTranslatedText('logout_error'))),
        );
      }
    }
  }

  Widget _buildCurrencyManagement() {
    return SizedBox(
      height:
          MediaQuery.of(context).size.height -
          200, // Adjust height to fit the screen
      child: Column(
        children: [
          // Header section
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 28),
                  onPressed: () {
                    setState(() {
                      _showCurrencyManagement = false;
                      _autoRefreshTimer?.cancel();
                    });
                  },
                ),
                const SizedBox(width: 16),
                Text(
                  _getTranslatedText('currency_management'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Add currency button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showAddCurrencyDialog(context),
              icon: const Icon(Icons.add),
              label: Text(_getTranslatedText('add_currency')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

          // Currency list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCurrencies,
              child: _buildCurrencyList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Filter out SOM currency
    final displayableCurrencies =
        _currencies.where((c) => c.code != 'SOM').toList();

    return displayableCurrencies.isEmpty
        ? const Center(
          child: Text(
            'No currencies available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        )
        : ListView.builder(
          itemCount: displayableCurrencies.length,
          itemBuilder: (context, index) {
            final currency = displayableCurrencies[index];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  title: Text(
                    currency.code!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed:
                            () => _showEditCurrencyDialog(context, currency),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteCurrency(currency),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
  }

  Future<void> _showEditCurrencyDialog(
    BuildContext context,
    CurrencyModel currency,
  ) async {
    // Don't allow editing SOM
    if (currency.code == 'SOM') return;

    // Initialize text controllers with current values
    _newCurrencyCodeController.text = currency.code!;

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _getTranslatedText('edit_currency'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newCurrencyCodeController,
                decoration: InputDecoration(
                  labelText: _getTranslatedText('currency_code'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                _getTranslatedText('cancel'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final newCode = _newCurrencyCodeController.text.toUpperCase();

                  // Check if new code already exists (unless it's the same code)
                  if (newCode != currency.code) {
                    final existingCurrency = await _dbHelper.getCurrency(
                      newCode,
                    );
                    if (existingCurrency != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _getTranslatedText('currency_exists_error'),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }

                  // Update currency with new code only
                  final updatedCurrency = currency.copyWith(code: newCode);

                  await _dbHelper.updateCurrency(updatedCurrency);
                  if (mounted) {
                    Navigator.pop(context);
                    _loadCurrencies(); // Refresh the list
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_getTranslatedText('error')}: ${e.toString()}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _getTranslatedText('save'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserManagement() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 28),
                  onPressed: () {
                    setState(() {
                      _showUserManagement = false;
                      _autoRefreshTimer?.cancel();
                    });
                  },
                ),
                const SizedBox(width: 16),
                Text(
                  _getTranslatedText('user_management'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUsers,
              child:
                  _users.isEmpty
                      ? Center(
                        child: Text(
                          _getTranslatedText('no_users_available'),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _users.where((user) => user.role != 'admin').length,
                        itemBuilder: (context, index) {
                          // Filter out admin users and get the user at the current index
                          final user = _users.where((user) => user.role != 'admin').elementAt(index);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: const CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blue,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              title: Text(
                                user.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${_getTranslatedText('created')}: ${DateFormat('dd-MM-yy').format(user.createdAt)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 26,
                                ),
                                onPressed:
                                    () => _deleteUser(
                                      user.id,
                                      user.username,
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddUserDialog(context),
              icon: const Icon(Icons.person_add),
              label: Text(
                _getTranslatedText('add_new_user'),
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 28),
                  onPressed: () {
                    setState(() {
                      _showExportSection = false;
                    });
                  },
                ),
                const SizedBox(width: 16),
                Text(
                  _getTranslatedText('export_data'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Export settings
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTranslatedText('export_format'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Format Selection
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(
                              _getTranslatedText('excel'),
                              style: const TextStyle(fontSize: 16),
                            ),
                            value: 'excel',
                            groupValue: _selectedFormat,
                            onChanged: (value) {
                              setState(() {
                                _selectedFormat = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(
                              _getTranslatedText('pdf'),
                              style: const TextStyle(fontSize: 16),
                            ),
                            value: 'pdf',
                            groupValue: _selectedFormat,
                            onChanged: (value) {
                              setState(() {
                                _selectedFormat = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    Text(
                      _getTranslatedText('export_options'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Export Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _exportType = 'history';
                              });
                              _exportData();
                            },
                            icon: const Icon(Icons.history, size: 24),
                            label: Text(
                              _getTranslatedText('export_history'),
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _exportType = 'statistics';
                              });
                              _exportData();
                            },
                            icon: const Icon(Icons.analytics, size: 24),
                            label: Text(
                              _getTranslatedText('export_statistics'),
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to export data
  Future<void> _exportData() async {
    try {
      // Set start and end dates to today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      _startDate = today;
      _endDate = now;

      // Get the Documents directory
      final directory = Directory('/storage/emulated/0/Documents');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileName =
          '${_exportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      String filePath;

      if (_selectedFormat == 'excel') {
        filePath = await _exportToExcel(directory, fileName);
      } else {
        filePath = await _exportToPdf(directory, fileName);
      }

      // Trigger media scan
      await MediaScanner.loadMedia(path: filePath);
      _showSnackBar(_getTranslatedText('export_success'));
    } catch (e) {
      _showSnackBar('${_getTranslatedText('export_error')}: ${e.toString()}');
    }
  }

  Future<String> _exportToExcel(Directory directory, String fileName) async {
    final excel = Excel.createExcel();

    if (fileName.contains('history')) {
      await _exportHistoryData(excel);
    } else {
      await _exportAnalyticsData(excel);
    }

    final filePath = '${directory.path}/${fileName}.xlsx';
    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
    return filePath;
  }

  Future<String> _exportToPdf(Directory directory, String fileName) async {
    final pdf = pw.Document();
    late final String filePath;
    late final File file;

    try {
      if (fileName.contains('history')) {
        // Get history data with company ID if available
        final historyData = await _dbHelper.getFilteredHistoryByDate(
          startDate: _startDate!,
          endDate: _endDate!,
          companyId: currentUser?.companyId, // Pass the company ID if available
        );

        // Create PDF content for history
        pdf.addPage(
          pw.MultiPage(
            build:
                (context) => [
                  pw.Header(
                    level: 0,
                    child: pw.Text('Transaction History Report'),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Period: ${DateFormat('dd-MM-yyyy').format(_startDate!)} to ${DateFormat('dd-MM-yyyy').format(_endDate!)}',
                  ),
                  pw.SizedBox(height: 20),
                  pw.Table.fromTextArray(
                    headers: [
                      'Date',
                      'Currency',
                      'Operation',
                      'Rate',
                      'Quantity',
                      'Total',
                    ],
                    data:
                        historyData
                            .map(
                              (entry) => [
                                DateFormat(
                                  'dd-MM-yyyy HH:mm',
                                ).format(entry.createdAt),
                                entry.currencyCode,
                                entry.operationType,
                                entry.rate.toStringAsFixed(2),
                                entry.quantity.toStringAsFixed(2),
                                entry.total.toStringAsFixed(2),
                              ],
                            )
                            .toList(),
                  ),
                ],
          ),
        );
      } else {
        // Get analytics data with company ID if available
        final analyticsData = await _dbHelper.calculateAnalytics(
          startDate: _startDate,
          endDate: _endDate,
          companyId: currentUser?.companyId, // Pass the company ID if available
        );

        // Create PDF content for statistics
        pdf.addPage(
          pw.MultiPage(
            build:
                (context) => [
                  pw.Header(
                    level: 0,
                    child: pw.Text('Currency Statistics Report'),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Period: ${DateFormat('dd-MM-yyyy').format(_startDate!)} to ${DateFormat('dd-MM-yyyy').format(_endDate!)}',
                  ),
                  pw.SizedBox(height: 20),
                  pw.Table.fromTextArray(
                    headers: [
                      'Currency',
                      'Avg Purchase Rate',
                      'Total Purchased',
                      'Purchase Amount',
                      'Avg Sale Rate',
                      'Total Sold',
                      'Sale Amount',
                      'Current Quantity',
                      'Profit',
                    ],
                    data:
                        (analyticsData['currency_stats'] as List)
                            .map(
                              (stat) => [
                                stat['currency'] as String,
                                (stat['avg_purchase_rate'] as double)
                                    .toStringAsFixed(2),
                                (stat['total_purchased'] as double)
                                    .toStringAsFixed(2),
                                (stat['total_purchase_amount'] as double)
                                    .toStringAsFixed(2),
                                (stat['avg_sale_rate'] as double)
                                    .toStringAsFixed(2),
                                (stat['total_sold'] as double).toStringAsFixed(
                                  2,
                                ),
                                (stat['total_sale_amount'] as double)
                                    .toStringAsFixed(2),
                                (stat['current_quantity'] as double)
                                    .toStringAsFixed(2),
                                (stat['profit'] as double).toStringAsFixed(2),
                              ],
                            )
                            .toList(),
                  ),
                ],
          ),
        );
      }

      filePath = '${directory.path}/${fileName}.pdf';
      file = File(filePath);

      // Generate a unique filename if file exists
      int counter = 1;
      String newFilePath = filePath;
      File newFile = file;

      while (await newFile.exists()) {
        final newFileName = '${fileName}_${counter}';
        newFilePath = '${directory.path}/${newFileName}.pdf';
        newFile = File(newFilePath);
        counter++;
      }

      // Write the PDF file
      final bytes = await pdf.save();
      await newFile.writeAsBytes(bytes, flush: true);

      return newFilePath;
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      rethrow;
    }
  }

  // Export history data
  Future<void> _exportHistoryData(Excel excel) async {
    // Create a sheet for history data
    final sheet = excel['History'];

    // Add headers
    final headers = [
      'Date',
      'Currency',
      'Operation',
      'Rate',
      'Quantity',
      'Total',
    ];
    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = headers[i];
    }

    // Get history data
    final historyData = await _dbHelper.getFilteredHistoryByDate(
      startDate: _startDate!,
      endDate: _endDate!,
    );

    // Add data rows
    for (var i = 0; i < historyData.length; i++) {
      final entry = historyData[i];
      final rowIndex = i + 1; // +1 because headers are at row 0

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = DateFormat('dd-MM-yyyy HH:mm').format(entry.createdAt);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = entry.currencyCode;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = entry.operationType;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = entry.rate;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = entry.quantity;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = entry.total;
    }

    // Set column widths
    for (var i = 0; i < headers.length; i++) {
      sheet.setColWidth(i, 20.0);
    }
  }

  // Export analytics data
  Future<void> _exportAnalyticsData(Excel excel) async {
    // Get analytics data
    final analyticsData = await _dbHelper.calculateAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );

    // Delete all existing sheets
    excel.delete('Sheet1');

    // Create currencies sheet
    final currencySheet = excel['Currency Statistics'];

    // Add headers
    final headers = [
      'Currency',
      'Avg Purchase Rate',
      'Total Purchased',
      'Purchase Amount',
      'Avg Sale Rate',
      'Total Sold',
      'Sale Amount',
      'Current Quantity',
      'Profit',
    ];

    for (var i = 0; i < headers.length; i++) {
      currencySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = headers[i];
    }

    // Add data rows
    final currencyStats = analyticsData['currency_stats'] as List;
    for (var i = 0; i < currencyStats.length; i++) {
      final stat = currencyStats[i];
      final rowIndex = i + 1;

      currencySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = stat['currency'] as String;
      currencySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = stat['avg_purchase_rate'] as double;
      currencySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = stat['total_purchased'] as double;
      currencySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = stat['total_purchase_amount'] as double;
      currencySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = stat['avg_sale_rate'] as double;
      currencySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = stat['total_sold'] as double;
      currencySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = stat['total_sale_amount'] as double;
      currencySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .value = stat['current_quantity'] as double;
      currencySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
          .value = stat['profit'] as double;
    }

    // Set column widths
    for (var i = 0; i < headers.length; i++) {
      currencySheet.setColWidth(i, 20.0);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            message.contains(_getTranslatedText('error'))
                ? Colors.red
                : Colors.green,
      ),
    );
  }

  Future<void> _confirmDeleteCurrency(CurrencyModel currency) async {
    // Check if it's SOM (cannot delete SOM)
    if (currency.code == 'SOM') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getTranslatedText('cannot_delete_som')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_getTranslatedText('confirm_delete')),
            content: Text(
              _getTranslatedText('confirm_delete_currency', {
                'code': currency.code!,
              }),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_getTranslatedText('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  _getTranslatedText('delete'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    // If confirmed, delete the currency
    if (confirmed == true && mounted) {
      try {
        await _deleteCurrency(currency.id, currency.code!);
        _loadCurrencies(); // Refresh the list

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _getTranslatedText('currency_deleted', {'code': currency.code!}),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getTranslatedText('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
