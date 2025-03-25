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
  final TextEditingController _quantityController = TextEditingController();
  bool _showCurrencyManagement = false;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
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
                      // Format quantity with 2 decimal places
                      final formattedQuantity = NumberFormat.currency(
                        decimalDigits: 2,
                        symbol: '',
                      ).format(currency.quantity);

                      return ListTile(
                        title: Text(currency.code),
                        subtitle: Text(
                          'Quantity: $formattedQuantity\n'
                          'Last updated: ${DateFormat('yyyy-MM-dd HH:mm').format(currency.updatedAt)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed:
                              () => _deleteCurrency(currency.id, currency.code),
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
    _quantityController.dispose();
    super.dispose();
  }
}
