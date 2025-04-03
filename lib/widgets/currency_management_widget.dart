import 'package:flutter/material.dart';
import 'dart:async';
import '../db_helper.dart';
import '../models/currency.dart';

class CurrencyManagementWidget extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final bool isAdmin;

  const CurrencyManagementWidget({
    super.key,
    required this.dbHelper,
    required this.isAdmin,
  });

  @override
  State<CurrencyManagementWidget> createState() =>
      _CurrencyManagementWidgetState();
}

class _CurrencyManagementWidgetState extends State<CurrencyManagementWidget> {
  List<CurrencyModel> _currencies = [];
  final TextEditingController _newCurrencyCodeController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _defaultBuyRateController =
      TextEditingController();
  final TextEditingController _defaultSellRateController =
      TextEditingController();
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _newCurrencyCodeController.dispose();
    _quantityController.dispose();
    _defaultBuyRateController.dispose();
    _defaultSellRateController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _loadCurrencies();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadCurrencies() async {
    try {
      final currencies = await widget.dbHelper.getAllCurrencies();
      if (!mounted) return;
      setState(() {
        _currencies =
            currencies.map((currency) {
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

  Future<void> _showAddCurrencyDialog(BuildContext context) async {
    _newCurrencyCodeController.clear();
    _quantityController.text = "0";
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
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _defaultSellRateController,
                decoration: const InputDecoration(
                  labelText: 'Default Sell Rate',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
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
                final code = _newCurrencyCodeController.text.toUpperCase();
                final quantity =
                    double.tryParse(_quantityController.text) ?? 0.0;
                final buyRate =
                    double.tryParse(_defaultBuyRateController.text) ?? 0.0;
                final sellRate =
                    double.tryParse(_defaultSellRateController.text) ?? 0.0;

                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a currency code'),
                    ),
                  );
                  return;
                }

                try {
                  await widget.dbHelper.insertCurrency(
                    CurrencyModel(
                      code: code,
                      quantity: quantity,
                      defaultBuyRate: buyRate,
                      defaultSellRate: sellRate,
                    ),
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  _loadCurrencies();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding currency: $e')),
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
              'Currency Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (widget.isAdmin)
              ElevatedButton(
                onPressed: () => _showAddCurrencyDialog(context),
                child: const Text('Add Currency'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _currencies.length,
            itemBuilder: (context, index) {
              final currency = _currencies[index];
              return Card(
                child: ListTile(
                  title: Text(currency.code ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quantity: ${currency.quantity}'),
                      Text('Buy Rate: ${currency.defaultBuyRate}'),
                      Text('Sell Rate: ${currency.defaultSellRate}'),
                    ],
                  ),
                  trailing:
                      widget.isAdmin
                          ? IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              try {
                                if (currency.id != null) {
                                  await widget.dbHelper.deleteCurrency(
                                    currency.id!,
                                  );
                                  _loadCurrencies();
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error deleting currency: $e',
                                    ),
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
