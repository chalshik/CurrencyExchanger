import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Add SystemChrome
import '../db_helper.dart';
import '../models/currency.dart';
import '../models/history.dart';
import 'history_screen.dart';
import 'settings.dart';
import 'analytics_screen.dart';
import 'statistics_screen.dart';
import 'login_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

// Responsive Currency Converter
class ResponsiveCurrencyConverter extends StatelessWidget {
  const ResponsiveCurrencyConverter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 599) {
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

  // Add focus nodes to track which field is active
  final FocusNode _currencyFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();

  // Track which field is currently active for the numpad
  bool _isRateFieldActive = true;

  // Track numpad visibility for tablet portrait mode
  bool _isNumpadVisible = true;

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Set empty values to start with
    _currencyController.text = '';
    _quantityController.text = '';

    // Set up listeners for focus changes
    _currencyFocusNode.addListener(_handleFocusChange);
    _quantityFocusNode.addListener(_handleFocusChange);

    // Add listeners to the text controllers to update total when text changes
    _currencyController.addListener(_calculateTotal);
    _quantityController.addListener(_calculateTotal);

    // Ensure rate field is active initially
    _isRateFieldActive = true;

    // Schedule focus request for after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isWideLayout) {
        // Request focus on rate field
        _currencyFocusNode.requestFocus();
      }
    });
  }

  void _handleFocusChange() {
    setState(() {
      _isRateFieldActive = _currencyFocusNode.hasFocus;
    });
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

        // Update selected currency if needed, but don't auto-fill rate
        if (_selectedCurrency.isEmpty && currencies.isNotEmpty) {
          for (var currency in currencies) {
            if (currency.code != 'SOM') {
              _selectedCurrency = currency.code!;
              // Don't auto-fill rate values
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
    // Convert empty fields to 0
    double currencyValue =
        _currencyController.text.isEmpty
            ? 0.0
            : double.tryParse(_currencyController.text) ?? 0.0;

    double quantity =
        _quantityController.text.isEmpty
            ? 0.0
            : double.tryParse(_quantityController.text) ?? 0.0;

    setState(() {
      _totalSum = currencyValue * quantity;
    });
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

  // Add this method for translations
  String _getTranslatedText(String key, [Map<String, String>? params]) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    String text = languageProvider.translate(key);
    if (params != null) {
      params.forEach((key, value) {
        text = text.replaceAll('{$key}', value);
      });
    }
    return text;
  }

  Widget _buildCurrencyInputSection() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = MediaQuery.of(context).size.width > 600;
    final isSmallScreen = screenSize.width < 360;
    final fontSize = isSmallScreen ? 16.0 : 18.0; // Increased font size
    final iconSize = isSmallScreen ? 24.0 : 28.0; // Increased icon size

    // Always use portrait layout
      return Row(
        children: [
          // Exchange Rate Field
          Expanded(
            child: TextField(
              controller: _currencyController,
              focusNode: _currencyFocusNode,
              decoration: InputDecoration(
                labelText: _getTranslatedText('exchange_rate'),
                labelStyle: TextStyle(
                  fontSize: fontSize - 2,
                  color: Colors.blue.shade700,
                ), // Adjusted label with blue color
                hintText:
                    _operationType == 'Purchase'
                        ? _getTranslatedText('enter_buy_rate')
                        : _getTranslatedText('enter_sell_rate'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ), // Increased border radius
                  borderSide: BorderSide(
                    color: Colors.blue.shade500,
                    width: 2.0,
                  ), // Blue border
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blue.shade300,
                    width: 2.0,
                  ), // Light blue when not focused
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blue.shade700,
                    width: 2.5,
                  ), // Darker blue when focused
                ),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                prefixIcon: Icon(
                  Icons.attach_money,
                  color: Colors.blue.shade700, // Blue icon color
                  size: iconSize,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16, // Increased vertical padding
                  horizontal: 16, // Increased horizontal padding
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              readOnly: _isNumpadVisible || (isTablet && _isNumpadVisible) || _selectedCurrency == 'SOM', // Disable manual input when numpad is visible or SOM is selected
              enabled: _selectedCurrency != 'SOM', // Disable field when SOM is selected
              showCursor: true,
              // Always calculate total when text changes
              onChanged: (_) => _calculateTotal(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: fontSize),
              onTap: () {
                setState(() {
                  _isRateFieldActive = true;
                });
              },
            ),
          ),
          const SizedBox(width: 20), // Increased spacing
          // Quantity Field
          Expanded(
            child: TextField(
              controller: _quantityController,
              focusNode: _quantityFocusNode,
              decoration: InputDecoration(
                labelText: _getTranslatedText('quantity'),
                labelStyle: TextStyle(
                  fontSize: fontSize - 2,
                  color: Colors.blue.shade700,
                ), // Adjusted label with blue color
                hintText: _getTranslatedText('amount_in_currency', {
                  'code': _selectedCurrency,
                }),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ), // Increased border radius
                  borderSide: BorderSide(
                    color: Colors.blue.shade500,
                    width: 2.0,
                  ), // Blue border
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blue.shade300,
                    width: 2.0,
                  ), // Light blue when not focused
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blue.shade700,
                    width: 2.5,
                  ), // Darker blue when focused
                ),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                prefixIcon: Icon(
                  Icons.numbers,
                  color: Colors.blue.shade700, // Blue icon color
                  size: iconSize,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16, // Increased vertical padding
                  horizontal: 16, // Increased horizontal padding
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // Show tablet keyboard when numpad is hidden and we're on a tablet
              readOnly: isTablet && _isNumpadVisible,
              showCursor: true,
              // Always calculate total when text changes
              onChanged: (_) => _calculateTotal(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: fontSize),
              onTap: () {
                setState(() {
                  _isRateFieldActive = false;
                });
              },
            ),
          ),
        ],
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Get current date
    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date display at the top
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              currentDate,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Currency selection always at the top
          _buildCurrencySelection(),
          const SizedBox(height: 16),
          
          // Operation type buttons (Purchase/Sale)
          _buildOperationButtons(),
          const SizedBox(height: 16),
          
          // Amount input
          _buildAmountInput(),
          const SizedBox(height: 16),
          
          // Exchange rate input
          _buildExchangeRateInput(),
          const SizedBox(height: 16),
          
          // Total sum display
          _buildTotalDisplay(),
          const SizedBox(height: 20),
          
          // Finish button
          _buildFinishButton(),
          const SizedBox(height: 24),
          
          // Recent transaction history
          _buildTransactionHistorySection(),
        ],
      ),
    );
  }
  
  // Method to build exchange rate input
  Widget _buildExchangeRateInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTranslatedText('exchange_rate'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _currencyController,
          decoration: InputDecoration(
            filled: true,
            fillColor: _selectedCurrency == 'SOM' ? Colors.grey.shade100 : Colors.white,
            hintText: '0.00',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          style: const TextStyle(fontSize: 16),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          readOnly: _isNumpadVisible || _selectedCurrency == 'SOM',
          enabled: _selectedCurrency != 'SOM',
          onTap: () {
            if (!_isNumpadVisible && _selectedCurrency != 'SOM') {
              setState(() {
                _isNumpadVisible = true;
                _isRateFieldActive = true;
              });
            }
          },
          onChanged: (value) {
            setState(() {
              _calculateTotal();
            });
          },
        ),
      ],
    );
  }

  Widget _buildTotalSumCard() {
    // Get screen width to adjust sizing
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final valueSize = isSmallScreen ? 28.0 : 32.0; // Increased font size

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
        child: Center(
          child: Text(
            '${_totalSum.toStringAsFixed(2)} SOM',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencySelection() {
    // Include all currencies including SOM in the dropdown
    final allCurrencies = _currencies.map((c) => c.code).where((code) => code != null).cast<String>().toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTranslatedText('currency'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<String>(
            value: _selectedCurrency.isNotEmpty ? _selectedCurrency : null,
            hint: Text(_getTranslatedText('select_currency')),
            isExpanded: true,
            underline: Container(),
            items: allCurrencies.map((String currency) {
              return DropdownMenuItem<String>(
                value: currency,
                child: Text(currency),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedCurrency = newValue;
                  // Clear the rate if SOM is selected
                  if (_selectedCurrency == 'SOM') {
                    _currencyController.text = '1.0';
                  }
                  _calculateTotal();
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOperationButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTranslatedText('operation_type'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _operationType = 'Purchase';
                    _calculateTotal();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _operationType == 'Purchase'
                      ? Colors.blue
                      : Colors.grey.shade200,
                  foregroundColor: _operationType == 'Purchase'
                      ? Colors.white
                      : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(_getTranslatedText('purchase')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _operationType = 'Sale';
                    _calculateTotal();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _operationType == 'Sale'
                      ? Colors.blue
                      : Colors.grey.shade200,
                  foregroundColor: _operationType == 'Sale'
                      ? Colors.white
                      : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(_getTranslatedText('sale')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinishButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _validateAndSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 3,
        ),
        child: Text(
          _getTranslatedText('finish'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionHistorySection() {
    if (_recentHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade100,
        ),
        child: Center(
          child: Text(
            _getTranslatedText('no_recent_transactions'),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _getTranslatedText('recent_transactions'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.white,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentHistory.length > 10 ? 10 : _recentHistory.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey.shade300,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final transaction = _recentHistory[index];
              final formattedTime = DateFormat('HH:mm').format(transaction.createdAt);
              
              final isPurchase = transaction.operationType == 'Purchase';
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    // Time
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Operation icon
                    Icon(
                      isPurchase ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isPurchase ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    
                    // Amount and currency
                    Expanded(
                      child: Text(
                        '${transaction.quantity.toStringAsFixed(2)} ${transaction.currencyCode}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    // Rate
                    Text(
                      'rate: ${transaction.rate.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Total
                    Text(
                      '${transaction.total.toStringAsFixed(2)} сом',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTotalDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTranslatedText('total'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.grey.shade50,
          ),
          child: Text(
            '${_totalSum.toStringAsFixed(2)} SOM',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTranslatedText('amount'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _quantityController,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: '0.00',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          style: const TextStyle(fontSize: 16),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          readOnly: _isNumpadVisible,
          onTap: () {
            if (!_isNumpadVisible) {
              setState(() {
                _isNumpadVisible = true;
                _isRateFieldActive = false;
              });
            }
          },
          onChanged: (value) {
            setState(() {
              _calculateTotal();
            });
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _currencyController.dispose();
    _quantityController.dispose();
    _currencyFocusNode.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  // Validate inputs and submit transaction
  void _validateAndSubmit() async {
    // Validate currency selection
    if (_selectedCurrency.isEmpty) {
      _showBriefNotification(_getTranslatedText('select_currency_first'), Colors.red);
      return;
    }
    
    // Validate rate input
    final rate = _currencyController.text.isEmpty 
        ? 0.0 
        : double.tryParse(_currencyController.text);
    
    if (rate == null || (rate <= 0 && _selectedCurrency != 'SOM')) {
      _showBriefNotification(_getTranslatedText('invalid_rate'), Colors.red);
      return;
    }
    
    // Validate quantity input
    final quantity = _quantityController.text.isEmpty 
        ? 0.0 
        : double.tryParse(_quantityController.text);
    
    if (quantity == null || quantity <= 0) {
      _showBriefNotification(_getTranslatedText('invalid_quantity'), Colors.red);
      return;
    }
    
    // Check if we have enough balance for a sale operation
    if (_operationType == 'Sale' && _selectedCurrency != 'SOM') {
      final currencyBalance = await _databaseHelper.getCurrencyQuantity(_selectedCurrency);
      if (quantity > currencyBalance) {
        _showBriefNotification(
          _getTranslatedText('insufficient_balance', {'code': _selectedCurrency}),
          Colors.red,
        );
        return;
      }
    }
    
    // All validations passed, proceed with transaction
    try {
      // Create history entry
      final historyEntry = HistoryModel(
        currencyCode: _selectedCurrency,
        quantity: quantity,
        rate: _selectedCurrency == 'SOM' ? 1.0 : rate!,
        total: _totalSum,
        operationType: _operationType,
        username: currentUser?.username ?? 'unknown',
      );
      
      // Add to database
      await _databaseHelper.addHistoryEntry(historyEntry);
      
      // Update currency quantities
      if (_operationType == 'Purchase') {
        // For purchase, we add to the currency and deduct from SOM
        await _databaseHelper.adjustCurrencyQuantity(
          _selectedCurrency, 
          quantity, 
          true
        );
        
        // Deduct from SOM
        if (_selectedCurrency != 'SOM') {
          await _databaseHelper.adjustCurrencyQuantity(
            'SOM', 
            _totalSum, 
            false
          );
        }
      } else {
        // For sale, we deduct from the currency and add to SOM
        await _databaseHelper.adjustCurrencyQuantity(
          _selectedCurrency, 
          quantity, 
          false
        );
        
        // Add to SOM
        if (_selectedCurrency != 'SOM') {
          await _databaseHelper.adjustCurrencyQuantity(
            'SOM', 
            _totalSum, 
            true
          );
        }
      }
      
      // Show success message
      _showBriefNotification(
        _getTranslatedText('transaction_successful'),
        Colors.green,
      );
      
      // Reset form
      setState(() {
        _currencyController.text = '';
        _quantityController.text = '';
        _totalSum = 0.0;
      });
      
      // Reload data
      await _initializeData();
      
    } catch (e) {
      debugPrint('Error processing transaction: $e');
      _showBriefNotification(
        _getTranslatedText('transaction_failed'),
        Colors.red,
      );
    }
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
  Key _historyScreenKey = UniqueKey();

  late List<Widget> _pages;
  late List<BottomNavigationBarItem> _navigationItems;

  @override
  void initState() {
    super.initState();
    _initPages();
    _initNavigationItems();
  }

  void _initPages() {
    final bool isAdmin = currentUser?.role == 'admin';

    _pages = [
      CurrencyConverterCore(key: _currencyConverterCoreKey),
      HistoryScreen(key: _historyScreenKey),
    ];

    if (isAdmin) {
      _pages.add(StatisticsScreen(key: UniqueKey()));
      _pages.add(AnalyticsScreen(key: UniqueKey()));
    }

    _pages.add(const SettingsScreen());
  }

  void _initNavigationItems() {
    final bool isAdmin = currentUser?.role == 'admin';

    _navigationItems = [
      BottomNavigationBarItem(
        icon: Icon(Icons.currency_exchange, size: 28),
        label: '',
        activeIcon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade100, Colors.blue.shade200],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.currency_exchange, size: 28),
        ),
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.history, size: 28),
        label: '',
        activeIcon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade100, Colors.blue.shade200],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.history, size: 28),
        ),
      ),
    ];

    if (isAdmin) {
      _navigationItems.add(
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics, size: 28),
          label: '',
          activeIcon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.blue.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics, size: 28),
          ),
        ),
      );

      _navigationItems.add(
        BottomNavigationBarItem(
          icon: Icon(Icons.pie_chart, size: 28),
          label: '',
          activeIcon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.blue.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pie_chart, size: 28),
          ),
        ),
      );
    }

    _navigationItems.add(
      BottomNavigationBarItem(
        icon: Icon(Icons.settings, size: 28),
        label: '',
        activeIcon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade100, Colors.blue.shade200],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.settings, size: 28),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;

      if (index == 1) {
        _historyScreenKey = UniqueKey();
      }

      if (index == 0) {
        _loadCurrencyData();
      }
    });
  }

  void _loadCurrencyData() {
    _currencyConverterCoreKey.currentState?._loadCurrencies();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const LoginScreen();
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          child: _buildCurrentPage(),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.blue.shade50],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100,
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.blue.shade700,
              unselectedItemColor: Colors.grey.shade400,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              iconSize: 32,
              items: _navigationItems,
              mouseCursor: SystemMouseCursors.click,
              unselectedFontSize: 0,
              selectedFontSize: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    return _pages[_selectedIndex];
  }

  String _getTranslatedText(String key, [Map<String, String>? params]) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    String text = languageProvider.translate(key);
    if (params != null) {
      params.forEach((key, value) {
        text = text.replaceAll('{$key}', value);
      });
    }
    return text;
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
  final _currencyConverterCoreKey = GlobalKey<_CurrencyConverterCoreState>();
  Key _historyScreenKey = UniqueKey();

  late List<Widget> _pages;
  late List<NavigationRailDestination> _navigationDestinations;

  @override
  void initState() {
    super.initState();
    _initPages();
    _initNavigationDestinations();
  }

  void _initPages() {
    final bool isAdmin = currentUser?.role == 'admin';

    _pages = [
      CurrencyConverterCore(key: _currencyConverterCoreKey, isWideLayout: true),
      HistoryScreen(key: _historyScreenKey),
    ];

    if (isAdmin) {
      _pages.add(StatisticsScreen(key: UniqueKey()));
      _pages.add(AnalyticsScreen(key: UniqueKey()));
    }

    _pages.add(const SettingsScreen());
  }

  void _initNavigationDestinations() {
    final bool isAdmin = currentUser?.role == 'admin';

    _navigationDestinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.currency_exchange, size: 28),
        label: Text(''),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.history, size: 28),
        label: Text(''),
      ),
    ];

    if (isAdmin) {
      _navigationDestinations.addAll([
        const NavigationRailDestination(
          icon: Icon(Icons.analytics, size: 28),
          label: Text(''),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.pie_chart, size: 28),
          label: Text(''),
        ),
      ]);
    }

    _navigationDestinations.add(
      const NavigationRailDestination(
        icon: Icon(Icons.settings, size: 28),
        label: Text(''),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;

      if (index == 1) {
        _historyScreenKey = UniqueKey();
      }

      if (index == 0) {
        _loadCurrencyData();
      }
    });
  }

  void _loadCurrencyData() {
    _currencyConverterCoreKey.currentState?._loadCurrencies();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const LoginScreen();
    }

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: _buildPortraitLayout(),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.blue.shade50],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100.withOpacity(0.5),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.blue.shade700,
              unselectedItemColor: Colors.grey.shade400,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onDestinationSelected,
              iconSize: 36,
              items: _navigationDestinations.map((destination) {
                return BottomNavigationBarItem(
                  icon: destination.icon,
                  label: '',
                  activeIcon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade100,
                          Colors.blue.shade200,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: destination.icon,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20.0,
        vertical: 20.0,
      ),
      child: _pages[_selectedIndex],
    );
  }

  String _getTranslatedText(String key, [Map<String, String>? params]) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    String text = languageProvider.translate(key);
    if (params != null) {
      params.forEach((key, value) {
        text = text.replaceAll('{$key}', value);
      });
    }
    return text;
  }
}
