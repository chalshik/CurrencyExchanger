import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../models/currency.dart';
import '../models/history.dart';
import 'history_screen.dart';
import 'settings.dart';
import 'analytics_screen.dart';
import 'statistics_screen.dart';
import 'login_screen.dart'; // Import to access currentUser

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
  final _databaseHelper = DatabaseHelper.instance;
  List<CurrencyModel> _currencies = [];
  List<HistoryModel> _recentHistory = [];
  final TextEditingController _currencyController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String _selectedCurrency = '';
  String _operationType = 'Purchase';
  double _totalSum = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen becomes visible
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadCurrencies();
    await _loadOperationHistory();
  }

  Future<void> _loadCurrencies() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final currencies = await _databaseHelper.getAllCurrencies();

      if (!mounted) return;
      setState(() {
        _currencies = currencies;
        _isLoading = false;

        // Update selected currency if needed
        if (_selectedCurrency.isEmpty && currencies.isNotEmpty) {
          for (var currency in currencies) {
            if (currency.code != 'SOM') {
              _selectedCurrency = currency.code!;
              break;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading currencies: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOperationHistory() async {
    try {
      final historyEntries = await _databaseHelper.getHistoryEntries(limit: 10);
      setState(() {
        _recentHistory = historyEntries;
      });
    } catch (e) {
      _showBriefNotification('Error loading history', Colors.red);
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

  // Show brief notification (snackbar)
  void _showBriefNotification(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildCurrencyInputSection() {
    // Get screen width to adjust sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final fontSize = isSmallScreen ? 13.0 : 14.0;
    final iconSize = isSmallScreen ? 18.0 : 24.0;
    final verticalPadding = isSmallScreen ? 12.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _operationType == 'Purchase'
              ? 'Buy Rate (SOM per 1 $_selectedCurrency)'
              : 'Sell Rate (SOM per 1 $_selectedCurrency)',
          style: TextStyle(fontSize: fontSize, color: Colors.grey.shade600),
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
            prefixIcon: Icon(
              Icons.attach_money,
              color: Colors.blue,
              size: iconSize,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: verticalPadding,
            ),
          ),
          onChanged: (_) => _calculateTotal(),
          style: TextStyle(fontSize: fontSize),
        ),
        const SizedBox(height: 16),
        Text(
          'Amount to ${_operationType == 'Purchase' ? 'buy' : 'sell'}',
          style: TextStyle(fontSize: fontSize, color: Colors.grey.shade600),
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
            prefixIcon: Icon(Icons.numbers, color: Colors.blue, size: iconSize),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: verticalPadding,
            ),
          ),
          onChanged: (_) => _calculateTotal(),
          style: TextStyle(fontSize: fontSize),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTotalSumCard() {
    // Get screen width to adjust sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final titleSize = isSmallScreen ? 14.0 : 16.0;
    final valueSize = isSmallScreen ? 24.0 : 28.0;
    final subtitleSize = isSmallScreen ? 12.0 : 14.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          children: [
            Text(
              _operationType == 'Purchase'
                  ? 'Total SOM to pay'
                  : 'Total SOM to receive',
              style: TextStyle(
                fontSize: titleSize,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_totalSum.toStringAsFixed(2)} SOM',
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'for ${_quantityController.text.isEmpty ? '0' : _quantityController.text} $_selectedCurrency',
              style: TextStyle(
                fontSize: subtitleSize,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySelector() {
    // Check screen size to adjust layout accordingly
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Filter out SOM currency for selection
    final availableCurrencies =
        _currencies.where((c) => c.code != 'SOM').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Currency:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        const SizedBox(height: 4),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : availableCurrencies.isEmpty
            ? Center(
              child: Column(
                children: [
                  Text(
                    'No currencies available',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add currencies in Settings',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
            : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    availableCurrencies.map((currency) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            currency.code ?? '',
                            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                          ),
                          selected: _selectedCurrency == currency.code,
                          onSelected: (selected) {
                            if (currency.code != null) {
                              setState(() {
                                _selectedCurrency = currency.code!;
                                _calculateTotal();
                              });
                            }
                          },
                          backgroundColor: Colors.blue.shade50,
                          selectedColor: Colors.blue.shade700,
                          labelStyle: TextStyle(
                            color:
                                _selectedCurrency == currency.code
                                    ? Colors.white
                                    : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
      ],
    );
  }

  Widget _buildOperationTypeButtons() {
    // Get screen width to adjust button size
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final buttonPadding =
        isSmallScreen
            ? const EdgeInsets.symmetric(vertical: 12)
            : const EdgeInsets.symmetric(vertical: 16);
    final buttonTextSize = isSmallScreen ? 14.0 : 16.0;

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
              padding: buttonPadding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Purchase', style: TextStyle(fontSize: buttonTextSize)),
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
              padding: buttonPadding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Sale', style: TextStyle(fontSize: buttonTextSize)),
          ),
        ),
      ],
    );
  }

  Widget _buildFinishButton() {
    // Get screen width to adjust sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final fontSize = isSmallScreen ? 13.0 : 15.0;
    final verticalPadding = isSmallScreen ? 14.0 : 16.0;

    return Container(
      height: isSmallScreen ? 50 : 56,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      child: ElevatedButton(
        onPressed: _finishOperation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.blue.shade200,
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          'Finish Operation',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Future<void> _finishOperation() async {
    if (_currencyController.text.isEmpty || _quantityController.text.isEmpty) {
      _showBriefNotification('Please enter rate and amount', Colors.orange);
      return;
    }
    if (_currencies.isEmpty) {
      _showBriefNotification(
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
        '$_operationType operation completed',
        _operationType == 'Purchase' ? Colors.green : Colors.red,
      );

      // Refresh history and available currencies
      await _loadOperationHistory();
      await _loadCurrencies();
    } catch (e) {
      _showBriefNotification('Operation failed: ${e.toString()}', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check screen size to adjust layout accordingly
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final spacing = isSmallScreen ? 8.0 : 12.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 8.0 : 12.0),
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
                  fontSize: isSmallScreen ? 16 : 18,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing),
              _buildCurrencyInputSection(),
              SizedBox(height: spacing),
              _buildTotalSumCard(),
              SizedBox(height: spacing),
              _buildCurrencySelector(),
              SizedBox(height: spacing),
              Text(
                'Operation Type:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 13 : 15,
                ),
              ),
              SizedBox(height: 4),
              _buildOperationTypeButtons(),
              SizedBox(height: spacing),
              _buildFinishButton(),
            ],
          ),
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
  final _currencyConverterCoreKey = GlobalKey<_CurrencyConverterCoreState>();
  Key _historyScreenKey = GlobalKey();
  // Keys for statistics and analytics screens to force refresh
  Key _statisticsKey = UniqueKey();
  Key _analyticsKey = UniqueKey();

  late List<Widget> _pages;
  late List<BottomNavigationBarItem> _navigationItems;

  @override
  void initState() {
    super.initState();
    _initPages();
    _initNavigationItems();
  }

  void _initPages() {
    // Check if user is admin to determine what pages are available
    final bool isAdmin = currentUser?.role == 'admin';

    // Always include Converter and History screens
    _pages = [
      CurrencyConverterCore(key: _currencyConverterCoreKey),
      HistoryScreen(key: _historyScreenKey),
    ];

    // Add Statistics and Analytics screens only for admin users
    if (isAdmin) {
      _pages.add(StatisticsScreen(key: _statisticsKey));
      _pages.add(AnalyticsScreen(key: _analyticsKey));
    }

    // Add Settings screen for all users
    _pages.add(const SettingsScreen());
  }

  void _initNavigationItems() {
    // Check if user is admin
    final bool isAdmin = currentUser?.role == 'admin';

    // Basic navigation items available to all users
    _navigationItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.currency_exchange),
        label: 'Converter',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: 'History',
      ),
    ];

    // Only add Analytics and Charts options for admin users
    if (isAdmin) {
      _navigationItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Statistics',
        ),
      );

      _navigationItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.pie_chart),
          label: 'Analytics',
        ),
      );
    }

    // Settings available for all users
    _navigationItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;

      // Handle the history screen refresh
      if (index == 2 && _historyScreenKey != null) {
        _historyScreenKey = UniqueKey();
      }

      // For Statistics and Analytics screens, always recreate them with a new key
      // to force a full refresh when they're selected
      if (index == 3) {
        // Statistics screen
        _statisticsKey = UniqueKey();
      } else if (index == 4) {
        // Analytics screen
        _analyticsKey = UniqueKey();
      }

      // Refresh currency data when going to converter screen
      if (index == 0) {
        _loadCurrencyData();
      }
    });
  }

  // Method to refresh currency data in the converter screen
  void _loadCurrencyData() {
    _currencyConverterCoreKey.currentState?._loadCurrencies();
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          // Use a direct widget instead of IndexedStack to ensure screens rebuild
          child: _buildCurrentPage(),
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
            items: _navigationItems,
          ),
        ),
      ),
    );
  }

  // Build the current page directly rather than using IndexedStack
  Widget _buildCurrentPage() {
    // This ensures every page switch fully rebuilds the widget
    return _pages[_selectedIndex];
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
  final _currencyConverterCoreKey = GlobalKey<_CurrencyConverterCoreState>();
  Key _historyScreenKey = GlobalKey();
  // Keys for statistics and analytics screens to force refresh
  Key _statisticsKey = UniqueKey();
  Key _analyticsKey = UniqueKey();

  late List<Widget> _pages;
  late List<BottomNavigationBarItem> _navigationItems;

  @override
  void initState() {
    super.initState();
    _initPages();
    _initNavigationItems();
  }

  void _initPages() {
    // Check if user is admin to determine what pages are available
    final bool isAdmin = currentUser?.role == 'admin';

    // Always include Converter and History screens
    _pages = [
      CurrencyConverterCore(isWideLayout: true, key: _currencyConverterCoreKey),
      HistoryScreen(key: _historyScreenKey),
    ];

    // Add Statistics and Analytics screens only for admin users
    if (isAdmin) {
      _pages.add(StatisticsScreen(key: _statisticsKey));
      _pages.add(AnalyticsScreen(key: _analyticsKey));
    }

    // Add Settings screen for all users
    _pages.add(const SettingsScreen());
  }

  void _initNavigationItems() {
    // Check if user is admin
    final bool isAdmin = currentUser?.role == 'admin';

    // Basic navigation items available to all users
    _navigationItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.currency_exchange, size: 30),
        label: 'Converter',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.history, size: 30),
        label: 'History',
      ),
    ];

    // Only add Analytics and Charts options for admin users
    if (isAdmin) {
      _navigationItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.analytics, size: 30),
          label: 'Statistics',
        ),
      );

      _navigationItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.pie_chart, size: 30),
          label: 'Analytics',
        ),
      );
    }

    // Settings available for all users
    _navigationItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings, size: 30),
        label: 'Settings',
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;

      // Handle the history screen refresh
      if (index == 2 && _historyScreenKey != null) {
        _historyScreenKey = UniqueKey();
      }

      // For Statistics and Analytics screens, always recreate them with a new key
      // to force a full refresh when they're selected
      if (index == 3) {
        // Statistics screen
        _statisticsKey = UniqueKey();
      } else if (index == 4) {
        // Analytics screen
        _analyticsKey = UniqueKey();
      }

      // Refresh currency data when going to converter screen
      if (index == 0) {
        _loadCurrencyData();
      }
    });
  }

  // Method to refresh currency data in the converter screen
  void _loadCurrencyData() {
    _currencyConverterCoreKey.currentState?._loadCurrencies();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions to adjust layout accordingly
    final screenSize = MediaQuery.of(context).size;
    final isWideTablet = screenSize.width > 840;
    final horizontalPadding = isWideTablet ? 24.0 : 16.0;

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
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                // Use a direct widget instead of IndexedStack
                child: _buildCurrentPage(),
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
            items: _navigationItems,
          ),
        ),
      ),
    );
  }

  // Build the current page directly rather than using IndexedStack
  Widget _buildCurrentPage() {
    // This ensures every page switch fully rebuilds the widget
    return _pages[_selectedIndex];
  }
}
