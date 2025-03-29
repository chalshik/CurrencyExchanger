import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../db_helper.dart';
import '../models/currency.dart';
import '../models/user.dart';
import '../screens/login_screen.dart'; // Import to access currentUser

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
  Timer? _autoRefreshTimer;

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
                    _quantityController.text.isNotEmpty) {
                  try {
                    final newCurrency = CurrencyModel(
                      code: _newCurrencyCodeController.text.toUpperCase(),
                      quantity: double.parse(_quantityController.text),
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
      body: _showCurrencyManagement 
          ? _buildCurrencyManagement()
          : _showUserManagement 
              ? _buildUserManagement()
              : _buildSettings(),
    );
  }

  Widget _buildSettings() {
    // Check if user is admin
    final bool isAdmin = currentUser?.role == 'admin';
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Currency Management'),
          leading: const Icon(Icons.currency_exchange),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            setState(() {
              _showCurrencyManagement = true;
              // Start auto-refresh when navigating to currency management
              _startAutoRefresh();
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
    return Column(
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
                            'Last updated: ${DateFormat('dd-MM-yy HH:mm').format(currency.updatedAt)}',
                          ),
                          trailing: isSom 
                              ? const Icon(Icons.payments, color: Colors.blue)
                              : IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteCurrency(currency.id, currency.code ?? ''),
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
    );
  }

  Widget _buildUserManagement() {
    return Column(
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
    );
  }
}
