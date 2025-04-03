import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io'; // Add this import for File class
import '../db_helper.dart';
import '../models/currency.dart';
import '../models/user.dart';
import '../screens/login_screen.dart'; // Import to access currentUser
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:media_scanner/media_scanner.dart';
import '../widgets/currency_management_widget.dart';
import '../widgets/user_management_widget.dart';
import '../widgets/data_export_widget.dart';
import '../widgets/data_reset_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
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
  final TextEditingController _defaultBuyRateController =
      TextEditingController();
  final TextEditingController _defaultSellRateController =
      TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  // Add new property for export format
  String _selectedFormat = 'excel';

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _loadUsers();
    _checkAdminStatus();
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

  Future<void> _resetAllData() async {
    // Show confirmation dialog with warning
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset All Data'),
            content: const Text(
              'WARNING: This will delete all currencies, transaction history, and users except the admin. '
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Reset Everything',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );

        // Perform the reset
        await _dbHelper.resetAllData();

        // Close loading indicator
        if (!mounted) return;
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been reset'),
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
        // Close loading indicator if still showing
        if (!mounted) return;
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting data: ${e.toString()}'),
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
          title: const Text('Add New Currency'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newCurrencyCodeController,
                decoration: const InputDecoration(
                  labelText: 'Currency Code (e.g. USD)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Initial Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _defaultBuyRateController,
                decoration: const InputDecoration(
                  labelText: 'Default Buy Rate',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _defaultSellRateController,
                decoration: const InputDecoration(
                  labelText: 'Default Sell Rate',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                if (_newCurrencyCodeController.text.isNotEmpty &&
                    _quantityController.text.isNotEmpty &&
                    _defaultBuyRateController.text.isNotEmpty &&
                    _defaultSellRateController.text.isNotEmpty) {
                  try {
                    final newCurrency = CurrencyModel(
                      code: _newCurrencyCodeController.text.toUpperCase(),
                      quantity: double.parse(_quantityController.text),
                      defaultBuyRate: double.parse(
                        _defaultBuyRateController.text,
                      ),
                      defaultSellRate: double.parse(
                        _defaultSellRateController.text,
                      ),
                    );

                    await _dbHelper.insertCurrency(newCurrency);
                    await _loadCurrencies();
                    Navigator.pop(context);
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

  Future<void> _showAddSomDialog() async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                      _showSuccessNotification(
                        'Successfully added $amount SOM',
                      );
                      // Refresh currencies to show updated SOM balance
                      _loadCurrencies();
                    } catch (e) {
                      Navigator.pop(context);
                      _showErrorNotification(
                        'Failed to add SOM: ${e.toString()}',
                      );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.currency_exchange),
                label: Text('Currencies'),
              ),
              if (_isAdmin) ...[
                const NavigationRailDestination(
                  icon: Icon(Icons.people),
                  label: Text('Users'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.file_download),
                  label: Text('Export'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.delete_forever),
                  label: Text('Reset'),
                ),
              ],
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildSelectedContent()),
        ],
      ),
    );
  }

  Widget _buildSelectedContent() {
    switch (_selectedIndex) {
      case 0:
        return CurrencyManagementWidget(dbHelper: _dbHelper, isAdmin: _isAdmin);
      case 1:
        return UserManagementWidget(dbHelper: _dbHelper, isAdmin: _isAdmin);
      case 2:
        return DataExportWidget(dbHelper: _dbHelper);
      case 3:
        return DataResetWidget(dbHelper: _dbHelper);
      default:
        return const Center(child: Text('Select a setting'));
    }
  }

  Future<void> _checkAdminStatus() async {
    setState(() {
      _isAdmin = currentUser?.role == 'admin';
    });
  }
}
