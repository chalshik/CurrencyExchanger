import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models/company.dart';

class CompanyManagementScreen extends StatefulWidget {
  const CompanyManagementScreen({super.key});

  @override
  State<CompanyManagementScreen> createState() => _CompanyManagementScreenState();
}

class _CompanyManagementScreenState extends State<CompanyManagementScreen> {
  final dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  List<CompanyModel> _companies = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final companies = await dbHelper.getAllCompanies();
      setState(() {
        _companies = companies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading companies: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCompany(String companyId, String companyName) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "$companyName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await dbHelper.deleteCompany(companyId);
      
      if (success) {
        // Reload the companies list
        await _loadCompanies();
        
        if (!mounted) return;
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Company "$companyName" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to delete company';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error deleting company: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _showCreateCompanyDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateCompanyDialog(),
    ).then((value) {
      if (value == true) {
        // Reload companies if a new one was created
        _loadCompanies();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Management'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadCompanies,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _companies.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.business,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No companies yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create your first company to get started',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showCreateCompanyDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Company'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCompanies,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _companies.length,
                        itemBuilder: (context, index) {
                          final company = _companies[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              title: Text(
                                company.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('ID: ${company.id}'),
                              leading: const CircleAvatar(
                                backgroundColor: Colors.deepPurple,
                                child: Icon(
                                  Icons.business,
                                  color: Colors.white,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteCompany(
                                  company.id!,
                                  company.name,
                                ),
                              ),
                              onTap: () {
                                // View company details or navigate to company-specific page
                                // This could be implemented later
                              },
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: !_isLoading && _errorMessage.isEmpty
          ? FloatingActionButton(
              onPressed: _showCreateCompanyDialog,
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class CreateCompanyDialog extends StatefulWidget {
  const CreateCompanyDialog({super.key});

  @override
  State<CreateCompanyDialog> createState() => _CreateCompanyDialogState();
}

class _CreateCompanyDialogState extends State<CreateCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  final dbHelper = DatabaseHelper.instance;

  @override
  void dispose() {
    _companyNameController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createCompany() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await dbHelper.createCompany(
        _companyNameController.text.trim(),
        _adminUsernameController.text.trim(),
        _adminPasswordController.text.trim(),
      );

      if (!mounted) return;
      
      // Close dialog and return success
      Navigator.of(context).pop(true);
      
      // Show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Company "${_companyNameController.text.trim()}" created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        
        // Parse the error message to make it more user-friendly
        String errorMsg = e.toString();
        
        // Check for Firebase Auth errors
        if (errorMsg.contains('firebase_auth')) {
          if (errorMsg.contains('invalid-email')) {
            errorMsg = 'Invalid email format. Please use only letters and numbers for username and company name.';
          } else if (errorMsg.contains('email-already-in-use')) {
            errorMsg = 'Administrator email is already in use. Please choose a different username.';
          } else if (errorMsg.contains('weak-password')) {
            errorMsg = 'Password is too weak. Please use a stronger password.';
          }
        } else if (errorMsg.contains('Company with this name already exists')) {
          errorMsg = 'A company with this name already exists. Please choose a different name.';
        }
        
        _errorMessage = errorMsg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Company'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name',
                  border: OutlineInputBorder(),
                  helperText: 'Use only letters, numbers, and spaces',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a company name';
                  }
                  // Allow letters, numbers, and spaces, but warn about special characters
                  if (value.contains(RegExp(r'[^\w\s]'))) {
                    return 'Company name should only contain letters, numbers, and spaces';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Admin User',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminUsernameController,
                decoration: const InputDecoration(
                  labelText: 'Admin Username',
                  border: OutlineInputBorder(),
                  helperText: 'Use only letters, numbers, and spaces',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter admin username';
                  }
                  // Allow letters, numbers, and spaces, but warn about special characters
                  if (value.contains(RegExp(r'[^\w\s]'))) {
                    return 'Username should only contain letters, numbers, and spaces';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adminPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Admin Password',
                  border: OutlineInputBorder(),
                  helperText: 'Must be at least 6 characters',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter admin password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createCompany,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
} 