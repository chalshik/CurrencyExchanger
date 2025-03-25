import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../models/currency.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<CurrencyModel> _currencies = [];
  final TextEditingController _newCurrencyCodeController =
      TextEditingController();
  bool _showCurrencyManagement = false;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    final currencies = await _dbHelper.getAllCurrencies();
    setState(() {
      _currencies = currencies;
    });
  }

  Future<void> _showAddCurrencyDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Currency'),
          content: TextField(
            controller: _newCurrencyCodeController,
            decoration: const InputDecoration(
              labelText: 'Currency Code (e.g. USD)',
              border: OutlineInputBorder(),
            ),
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_newCurrencyCodeController.text.isNotEmpty) {
                  try {
                    final newCurrency = CurrencyModel(
                      code: _newCurrencyCodeController.text,
                      quantity: 0.0, // Default to zero
                    );

                    await _dbHelper.insertCurrency(newCurrency);
                    await _loadCurrencies();
                    _newCurrencyCodeController.clear();
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

  Future<void> _deleteCurrency(int? id) async {
    if (id == null) return;

    try {
      await _dbHelper.deleteCurrency(id);
      await _loadCurrencies();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting currency: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body:
          _showCurrencyManagement
              ? _buildCurrencyManagement()
              : _buildSettings(),
    );
  }

  Widget _buildSettings() {
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
        // Add other settings options here
        const ListTile(
          title: Text('Appearance'),
          leading: Icon(Icons.color_lens),
          trailing: Icon(Icons.arrow_forward_ios),
        ),
        const ListTile(
          title: Text('Notifications'),
          leading: Icon(Icons.notifications),
          trailing: Icon(Icons.arrow_forward_ios),
        ),
      ],
    );
  }

  Widget _buildCurrencyManagement() {
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
                  : ListView.builder(
                    itemCount: _currencies.length,
                    itemBuilder: (context, index) {
                      final currency = _currencies[index];
                      return ListTile(
                        title: Text(currency.code),
                        subtitle: Text(
                          'Quantity: ${currency.quantity}\n'
                          'Last updated: ${DateFormat('yyyy-MM-dd HH:mm').format(currency.updatedAt)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCurrency(currency.id),
                        ),
                      );
                    },
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

  @override
  void dispose() {
    _newCurrencyCodeController.dispose();
    super.dispose();
  }
}
