import 'package:currency_changer/screens/analytical_screen.dart';
import 'package:currency_changer/screens/history_screen.dart';
import 'package:currency_changer/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';

// Kyrgyzstan Time Utility
DateTime getKyrgyzstanTime() {
  final now = DateTime.now().toUtc();
  return now.add(const Duration(hours: 6));
}

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
        if (currencyModels.isNotEmpty) {
          _currencies = currencyModels.map((c) => c.code).toList();
          // Set default currency to first one if available
          _selectedCurrency = _currencies.isNotEmpty ? _currencies.first : '';
        } else {
          _currencies = []; // Empty list instead of default currencies
          _selectedCurrency = '';
        }
      });
    } catch (e) {
      setState(() {
        _currencies = []; // Empty list instead of default currencies
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

  // Method to show brief notification
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

  // Build Currency Input Section
  Widget _buildCurrencyInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _currencyController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Currency Value',
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
        TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity',
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

  // Build Total Sum Card
  Widget _buildTotalSumCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Total Amount',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '${_totalSum.toStringAsFixed(2)} $_selectedCurrency',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Currency Selector
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

    return SizedBox(
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
              });
            },
            selectedColor: Colors.blue,
            backgroundColor: Colors.grey.shade100,
            labelStyle: TextStyle(
              color:
                  _selectedCurrency == currency ? Colors.white : Colors.black,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }

  // Build Operation Type Buttons
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

  // Build Finish Button
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

  // Finish Operation Method
  Future<void> _finishOperation() async {
    if (_currencyController.text.isNotEmpty &&
        _quantityController.text.isNotEmpty) {
      try {
        double rate = double.parse(_currencyController.text);
        double quantity = double.parse(_quantityController.text);

        await _databaseHelper.performCurrencyOperation(
          currencyCode: _selectedCurrency,
          operationType: _operationType,
          rate: rate,
          quantity: quantity,
          total: _totalSum,
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
            _buildCurrencyInputSection(),
            const SizedBox(height: 16),
            _buildTotalSumCard(),
            const SizedBox(height: 24),
            Text(
              'Select Currency:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
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

// Mobile Layout with Enhanced Design
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
        title: Text(
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  DateFormat('HH:mm:ss').format(getKyrgyzstanTime()),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: _buildEnhancedBottomNavBar(),
    );
  }

  Widget _buildEnhancedBottomNavBar() {
    return Container(
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
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}

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
        title: Text(
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  DateFormat('HH:mm:ss').format(getKyrgyzstanTime()),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
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
      bottomNavigationBar: _buildTabletBottomNavBar(),
    );
  }

  Widget _buildTabletBottomNavBar() {
    return Container(
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
    );
  }
}
