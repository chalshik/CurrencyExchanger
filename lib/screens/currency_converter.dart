import 'package:currency_changer/screens/analytical_screen.dart';
import 'package:currency_changer/screens/history_screen.dart';
import 'package:currency_changer/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';

// Responsive Currency Converter
class ResponsiveCurrencyConverter extends StatelessWidget {
  const ResponsiveCurrencyConverter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return const TabletCurrencyConverterLayout();
        } else {
          return const MobileCurrencyConverterLayout();
        }
      },
    );
  }
}

// Core Converter Logic
class CurrencyConverterCore extends StatefulWidget {
  final bool isWideLayout;

  const CurrencyConverterCore({super.key, this.isWideLayout = false});

  @override
  State<CurrencyConverterCore> createState() => _CurrencyConverterCoreState();
}

class _CurrencyConverterCoreState extends State<CurrencyConverterCore> {
  final TextEditingController _currencyController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String _selectedCurrency = 'USD';
  String _operationType = 'Purchase';
  double _totalSum = 0.0;
  List<Map<String, dynamic>> _operationHistory = [];
  List<String> _currencies = [];
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadOperationHistory();
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    try {
      final currencyModels = await _databaseHelper.getAllCurrencies();
      setState(() {
        // Filter out SOM from the currency list
        _currencies =
            currencyModels
                .where((c) => c.code != 'SOM')
                .map((c) => c.code)
                .toList();

        // Set default currency to first one if available
        _selectedCurrency = _currencies.isNotEmpty ? _currencies.first : '';
      });
    } catch (e) {
      setState(() {
        _currencies = [];
        _selectedCurrency = '';
      });
      _showBriefNotification(context, 'Error loading currencies', Colors.red);
    }
  }

  Future<void> _loadOperationHistory() async {
    try {
      final historyEntries = await _databaseHelper.getHistoryEntries(limit: 10);
      setState(() {
        _operationHistory =
            historyEntries
                .map(
                  (entry) => {
                    'currency': entry.currencyCode,
                    'value': entry.rate,
                    'quantity': entry.quantity,
                    'total': entry.total,
                    'type': entry.operationType,
                    'date': entry.createdAt,
                  },
                )
                .toList();
      });
    } catch (e) {
      _showBriefNotification(context, 'Error loading history', Colors.red);
    }
  }

  void _calculateTotal() {
    if (_currencyController.text.isNotEmpty &&
        _quantityController.text.isNotEmpty) {
      double currencyValue = double.parse(_currencyController.text);
      double quantity = double.parse(_quantityController.text);
      setState(() {
        _totalSum = currencyValue * quantity;
      });
    }
  }

  void _showBriefNotification(
    BuildContext context,
    String message,
    Color color,
  ) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 1), () {
      overlayEntry.remove();
    });
  }

  Widget _buildCurrencyInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _operationType == 'Purchase'
              ? 'Buy Rate (SOM per 1 $_selectedCurrency)'
              : 'Sell Rate (SOM per 1 $_selectedCurrency)',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _currencyController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Exchange Rate',
            hintText:
                _operationType == 'Purchase'
                    ? 'Enter buy rate'
                    : 'Enter sell rate',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: const Icon(Icons.attach_money, color: Colors.blue),
          ),
          onChanged: (_) => _calculateTotal(),
        ),
        const SizedBox(height: 16),
        Text(
          'Amount to ${_operationType == 'Purchase' ? 'buy' : 'sell'}',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity',
            hintText: 'Enter amount in $_selectedCurrency',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: const Icon(Icons.numbers, color: Colors.blue),
          ),
          onChanged: (_) => _calculateTotal(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTotalSumCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _operationType == 'Purchase'
                  ? 'Total SOM to pay'
                  : 'Total SOM to receive',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '${_totalSum.toStringAsFixed(2)} SOM',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'for ${_quantityController.text.isEmpty ? '0' : _quantityController.text} $_selectedCurrency',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySelector() {
    if (_currencies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No currencies available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Currency:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _currencies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final currency = _currencies[index];
              return ChoiceChip(
                label: Text(currency),
                selected: _selectedCurrency == currency,
                onSelected: (selected) {
                  setState(() {
                    _selectedCurrency = currency;
                    _calculateTotal();
                  });
                },
                selectedColor: Colors.blue,
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color:
                      _selectedCurrency == currency
                          ? Colors.white
                          : Colors.black,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOperationTypeButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _operationType = 'Purchase';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _operationType == 'Purchase'
                      ? Colors.green
                      : Colors.green.shade50,
              foregroundColor:
                  _operationType == 'Purchase' ? Colors.white : Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Purchase'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _operationType = 'Sale';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _operationType == 'Sale' ? Colors.red : Colors.red.shade50,
              foregroundColor:
                  _operationType == 'Sale' ? Colors.white : Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sale'),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddSomDialog() async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add SOM Balance'),
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
                      await _databaseHelper.addToSomBalance(amount);
                      print("this one2");
                      print(amount);
                      Navigator.pop(context);
                      _showBriefNotification(
                        context,
                        'Successfully added $amount SOM',
                        Colors.green,
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      _showBriefNotification(
                        context,
                        'Failed to add SOM: ${e.toString()}',
                        Colors.red,
                      );
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Widget _buildFinishButton() {
    return ElevatedButton(
      onPressed: _finishOperation,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Finish Operation', style: TextStyle(fontSize: 16)),
    );
  }

  Future<void> _finishOperation() async {
    if (_currencyController.text.isEmpty || _quantityController.text.isEmpty) {
      _showBriefNotification(
        context,
        'Please enter rate and amoun',
        Colors.orange,
      );
      return;
    }
    if (_currencies.length == 0) {
      _showBriefNotification(
        context,
        'No currencies available for exchange',
        Colors.orange,
      );
      return;
    }

    try {
      final rate = double.parse(_currencyController.text);
      final quantity = double.parse(_quantityController.text);
      final totalSom = rate * quantity;

      if (_operationType == 'Purchase') {
        // Check if we have enough SOM to buy the currency
        final hasEnough = await _databaseHelper.hasEnoughSomForPurchase(
          totalSom,
        );
        if (!hasEnough) {
          _showBriefNotification(
            context,
            'Not enough SOM for this purchase',
            Colors.red,
          );
          return;
        }
      } else {
        // Check if we have enough of the currency to sell
        final hasEnough = await _databaseHelper.hasEnoughCurrencyToSell(
          _selectedCurrency,
          quantity,
        );
        if (!hasEnough) {
          _showBriefNotification(
            context,
            'Not enough $_selectedCurrency to sell',
            Colors.red,
          );
          return;
        }
      }

      // Proceed with the operation
      await _databaseHelper.performCurrencyExchange(
        currencyCode: _selectedCurrency,
        operationType: _operationType,
        rate: rate,
        quantity: quantity,
      );

      setState(() {
        _currencyController.clear();
        _quantityController.clear();
        _totalSum = 0.0;
      });

      _showBriefNotification(
        context,
        '$_operationType operation completed',
        _operationType == 'Purchase' ? Colors.green : Colors.red,
      );

      await _loadOperationHistory();
    } catch (e) {
      _showBriefNotification(
        context,
        'Operation failed: ${e.toString()}',
        Colors.red,
      );
    }
  }

  Widget _buildAddSomButton() {
    return ElevatedButton.icon(
      onPressed: _showAddSomDialog,
      icon: const Icon(Icons.add),
      label: const Text('Add SOM'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.blue.shade800,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _operationType == 'Purchase'
                  ? 'Buy Foreign Currency'
                  : 'Sell Foreign Currency',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildCurrencyInputSection(),
            const SizedBox(height: 16),
            _buildTotalSumCard(),
            const SizedBox(height: 16),
            // Add SOM button - only shown in wide layout
            if (widget.isWideLayout) ...[
              _buildAddSomButton(),
              const SizedBox(height: 16),
            ],
            _buildCurrencySelector(),
            const SizedBox(height: 24),
            Text(
              'Operation Type:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildOperationTypeButtons(),
            const SizedBox(height: 24),
            _buildFinishButton(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currencyController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}

// Mobile Layout
class MobileCurrencyConverterLayout extends StatefulWidget {
  const MobileCurrencyConverterLayout({super.key});

  @override
  State<MobileCurrencyConverterLayout> createState() =>
      _MobileCurrencyConverterLayoutState();
}

class _MobileCurrencyConverterLayoutState
    extends State<MobileCurrencyConverterLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const CurrencyConverterCore(),
    const HistoryScreen(),
    const AnalyticsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        title: const Text(
          'Currency Converter',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton(
                onPressed: () {
                  final converterCore =
                      _pages[_selectedIndex] as CurrencyConverterCore;
                  final coreState =
                      converterCore.createState()
                          as _CurrencyConverterCoreState;
                  coreState._showAddSomDialog();
                },
                backgroundColor: Colors.blue,
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100,
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.blue.shade700,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: 'Analytics',
            ),
          ],
        ),
      ),
    );
  }
}

// Tablet Layout
class TabletCurrencyConverterLayout extends StatefulWidget {
  const TabletCurrencyConverterLayout({super.key});

  @override
  State<TabletCurrencyConverterLayout> createState() =>
      _TabletCurrencyConverterLayoutState();
}

class _TabletCurrencyConverterLayoutState
    extends State<TabletCurrencyConverterLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const CurrencyConverterCore(isWideLayout: true),
    const HistoryScreen(),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        title: const Text(
          'Currency Converter',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _pages[_selectedIndex],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100,
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.blue.shade700,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.currency_exchange, size: 30),
                label: 'Converter',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history, size: 30),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics, size: 30),
                label: 'Analytics',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings, size: 30),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
