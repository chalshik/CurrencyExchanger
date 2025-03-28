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
    // Check if we're on a tablet in landscape mode
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width >= 600;
    final isLandscape = screenSize.width > screenSize.height;
    final isWideTablet = isTablet && isLandscape;
    
    return Scaffold(
      body: Column(
        children: [
          // Date Range Selector with filter icons
          Padding(
            padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: isWideTablet
                ? _buildTabletFilters()
                : _buildMobileFilters(),
          ),
          // Net Balance Display
          _buildNetBalanceDisplay(),
          // History Entries List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _historyEntries.isEmpty
                    ? _buildEmptyHistoryMessage()
                    : isWideTablet
                        ? _buildTabletHistoryTable()
                        : _buildMobileHistoryList(),
          ),
        ],
      ),
    );
  }
  
  // Tablet-optimized row of filter controls
  Widget _buildTabletFilters() {
    return Row(
      children: [
        // From date
        Expanded(
          flex: 3,
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
        // To date
        Expanded(
          flex: 3,
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
        const SizedBox(width: 8),
        // Currency dropdown
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                hint: const Text('Currency'),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('All Currencies'),
                  ),
                  ..._currencyCodes.map((String currency) {
                    return DropdownMenuItem<String>(
                      value: currency,
                      child: Text(currency),
                    );
                  }).toList(),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _selectedCurrency = value;
                  });
                  _loadHistory();
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Operation type dropdown
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedOperationType,
                hint: const Text('Type'),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('All Types'),
                  ),
                  ..._operationTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _selectedOperationType = value;
                  });
                  _loadHistory();
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Reset button
        IconButton(
          onPressed: _resetFilters,
          icon: const Icon(Icons.refresh),
          tooltip: 'Reset Filters',
          color: Colors.blue.shade700,
        ),
      ],
    );
  }
  
  // Mobile layout for filters
  Widget _buildMobileFilters() {
    return Row(
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
        const SizedBox(width: 8),
        // Filter icon
        InkWell(
          onTap: () => _showFilterDialog(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_selectedCurrency != null && _selectedCurrency!.isNotEmpty) || 
                     (_selectedOperationType != null && _selectedOperationType!.isNotEmpty)
                  ? Colors.blue.shade100
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (_selectedCurrency != null && _selectedCurrency!.isNotEmpty) || 
                       (_selectedOperationType != null && _selectedOperationType!.isNotEmpty)
                    ? Colors.blue.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Icon(
              Icons.filter_list,
              color: (_selectedCurrency != null && _selectedCurrency!.isNotEmpty) || 
                     (_selectedOperationType != null && _selectedOperationType!.isNotEmpty)
                  ? Colors.blue.shade700
                  : Colors.grey.shade600,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
  
  // Enhanced tablet history table with more details
  Widget _buildTabletHistoryTable() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
          dataRowMaxHeight: 60,
          columns: const [
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Currency', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _historyEntries.map((entry) {
            final dateFormat = DateFormat('dd-MM-yyyy HH:mm');
            final formattedDate = dateFormat.format(entry.createdAt);
            final backgroundColor = entry.operationType == 'Purchase'
                ? Colors.red.shade50
                : (entry.operationType == 'Sale' ? Colors.green.shade50 : Colors.blue.shade50);
                
            return DataRow(
              color: MaterialStateProperty.all(backgroundColor),
              cells: [
                DataCell(Text(formattedDate)),
                DataCell(Text(entry.currencyCode)),
                DataCell(Text(entry.operationType)),
                DataCell(Text('${entry.rate.toStringAsFixed(2)}')),
                DataCell(Text('${entry.quantity.toStringAsFixed(2)}')),
                DataCell(
                  Text(
                    '${entry.total.toStringAsFixed(2)} SOM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: entry.operationType == 'Purchase'
                          ? Colors.red.shade700
                          : (entry.operationType == 'Sale' ? Colors.green.shade700 : Colors.blue.shade700),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
  
  // Original mobile list view
  Widget _buildMobileHistoryList() {
    return ListView.builder(
      itemCount: _historyEntries.length,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemBuilder: (context, index) {
        final entry = _historyEntries[index];
        final dateFormat = DateFormat('dd-MM-yyyy HH:mm');
        final formattedDate = dateFormat.format(entry.createdAt);
        
        // Choose background color based on operation type
        Color backgroundColor;
        IconData operationIcon;
        
        if (entry.operationType == 'Purchase') {
          backgroundColor = Colors.red.shade50;
          operationIcon = Icons.arrow_downward;
        } else if (entry.operationType == 'Sale') {
          backgroundColor = Colors.green.shade50;
          operationIcon = Icons.arrow_upward;
        } else {
          backgroundColor = Colors.blue.shade50;
          operationIcon = Icons.account_balance_wallet;
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            tileColor: backgroundColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: 
                entry.operationType == 'Purchase' ? Colors.red.shade100 :
                (entry.operationType == 'Sale' ? Colors.green.shade100 : Colors.blue.shade100),
              child: Icon(
                operationIcon,
                color: 
                  entry.operationType == 'Purchase' ? Colors.red.shade700 :
                  (entry.operationType == 'Sale' ? Colors.green.shade700 : Colors.blue.shade700),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.currencyCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${entry.total.toStringAsFixed(2)} SOM',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: entry.operationType == 'Purchase'
                        ? Colors.red.shade700
                        : (entry.operationType == 'Sale' ? Colors.green.shade700 : Colors.blue.shade700),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.operationType,
                      style: TextStyle(
                        color: entry.operationType == 'Purchase'
                            ? Colors.red.shade700
                            : (entry.operationType == 'Sale' ? Colors.green.shade700 : Colors.blue.shade700),
                      ),
                    ),
                    Text(
                      'Amount: ${entry.quantity.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Rate: ${entry.rate.toStringAsFixed(2)}  |  $formattedDate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Net balance display widget
  Widget _buildNetBalanceDisplay() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Net SOM Balance:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          Text(
            '${_netBalance.toString()} SOM',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Empty history message widget
  Widget _buildEmptyHistoryMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No History Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no transactions matching your filters',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // Show filter dialog for mobile view
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Currency dropdown
            DropdownButtonFormField<String>(
              value: _selectedCurrency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('All Currencies'),
                ),
                ..._currencyCodes.map((String currency) {
                  return DropdownMenuItem<String>(
                    value: currency,
                    child: Text(currency),
                  );
                }).toList(),
              ],
              onChanged: (String? value) {
                setState(() {
                  _selectedCurrency = value;
                });
              },
            ),
            const SizedBox(height: 16),
            // Operation type dropdown
            DropdownButtonFormField<String>(
              value: _selectedOperationType,
              decoration: const InputDecoration(
                labelText: 'Operation Type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('All Types'),
                ),
                ..._operationTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
              ],
              onChanged: (String? value) {
                setState(() {
                  _selectedOperationType = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadHistory();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
