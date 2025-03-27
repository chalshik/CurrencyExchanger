import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _loadUsers();
  }

  Future<void> _loadCurrencies() async {
    try {
      final currencies = await _dbHelper.getAllCurrencies();
      setState(() {
        // Filter out SOM and ensure proper quantity parsing
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
      setState(() {
        _users = users;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Future<void> _showAddCurrencyDialog(BuildContext context) async {
    _newCurrencyCodeController.clear();
    _quantityController.clear();

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
      body:
          _showCurrencyManagement
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
      ],
    );
  }

  Widget _buildCurrencyManagement() {
    // Separate SOM from other currencies
    final somCurrency = _currencies.firstWhere(
      (currency) => currency.code == 'SOM',
      orElse:
          () => CurrencyModel(
            code: 'SOM',
            quantity: 0.0,
            updatedAt: DateTime.now(),
          ),
    );

    final otherCurrencies =
        _currencies.where((currency) => currency.code != 'SOM').toList();

    return Column(
      children: [
        AppBar(
          title: const Text('Currency Management'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _showCurrencyManagement = false;
              });
            },
          ),
        ),
        Expanded(
          child:
              _currencies.isEmpty
                  ? const Center(
                    child: Text(
                      'No currencies available',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                  : ListView(
                    children: [
                      // SOM Card - Main Currency
                      Card(
                        margin: const EdgeInsets.all(8),
                        color: Colors.blue.shade50,
                        child: ListTile(
                          title: const Text(
                            'SOM (Main Currency)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quantity: ${NumberFormat.currency(decimalDigits: 2, symbol: '').format(somCurrency.quantity)}',
                              ),
                              Text(
                                'Last updated: ${DateFormat('yyyy-MM-dd HH:mm').format(somCurrency.updatedAt)}',
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.lock, color: Colors.grey),
                        ),
                      ),

                      // Other Currencies
                      ...otherCurrencies.map((currency) {
                        final formattedQuantity = NumberFormat.currency(
                          decimalDigits: 2,
                          symbol: '',
                        ).format(currency.quantity);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            title: Text(currency.code),
                            subtitle: Text(
                              'Quantity: $formattedQuantity\n'
                              'Last updated: ${DateFormat('yyyy-MM-dd HH:mm').format(currency.updatedAt)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed:
                                  () => _deleteCurrency(
                                    currency.id,
                                    currency.code,
                                  ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
        ),
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
        AppBar(
          title: const Text('User Management'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _showUserManagement = false;
              });
            },
          ),
        ),
        Expanded(
          child:
              _users.isEmpty
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
                              user.role == 'admin'
                                  ? Colors.orange
                                  : Colors.blue,
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
                          'Created: ${DateFormat('yyyy-MM-dd').format(user.createdAt)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteUser(user.id, user.username),
                        ),
                      );
                    },
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

  @override
  void dispose() {
    _newCurrencyCodeController.dispose();
    _quantityController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _roleController.dispose();
    super.dispose();
  }
}
