import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';  // Add this import for File class
import '../db_helper.dart';
import '../models/currency.dart';
import '../models/user.dart';
import '../screens/login_screen.dart'; // Import to access currentUser
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

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
  final TextEditingController _defaultBuyRateController = TextEditingController();
  final TextEditingController _defaultSellRateController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;

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

  Future<void> _resetAllData() async {
    // Show confirmation dialog with warning
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _defaultSellRateController,
                decoration: const InputDecoration(
                  labelText: 'Default Sell Rate',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      defaultBuyRate: double.parse(_defaultBuyRateController.text),
                      defaultSellRate: double.parse(_defaultSellRateController.text),
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
    
    return SizedBox(
      height: 300, // Increase height to fit all options
      child: ListView(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Currency Management'),
            leading: const Icon(Icons.currency_exchange),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              setState(() {
                _showCurrencyManagement = true;
                _showUserManagement = false;
                _showExportSection = false;
                // Start auto-refresh when navigating to currency management
                _startAutoRefresh();
              });
            },
          ),
          
          // Export Data option
          ListTile(
            title: const Text('Export Data'),
            leading: const Icon(Icons.file_download),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              setState(() {
                _showExportSection = true;
                _showCurrencyManagement = false;
                _showUserManagement = false;
              });
            },
          ),
          
          // Only show User Accounts option to admin users
          if (isAdmin)
            ListTile(
              title: const Text('User Accounts'),
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
          
          const Divider(),
          
          // Reset All Data option (admin only)
          if (isAdmin)
            ListTile(
              title: const Text('Reset All Data'),
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              onTap: _resetAllData,
            ),
          
          // Logout option
          ListTile(
            title: const Text('Logout'),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: _logout,
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
      height: MediaQuery.of(context).size.height - 200, // Adjust height to fit the screen
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
                const Text(
                  'Currency Management',
                  style: TextStyle(
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
                label: const Text('Add SOM'),
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
                  ? const Center(
                      child: Text(
                        'No currencies available',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _currencies.length,
                      itemBuilder: (context, index) {
                        final currency = _currencies[index];
                        // Format quantity with 2 decimal places
                        final formattedQuantity = NumberFormat.currency(
                          decimalDigits: 2,
                          symbol: '',
                        ).format(currency.quantity);

                        // Use different style for SOM currency
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
                              'Quantity: $formattedQuantity\n'
                              'Last updated: ${DateFormat('dd-MM-yy HH:mm').format(currency.updatedAt)}\n'
                              'Buy Rate: ${currency.defaultBuyRate}\n'
                              'Sell Rate: ${currency.defaultSellRate}',
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
              child: const Text('Add New Currency'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserManagement() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200, // Adjust height to fit the screen
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
                const Text(
                  'User Management',
                  style: TextStyle(
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
                  ? const Center(
                      child: Text(
                        'No users available',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
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
                            'Role: ${user.role}\n'
                            'Created: ${DateFormat('dd-MM-yy').format(user.createdAt)}',
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
              child: const Text('Add New User'),
            ),
          ),
        ],
      ),
    );
  }

  // Add new method to build export section
  Widget _buildExportSection() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and header
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
                const Text(
                  'Export Data',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Date range and export settings
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Date Range',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Date Range Selection
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startDateController,
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _endDateController,
                            decoration: const InputDecoration(
                              labelText: 'End Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Export Options',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Export Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _exportData(exportType: 'history'),
                            icon: const Icon(Icons.history),
                            label: const Text('Export History'),
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
                            label: const Text('Export Statistics'),
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
      // Check start and end dates
      if (_startDate == null || _endDate == null) {
        _showSnackBar('Please select start and end dates');
        return;
      }
      
      if (_endDate!.isBefore(_startDate!)) {
        _showSnackBar('End date cannot be before start date');
        return;
      }

      // Request storage permission
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        _showSnackBar('Storage permission is required to export data');
        return;
      }

      // Create excel file
      final excel = Excel.createExcel();
      
      if (exportType == 'history') {
        await _exportHistoryData(excel);
      } else {
        await _exportAnalyticsData(excel);
      }
      
      // Save the file
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        _showSnackBar('Could not access storage directory');
        return;
      }
      
      // Get save location from user
      String? outputPath = await FilePicker.platform.getDirectoryPath();
      if (outputPath == null) {
        _showSnackBar('Export cancelled');
        return;
      }
      
      final fileName = '${exportType}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      final filePath = '$outputPath/$fileName';
      
      final fileBytes = excel.encode();
      if (fileBytes == null) {
        _showSnackBar('Failed to generate Excel file');
        return;
      }
      
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      _showSnackBar('Data exported successfully to: $filePath');
    } catch (e) {
      _showSnackBar('Error exporting data: ${e.toString()}');
    }
  }
  
  // Export history data
  Future<void> _exportHistoryData(Excel excel) async {
    // Create a sheet for history data
    final sheet = excel['History'];
    
    // Add headers
    final headers = ['Date', 'Currency', 'Operation', 'Rate', 'Quantity', 'Total'];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
    }
    
    // Get history data
    final historyData = await _dbHelper.getFilteredHistoryByDate(
      fromDate: _startDate!,
      toDate: _endDate!,
    );
    
    // Add data rows
    for (var i = 0; i < historyData.length; i++) {
      final entry = historyData[i];
      final rowIndex = i + 1; // +1 because headers are at row 0
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
          TextCellValue(DateFormat('dd-MM-yyyy HH:mm').format(entry.createdAt));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(entry.currencyCode);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(entry.operationType);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(entry.rate);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(entry.quantity);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(entry.total);
    }
    
    // Auto fit columns
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 15);
    }
  }
  
  // Export analytics data
  Future<void> _exportAnalyticsData(Excel excel) async {
    // Get analytics data
    final analyticsData = await _dbHelper.calculateAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );
    
    // Create summary sheet
    final summarySheet = excel['Summary'];
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('Period');
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = 
        TextCellValue('${DateFormat('dd-MM-yyyy').format(_startDate!)} to ${DateFormat('dd-MM-yyyy').format(_endDate!)}');
    
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('Total Profit');
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = 
        DoubleCellValue(analyticsData['total_profit'] as double);
    
    // Create currencies sheet
    final currencySheet = excel['Currency Statistics'];
    
    // Add headers
    final headers = [
      'Currency', 'Avg Purchase Rate', 'Total Purchased', 'Purchase Amount',
      'Avg Sale Rate', 'Total Sold', 'Sale Amount', 'Current Quantity', 'Profit'
    ];
    
    for (var i = 0; i < headers.length; i++) {
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
    }
    
    // Add data rows
    final currencyStats = analyticsData['currency_stats'] as List;
    for (var i = 0; i < currencyStats.length; i++) {
      final stat = currencyStats[i];
      final rowIndex = i + 1;
      
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
          TextCellValue(stat['currency'] as String);
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = 
          DoubleCellValue(stat['avg_purchase_rate'] as double);
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = 
          DoubleCellValue(stat['total_purchased'] as double);
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = 
          DoubleCellValue(stat['total_purchase_amount'] as double);
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = 
          DoubleCellValue(stat['avg_sale_rate'] as double);
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = 
          DoubleCellValue(stat['total_sold'] as double);
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = 
          DoubleCellValue(stat['total_sale_amount'] as double);
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = 
          DoubleCellValue(stat['current_quantity'] as double);
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = 
          DoubleCellValue(stat['profit'] as double);
    }
    
    // Auto fit columns
    for (var i = 0; i < headers.length; i++) {
      currencySheet.setColumnWidth(i, 15);
    }

    // Get daily profit data
    final dailyProfitData = await _dbHelper.getDailyProfitData(
      startDate: _startDate!,
      endDate: _endDate!,
    );

    // Create daily profit sheet
    final dailySheet = excel['Daily Profit'];
    dailySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('Date');
    dailySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = TextCellValue('Profit');

    for (var i = 0; i < dailyProfitData.length; i++) {
      final day = dailyProfitData[i];
      final rowIndex = i + 1;
      dailySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
          TextCellValue(day['day'] as String);
      dailySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = 
          DoubleCellValue(day['profit'] as double);
    }

    dailySheet.setColumnWidth(0, 15);
    dailySheet.setColumnWidth(1, 15);
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

