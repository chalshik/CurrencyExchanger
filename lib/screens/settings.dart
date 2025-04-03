import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';  // Add this import for File class
import '../db_helper.dart';
import '../models/currency.dart';
import '../models/user.dart';
import '../screens/login_screen.dart'; // Import to access currentUser
import '../widgets/language_selector.dart';
import '../providers/language_provider.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:media_scanner/media_scanner.dart';
import '../services/export_service.dart';

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
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _defaultBuyRateController = TextEditingController();
  final TextEditingController _defaultSellRateController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;

  // Add new property for export format
  String _selectedFormat = 'excel';

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _loadUsers();
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
    _startDateController.dispose();
    _endDateController.dispose();
    _defaultBuyRateController.dispose();
    _defaultSellRateController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencies() async {
    try {
      final currencies = await _dbHelper.getAllCurrencies();
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
      final users = await _dbHelper.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  String _getTranslatedText(String key, [Map<String, String>? params]) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    String text = languageProvider.translate(key);
    if (params != null) {
      params.forEach((key, value) {
        text = text.replaceAll('{$key}', value);
      });
    }
    return text;
  }

  Future<void> _resetAllData() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getTranslatedText('reset_all_data')),
        content: Text(
          _getTranslatedText('reset_warning'),
          style: const TextStyle(color: Colors.red),
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
              _getTranslatedText('reset_all_data'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_getTranslatedText('loading')),
              ],
            ),
          ),
        );
        
        await _dbHelper.resetAllData();
        
        if (!mounted) return;
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getTranslatedText('reset_success')),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
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
    _quantityController.text = "0"; // Set default value to 0
    _defaultBuyRateController.text = "0.0";
    _defaultSellRateController.text = "0.0";

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_getTranslatedText('add_new_currency')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: _newCurrencyCodeController,
                  decoration: InputDecoration(
                    labelText: _getTranslatedText('select_currency'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  maxLength: 3,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _getTranslatedText('amount'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _defaultBuyRateController,
                  decoration: InputDecoration(
                    labelText: _getTranslatedText('default_buy_rate'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _defaultSellRateController,
                  decoration: InputDecoration(
                    labelText: _getTranslatedText('default_sell_rate'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_getTranslatedText('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_newCurrencyCodeController.text.isNotEmpty &&
                    _quantityController.text.isNotEmpty &&
                    _defaultBuyRateController.text.isNotEmpty &&
                    _defaultSellRateController.text.isNotEmpty) {
                  try {
                    final newCurrency = CurrencyModel(
                      code: _newCurrencyCodeController.text.toUpperCase(),
                      quantity: double.parse(_quantityController.text),
                      defaultBuyRate: double.parse(_defaultBuyRateController.text),
                      defaultSellRate: double.parse(_defaultSellRateController.text),
                    );

                    await _dbHelper.insertCurrency(newCurrency);
                    await _loadCurrencies();
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_getTranslatedText('error')}: ${e.toString()}')),
                    );
                  }
                }
              },
              child: Text(_getTranslatedText('add')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddSomDialog() async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add SOM'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount to add',
              prefixIcon: Icon(Icons.attach_money),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter amount';
              }
              if (double.tryParse(value) == null) {
                return 'Please enter valid number';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final amount = double.parse(amountController.text);
                try {
                  await _dbHelper.addToSomBalance(amount);
                  Navigator.pop(context);
                  _showSuccessNotification('Successfully added $amount SOM');
                  // Refresh currencies to show updated SOM balance
                  _loadCurrencies();
                } catch (e) {
                  Navigator.pop(context);
                  _showErrorNotification('Failed to add SOM: ${e.toString()}');
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
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
          title: const Text('Add New User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: 'user',
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _roleController.text = value;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_usernameController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty) {
                  try {
                    // Check if username already exists
                    final exists = await _dbHelper.usernameExists(
                      _usernameController.text,
                    );
                    if (exists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Username already exists'),
                        ),
                      );
                      return;
                    }

                    final newUser = UserModel(
                      username: _usernameController.text,
                      password: _passwordController.text,
                      role: _roleController.text,
                    );

                    await _dbHelper.createUser(newUser);
                    await _loadUsers();
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User created successfully'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Add'),
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
            title: const Text('Confirm Delete'),
            content: Text('Are you sure you want to delete currency $code?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteCurrency(id);
        await _loadCurrencies();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Currency $code deleted')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting currency: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteUser(int? id, String username) async {
    if (id == null) return;

    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text('Are you sure you want to delete user $username?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteUser(id);
        await _loadUsers();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('User $username deleted')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          margin: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Language Selection
              ListTile(
                title: Text(_getTranslatedText('language')),
                leading: const Icon(Icons.language),
                trailing: DropdownButton<String>(
                  value: Provider.of<LanguageProvider>(context).currentLocale.languageCode,
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
                      Provider.of<LanguageProvider>(context, listen: false)
                          .setLanguage(languageCode);
                    }
                  },
                ),
              ),

              const Divider(),

              // Currency Management
              ListTile(
                title: Text(_getTranslatedText('currency_management')),
                leading: const Icon(Icons.currency_exchange),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  setState(() {
                    _showCurrencyManagement = true;
                    _showUserManagement = false;
                    _showExportSection = false;
                    _startAutoRefresh();
                  });
                },
              ),
              
              // Export Data option
              ListTile(
                title: Text(_getTranslatedText('export_data')),
                leading: const Icon(Icons.file_download),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  setState(() {
                    _startDate = today;
                    _endDate = now;
                    _startDateController.text = DateFormat('dd-MM-yyyy').format(today);
                    _endDateController.text = DateFormat('dd-MM-yyyy').format(now);
                    _showExportSection = true;
                    _showCurrencyManagement = false;
                    _showUserManagement = false;
                  });
                },
              ),
              
              // Only show User Accounts option to admin users
              if (isAdmin) ...[
                ListTile(
                  title: Text(_getTranslatedText('user_accounts')),
                  leading: const Icon(Icons.people),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    setState(() {
                      _showUserManagement = true;
                      _showCurrencyManagement = false;
                      _showExportSection = false;
                    });
                  },
                ),
              ],
            ],
          ),
        ),

        // Admin Actions Card
        if (isAdmin)
          Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              title: Text(_getTranslatedText('reset_all_data')),
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              onTap: _resetAllData,
            ),
          ),
        
        // Logout Card
        Card(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            title: Text(_getTranslatedText('logout')),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: _logout,
          ),
        ),
      ],
    );
  }

  // Logout function
  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
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
          const SnackBar(content: Text('Error during logout')),
        );
      }
    }
  }

  Widget _buildCurrencyManagement() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Column(
        children: [
          // Header section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Add SOM button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddSomDialog,
                icon: const Icon(Icons.add),
                label: Text(_getTranslatedText('add_som')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade100,
                  foregroundColor: Colors.blue.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Currency list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCurrencies,
              child: _currencies.isEmpty
                  ? Center(
                      child: Text(
                        _getTranslatedText('no_currencies'),
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _currencies.length,
                      itemBuilder: (context, index) {
                        final currency = _currencies[index];
                        final formattedQuantity = NumberFormat.currency(
                          decimalDigits: 2,
                          symbol: '',
                        ).format(currency.quantity);

                        final bool isSom = currency.code == 'SOM';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          color: isSom ? Colors.blue.shade50 : null,
                          child: ListTile(
                            title: Text(
                              currency.code ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSom ? Colors.blue.shade800 : null,
                              ),
                            ),
                            subtitle: Text(
                              '${_getTranslatedText('quantity')}: $formattedQuantity\n'
                              '${_getTranslatedText('last_updated')}: ${DateFormat('dd-MM-yy HH:mm').format(currency.updatedAt)}\n'
                              '${_getTranslatedText('buy_rate')}: ${currency.defaultBuyRate}\n'
                              '${_getTranslatedText('sell_rate')}: ${currency.defaultSellRate}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isSom) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditCurrencyDialog(currency),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteCurrency(currency.id, currency.code ?? ''),
                                  ),
                                ] else
                                  const Icon(Icons.payments, color: Colors.blue),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          
          // Add New Currency button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _showAddCurrencyDialog(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(_getTranslatedText('add_new_currency')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserManagement() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _showUserManagement = false;
                      _autoRefreshTimer?.cancel();
                    });
                  },
                ),
                const SizedBox(width: 16),
                Text(
                  _getTranslatedText('user_accounts'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUsers,
              child: _users.isEmpty
                  ? Center(
                      child: Text(
                        _getTranslatedText('no_users'),
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: 
                              user.role == 'admin' ? Colors.orange : Colors.blue,
                            child: Icon(
                              user.role == 'admin' 
                                  ? Icons.admin_panel_settings
                                  : Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(user.username),
                          subtitle: Text(
                            '${_getTranslatedText('role')}: ${_getTranslatedText(user.role)}\n'
                            '${_getTranslatedText('created')}: ${DateFormat('dd-MM-yy').format(user.createdAt)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteUser(user.id, user.username),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _showAddUserDialog(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(_getTranslatedText('add_new_user')),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
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
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTranslatedText('select_date_range'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startDateController,
                            decoration: InputDecoration(
                              labelText: _getTranslatedText('start_date'),
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _endDateController,
                            decoration: InputDecoration(
                              labelText: _getTranslatedText('end_date'),
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      _getTranslatedText('export_format'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(_getTranslatedText('excel')),
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
                            title: Text(_getTranslatedText('pdf')),
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
                    const SizedBox(height: 24),
                    
                    Text(
                      _getTranslatedText('export_options'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _exportData(exportType: 'history'),
                            icon: const Icon(Icons.history),
                            label: Text(_getTranslatedText('export_history')),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _exportData(exportType: 'analytics'),
                            icon: const Icon(Icons.analytics),
                            label: Text(_getTranslatedText('export_statistics')),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
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

  // Date selection method
  Future<void> _selectDate(bool isStartDate) async {
    final initialDate = isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        } else {
          _endDate = picked;
          _endDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        }
      });
    }
  }

  // Method to export data
  Future<void> _exportData({required String exportType}) async {
    try {
      final startDate = _startDateController.text.isNotEmpty
          ? DateFormat('dd-MM-yy').parse(_startDateController.text)
          : DateTime.now().subtract(const Duration(days: 30));
      final endDate = _endDateController.text.isNotEmpty
          ? DateFormat('dd-MM-yy').parse(_endDateController.text)
          : DateTime.now();

      final fileName = exportType == 'history'
          ? 'transaction_history_${DateFormat('dd-MM-yy').format(DateTime.now())}'
          : 'analytics_${DateFormat('dd-MM-yy').format(DateTime.now())}';

      final filePath = await _exportService.exportData(
        startDate: startDate,
        endDate: endDate,
        format: _selectedFormat,
        fileName: fileName,
        exportType: exportType,
      );

      await MediaScanner.loadMedia(path: filePath);
      _showSnackBar(_getTranslatedText('export_success'));
    } catch (e) {
      _showSnackBar('${_getTranslatedText('export_error')}: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showEditCurrencyDialog(CurrencyModel currency) async {
    final TextEditingController codeController = TextEditingController(text: currency.code);
    final TextEditingController quantityController = TextEditingController(text: currency.quantity.toString());
    final TextEditingController defaultBuyRateController = TextEditingController(text: currency.defaultBuyRate.toString());
    final TextEditingController defaultSellRateController = TextEditingController(text: currency.defaultSellRate.toString());

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${currency.code}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Currency Code',
                  hintText: 'Enter currency code (e.g. USD)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'Enter current quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: defaultBuyRateController,
                decoration: const InputDecoration(
                  labelText: 'Default Buy Rate',
                  hintText: 'Enter default buy rate',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: defaultSellRateController,
                decoration: const InputDecoration(
                  labelText: 'Default Sell Rate',
                  hintText: 'Enter default sell rate',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final newCode = codeController.text.toUpperCase();
                final newQuantity = double.parse(quantityController.text);
                final newBuyRate = double.parse(defaultBuyRateController.text);
                final newSellRate = double.parse(defaultSellRateController.text);

                if (newQuantity < 0 || newBuyRate <= 0 || newSellRate <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid values: Quantity cannot be negative, rates must be greater than 0'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Check if the new code already exists (if it's different from current code)
                if (newCode != currency.code) {
                  final existingCurrency = await _dbHelper.getCurrency(newCode);
                  if (existingCurrency != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Currency code already exists'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

                // Update currency with new values
                final updatedCurrency = currency.copyWith(
                  code: newCode,
                  quantity: newQuantity,
                  defaultBuyRate: newBuyRate,
                  defaultSellRate: newSellRate,
                );

                await _dbHelper.updateCurrency(updatedCurrency);
                if (mounted) {
                  Navigator.pop(context);
                  _loadCurrencies(); // Refresh the list
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid numbers'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

