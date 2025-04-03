import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models/user.dart';

class UserManagementWidget extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final bool isAdmin;

  const UserManagementWidget({
    super.key,
    required this.dbHelper,
    required this.isAdmin,
  });

  @override
  State<UserManagementWidget> createState() => _UserManagementWidgetState();
}

class _UserManagementWidgetState extends State<UserManagementWidget> {
  List<UserModel> _users = [];
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await widget.dbHelper.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Future<void> _showAddUserDialog(BuildContext context) async {
    _usernameController.clear();
    _passwordController.clear();
    _roleController.clear();

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
              TextField(
                controller: _roleController,
                decoration: const InputDecoration(
                  labelText: 'Role (admin/user)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final username = _usernameController.text;
                final password = _passwordController.text;
                final role = _roleController.text.toLowerCase();

                if (username.isEmpty || password.isEmpty || role.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                if (role != 'admin' && role != 'user') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Role must be either admin or user'),
                    ),
                  );
                  return;
                }

                try {
                  await widget.dbHelper.createUser(
                    UserModel(
                      username: username,
                      password: password,
                      role: role,
                    ),
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  _loadUsers();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding user: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'User Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (widget.isAdmin)
              ElevatedButton(
                onPressed: () => _showAddUserDialog(context),
                child: const Text('Add User'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return Card(
                child: ListTile(
                  title: Text(user.username),
                  subtitle: Text('Role: ${user.role}'),
                  trailing:
                      widget.isAdmin && user.role != 'admin'
                          ? IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              try {
                                if (user.id != null) {
                                  await widget.dbHelper.deleteUser(user.id!);
                                  _loadUsers();
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error deleting user: $e'),
                                  ),
                                );
                              }
                            },
                          )
                          : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
