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
  List<HistoryModel> _historyEntries = [];
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
    _fromDateController.text = DateFormat('dd-MM-yy').format(_fromDate);
    _toDateController.text = DateFormat('dd-MM-yy').format(_toDate);
    _loadFilters();
    _loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure history is always refreshed when the screen becomes visible
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

    try {
      final fromDate = DateFormat('dd-MM-yy').parse(_fromDateController.text);
      final toDate = DateFormat('dd-MM-yy').parse(_toDateController.text);
      
      // Add 23:59:59 to the toDate to include the entire day
      final adjustedToDate = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

      // Apply filters if they exist
      final entries = await _dbHelper.getFilteredHistoryByDate(
        fromDate: fromDate,
        toDate: adjustedToDate,
        currencyCode: _selectedCurrency == null || _selectedCurrency!.isEmpty ? null : _selectedCurrency,
        operationType: _selectedOperationType == null || _selectedOperationType!.isEmpty ? null : _selectedOperationType,
      );

      if (!mounted) return;
      setState(() {
        _historyEntries = entries;
        _isLoading = false;
        _calculateTotals();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateTotals() {
    int balance = 0;
    for (var entry in _historyEntries) {
      if (entry.operationType == 'Purchase') {
        balance -= entry.total.toInt(); // Deduct for purchases
      } else if (entry.operationType == 'Sale') {
        balance += entry.total.toInt(); // Add for sales
      } else if (entry.operationType == 'Deposit') {
        balance += entry.total.toInt(); // Add for deposits
      }
    }
    _netBalance = balance;
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
          _fromDateController.text = DateFormat('dd-MM-yy').format(picked);
        } else {
          _toDate = picked;
          _toDateController.text = DateFormat('dd-MM-yy').format(picked);
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
      _fromDateController.text = DateFormat('dd-MM-yy').format(_fromDate);
      _toDateController.text = DateFormat('dd-MM-yy').format(_toDate);
      _selectedCurrency = null;
      _selectedOperationType = null;
    });
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Date Range Selector with filter icons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _fromDateController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'From',
                      labelStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _toDateController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'To',
                      labelStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, false),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.filter_alt, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _showFilterDialog,
                  tooltip: 'Filter',
                ),
                if (_selectedCurrency != null ||
                    _selectedOperationType != null ||
                    _fromDate != DateTime.now().subtract(const Duration(days: 30)) ||
                    _toDate != DateTime.now())
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _resetFilters,
                    tooltip: 'Reset Filters',
                  ),
              ],
            ),
          ),
          
          // Balance summary
          if (!_isLoading && _historyEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                color: _netBalance >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Net Balance: ${_netBalance.abs()} SOM',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _netBalance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _netBalance >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: _netBalance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const Divider(height: 1),
          
          // History List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _historyEntries.isEmpty
                    ? const Center(child: Text('No operations found'))
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          itemCount: _historyEntries.length,
                          itemBuilder: (context, index) {
                            final entry = _historyEntries[index];
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
              DateFormat('dd-MM-yy HH:mm').format(entry.createdAt),
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
