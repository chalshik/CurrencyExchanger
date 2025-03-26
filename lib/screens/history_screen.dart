import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../models/history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<HistoryModel> _history = [];
  bool _isLoading = true;
  int _netBalance = 0;

  // Date filters
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30)); // Show last 30 days by default
  DateTime _toDate = DateTime.now();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  // Other filters
  String? _selectedCurrency;
  String? _selectedOperationType;
  List<String> _currencyCodes = [];
  List<String> _operationTypes = [];

  @override
  void initState() {
    super.initState();
    _fromDateController.text = DateFormat('yyyy-MM-dd').format(_fromDate);
    _toDateController.text = DateFormat('yyyy-MM-dd').format(_toDate);
    _loadFilters();
    _loadHistory();
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  // Public method to refresh history entries
  void loadHistoryEntries() {
    _loadHistory();
  }

  Future<void> _loadFilters() async {
    try {
      final currencies = await _dbHelper.getHistoryCurrencyCodes();
      final operations = await _dbHelper.getHistoryOperationTypes();

      if (mounted) {
        setState(() {
          _currencyCodes = currencies;
          _operationTypes = operations;
        });
      }
    } catch (e) {
      debugPrint('Error loading filters: $e');
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    // Adjust toDate to include the entire day
    final adjustedToDate = DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
      23,
      59,
      59,
    );

    try {
      final history = await _dbHelper.getFilteredHistoryByDate(
        fromDate: _fromDate,
        toDate: adjustedToDate,
        currencyCode: _selectedCurrency,
        operationType: _selectedOperationType,
      );

      // Calculate net balance
      int balance = 0;
      for (var entry in history) {
        balance +=
            entry.operationType == 'Purchase'
                ? entry.total.toInt()
                : -entry.total.toInt();
      }

      if (mounted) {
        setState(() {
          _history = history;
          _netBalance = balance;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          _fromDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _toDate = picked;
          _toDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
      // Load history immediately after date change
      _loadHistory();
    }
  }

  void _resetFilters() {
    if (!mounted) return;
    
    setState(() {
      _fromDate = DateTime.now().subtract(const Duration(days: 30));
      _toDate = DateTime.now();
      _fromDateController.text = DateFormat('yyyy-MM-dd').format(_fromDate);
      _toDateController.text = DateFormat('yyyy-MM-dd').format(_toDate);
      _selectedCurrency = null;
      _selectedOperationType = null;
    });
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operation History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterDialog,
          ),
          if (_selectedCurrency != null ||
              _selectedOperationType != null ||
              _fromDate != DateTime.now().subtract(const Duration(days: 30)) ||
              _toDate != DateTime.now())
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: _resetFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fromDateController,
                    decoration: const InputDecoration(
                      labelText: 'From',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _toDateController,
                    decoration: const InputDecoration(
                      labelText: 'To',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
          ),
          
          
          // History List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _history.isEmpty
                    ? const Center(child: Text('No operations found'))
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final entry = _history[index];
                            return _buildHistoryItem(entry);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(HistoryModel entry) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          '${entry.operationType} ${entry.quantity.toInt()} ${entry.currencyCode}',
          style: TextStyle(
            color:
                entry.operationType == 'Purchase' ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate: ${entry.rate.toStringAsFixed(6)}'),
            Text('Total: ${entry.total.toInt()}'),
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(entry.createdAt),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    // Save initial filter state to check for changes later
    final initialCurrency = _selectedCurrency;
    final initialOperationType = _selectedOperationType;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Currency filter
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Currencies'),
                      ),
                      ..._currencyCodes.map((currency) {
                        return DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        _selectedCurrency = value;
                      });
                      // Update the parent state too
                      setState(() {
                        _selectedCurrency = value;
                      });
                      // Load data immediately
                      _loadHistory();
                    },
                  ),
                  const SizedBox(height: 16),
                  // Operation type filter
                  DropdownButtonFormField<String>(
                    value: _selectedOperationType,
                    decoration: const InputDecoration(
                      labelText: 'Operation Type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Operations'),
                      ),
                      ..._operationTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        _selectedOperationType = value;
                      });
                      // Update the parent state too
                      setState(() {
                        _selectedOperationType = value;
                      });
                      // Load data immediately
                      _loadHistory();
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _selectedCurrency = null;
                        _selectedOperationType = null;
                      });
                      // Reset in parent state too
                      setState(() {
                        _selectedCurrency = null;
                        _selectedOperationType = null;
                      });
                      // Load data immediately
                      _loadHistory();
                      Navigator.pop(context);
                    },
                    child: const Text('Reset Filters'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
