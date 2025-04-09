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
            readOnly: _isNumpadVisible || (isTablet && _isNumpadVisible), // Disable manual input when numpad is visible
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
<<<<<<< Updated upstream:lib/screens/currency_converter.dart
=======
<<<<<<< HEAD:lib/screens/currency_exchanger.dart
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            readOnly: _isNumpadVisible || (isTablet && _isNumpadVisible), // Disable manual input when numpad is visible
=======
>>>>>>> Stashed changes:lib/screens/currency_exchanger.dart
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // Show tablet keyboard when numpad is hidden and we're on a tablet
              readOnly: isTablet && _isNumpadVisible,
>>>>>>> 213a96f2a4caea528302597653a4d99b7df66c02:lib/screens/currency_converter.dart
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
<<<<<<< HEAD:lib/screens/currency_exchanger.dart
=======
          ),
        ],
      );
    }

    // For landscape mode, stack the fields vertically
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exchange Rate field
        TextField(
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          readOnly: isTablet,
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
        const SizedBox(height: 20), // Increased spacing
        // Quantity field
        TextField(
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          readOnly: isTablet,
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
>>>>>>> 213a96f2a4caea528302597653a4d99b7df66c02:lib/screens/currency_converter.dart
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
    // Include all currencies, including SOM
    final allCurrencies = _currencies;

    // Set text size based on screen size
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final fontSize = isSmallScreen ? 16.0 : 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTranslatedText('currency'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
        const SizedBox(height: 8),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : allCurrencies.isEmpty
            ? Center(
              child: Column(
                children: [
                  Text(
                    _getTranslatedText('no_currencies_available'),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getTranslatedText('add_currencies_settings'),
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
            : DropdownButtonFormField<String>(
              value: _selectedCurrency.isNotEmpty ? _selectedCurrency : null,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 2.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 2.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade700, width: 2.5),
                ),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: allCurrencies.map((currency) {
                return DropdownMenuItem<String>(
                  value: currency.code,
                  child: Text(
                    currency.code ?? '',
                    style: TextStyle(fontSize: fontSize),
                  ),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCurrency = newValue;
                    // Clear the exchange rate field for all currencies including SOM
                    _currencyController.text = '';
                    _calculateTotal();
                  });
                }
              },
              hint: _selectedCurrency.isEmpty
                  ? Text(
                      _getTranslatedText('select_currency'),
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  : null,
            ),
      ],
    );
  }

  Widget _buildOperationTypeButtons() {
    // Get screen width to adjust button size
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final buttonPadding = isSmallScreen ? const EdgeInsets.symmetric(vertical: 16) : const EdgeInsets.symmetric(vertical: 20);
    final buttonTextSize = isSmallScreen ? 16.0 : 18.0;

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient:
                  _operationType == 'Purchase'
                      ? LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
              borderRadius: BorderRadius.circular(12),
              border:
                  _operationType != 'Purchase'
                      ? Border.all(color: Colors.blue.shade300, width: 2)
                      : null,
            ),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _operationType = 'Purchase';
                  // Do not auto-fill exchange rate
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _operationType == 'Purchase'
                        ? Colors.transparent
                        : Colors.blue.shade50,
                foregroundColor:
                    _operationType == 'Purchase'
                        ? Colors.white
                        : Colors.blue.shade700,
                padding: buttonPadding,
                elevation: _operationType == 'Purchase' ? 6 : 2,
                shadowColor:
                    _operationType == 'Purchase'
                        ? Colors.blue.shade300
                        : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(0, 60),
              ),
              child: Text(
                _getTranslatedText('purchase'),
                style: TextStyle(
                  fontSize: buttonTextSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient:
                  _operationType == 'Sale'
                      ? LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
              borderRadius: BorderRadius.circular(12),
              border:
                  _operationType != 'Sale'
                      ? Border.all(color: Colors.blue.shade300, width: 2)
                      : null,
            ),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _operationType = 'Sale';
                  // Do not auto-fill exchange rate
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _operationType == 'Sale'
                        ? Colors.transparent
                        : Colors.blue.shade50,
                foregroundColor:
                    _operationType == 'Sale'
                        ? Colors.white
                        : Colors.blue.shade700,
                padding: buttonPadding,
                elevation: _operationType == 'Sale' ? 6 : 2,
                shadowColor:
                    _operationType == 'Sale'
                        ? Colors.blue.shade300
                        : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(0, 60),
              ),
              child: Text(
                _getTranslatedText('sale'),
                style: TextStyle(
                  fontSize: buttonTextSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinishButton() {
    // Get screen width to adjust sizing
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    // Remove landscape check
    // final isLandscape = screenSize.width > screenSize.height;

    // Standard sizes for portrait mode
    final fontSize = isSmallScreen ? 16.0 : 18.0; // Increased font size
    final verticalPadding = isSmallScreen ? 18.0 : 20.0; // Increased padding
    final buttonHeight = isSmallScreen ? 60.0 : 65.0; // Increased height

    return Container(
      height: buttonHeight,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16), // Increased margin
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade300.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _finishOperation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _getTranslatedText('finish'),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0, // Increased letter spacing
          ),
        ),
      ),
    );
  }

  Future<void> _finishOperation() async {
    try {
      // Special handling for SOM
      if (_selectedCurrency == 'SOM') {
        // For SOM operations, we only need quantity (amount), not rate
        if (_quantityController.text.isEmpty) {
          _showBriefNotification(
            _getTranslatedText('enter_valid_amount'),
            Colors.red,
          );
          return;
        }
        
        final amount = double.tryParse(_quantityController.text);
        if (amount == null || amount <= 0) {
          _showBriefNotification(
            _getTranslatedText('enter_valid_amount'),
            Colors.red,
          );
          return;
        }
        
        // Get the SOM currency
        final somCurrency = await _databaseHelper.getCurrency('SOM');
        if (somCurrency == null) {
          _showBriefNotification(_getTranslatedText('error'), Colors.red);
          return;
        }
        
        // Update SOM balance
        double newSomQuantity = somCurrency.quantity;
        if (_operationType == 'Purchase') {
          // Add to SOM when buying
          newSomQuantity += amount;
        } else {
          // Subtract from SOM when selling
          if (somCurrency.quantity < amount) {
            _showBriefNotification(
              _getTranslatedText('not_enough_som'),
              Colors.red,
            );
            return;
          }
          newSomQuantity -= amount;
        }
        
        // Update SOM quantity
        await _databaseHelper.updateCurrencyQuantity('SOM', newSomQuantity);
        
        // Store the transaction in history
        final history = HistoryModel(
          currencyCode: 'SOM',
          operationType: _operationType,
          rate: 1, // Use 1 as default rate for SOM
          quantity: amount,
          total: amount, // Total equals amount for SOM
        );
        
        await _databaseHelper.insertHistory(history);
        
        _showBriefNotification(
          _getTranslatedText('transaction_complete'),
          Colors.green,
        );

        setState(() {
          _quantityController.text = '';
          _currencyController.text = '';
        });

        // Refresh data
        await _initializeData();
        return;
      }

      // For non-SOM currencies, perform regular validation
      if (_selectedCurrency.isEmpty ||
          _currencyController.text.isEmpty ||
          _quantityController.text.isEmpty) {
        _showBriefNotification(
          _getTranslatedText('enter_valid_numbers'),
          Colors.red,
        );
        return;
      }

      final rate = double.tryParse(_currencyController.text);
      final quantity = double.tryParse(_quantityController.text);

      if (rate == null || quantity == null || rate < 0 || quantity <= 0) {
        _showBriefNotification(
          _getTranslatedText('enter_valid_numbers'),
          Colors.red,
        );
        return;
      }

      // Get the SOM and selected currency
      final somCurrency = await _databaseHelper.getCurrency('SOM');
      final selectedCurrency = await _databaseHelper.getCurrency(
        _selectedCurrency,
      );

      if (somCurrency == null || selectedCurrency == null) {
        _showBriefNotification(_getTranslatedText('error'), Colors.red);
        return;
      }

      // Check if enough balance
      if (_operationType == 'Purchase') {
        // In Purchase: We spend SOM to get foreign currency
        if (somCurrency.quantity < _totalSum) {
          _showBriefNotification(
            _getTranslatedText('not_enough_som'),
            Colors.red,
          );
          return;
        }
      } else {
        // In Sale: We spend foreign currency to get SOM
        if (selectedCurrency.quantity < quantity) {
          _showBriefNotification(
            _getTranslatedText('not_enough_currency', {
              'code': _selectedCurrency,
            }),
            Colors.red,
          );
          return;
        }
      }

      // Store the transaction in history
      final history = HistoryModel(
        currencyCode: _selectedCurrency,
        operationType: _operationType,
        rate: rate,
        quantity: quantity,
        total: _totalSum,
        createdAt: DateTime.now(),
        username: currentUser?.username ?? '',
      );

      await _databaseHelper.insertHistory(
        currencyCode: history.currencyCode,
        operationType: history.operationType,
        rate: history.rate,
        quantity: history.quantity,
        total: history.total,
      );

      // Update currency quantities
      if (_operationType == 'Purchase') {
        // Subtract SOM, add foreign currency
        await _databaseHelper.updateCurrencyQuantity(
          'SOM',
          somCurrency.quantity - _totalSum,
        );
        await _databaseHelper.updateCurrencyQuantity(
          _selectedCurrency,
          selectedCurrency.quantity + quantity,
        );
      } else {
        // Add SOM, subtract foreign currency
        await _databaseHelper.updateCurrencyQuantity(
          'SOM',
          somCurrency.quantity + _totalSum,
        );
        await _databaseHelper.updateCurrencyQuantity(
          _selectedCurrency,
          selectedCurrency.quantity - quantity,
        );
      }

      // Show success message and clear form
      _showBriefNotification(
        _getTranslatedText('transaction_complete'),
        Colors.green,
      );

      setState(() {
        _quantityController.text = '';
        _currencyController.text = '';
      });

      // Refresh data
      await _initializeData();
    } catch (e) {
      _showBriefNotification(
        '${_getTranslatedText('error')}: ${e.toString()}',
        Colors.red,
      );
    }
  }

  Widget _buildRecentHistory() {
    return _buildCompactTransactionHistory();
  }

  Widget _buildCompactTransactionHistory() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final iconSize = isSmallScreen ? 24.0 : 28.0; // Increased icon size
    final fontSize = isSmallScreen ? 14.0 : 16.0; // Increased main font size
    final timeSize = isSmallScreen ? 10.0 : 12.0; // Keeping time size small
    final padding = isSmallScreen ? 12.0 : 16.0;
    final borderRadius = isSmallScreen ? 12.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getTranslatedText('recent_transactions'),
          style: TextStyle(
            fontSize: fontSize + 2,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        if (_recentHistory.isNotEmpty)
          ..._recentHistory.map((transaction) {
            final isPurchase = transaction.operationType == 'Purchase';
            final gradientColors = isPurchase
                ? [Colors.red.shade50, Colors.red.shade100]
                : [Colors.green.shade50, Colors.green.shade100];

            return Container(
                  margin: const EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
                    child: Column(
                      children: [
                  // Time at the top center with smaller font
                            Text(
                    DateFormat('HH:mm').format(transaction.createdAt),
                    style: TextStyle(
                      fontSize: timeSize,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Transaction details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                      // Left section: Arrow icon and Currency amount
                      Expanded(
                        flex: 3,
                        child: Row(
                              children: [
                            Icon(
                              isPurchase ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isPurchase ? Colors.red.shade700 : Colors.green.shade700,
                              size: iconSize,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${transaction.quantity.toStringAsFixed(2)} ${transaction.currencyCode}',
                                style: TextStyle(
                                  fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                ),
                                  ),
                                ),
                              ],
                            ),
                      ),
                      // Center section: Rate
                      Expanded(
                        flex: 2,
                        child: Text(
                          'rate: ${transaction.rate.toStringAsFixed(1)}',
                          style: TextStyle(
                                    fontWeight: FontWeight.bold,
                            fontSize: fontSize,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Right section: Total in SOM
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${transaction.total.toStringAsFixed(2)} сом',
                          style: TextStyle(
                                    fontWeight: FontWeight.bold,
                            fontSize: fontSize,
                                  ),
                          textAlign: TextAlign.right,
                                ),
                            ),
                          ],
                        ),
                      ],
              ),
            );
          }).toList()
        else
          Center(
            child: Text(
              _getTranslatedText('no_recent_transactions'),
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey.shade600,
              ),
            ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check screen size to adjust layout accordingly
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isTablet = screenSize.width >= 600;
    final spacing = isSmallScreen ? 8.0 : 12.0;

    final cardRadius = widget.isWideLayout ? 20.0 : 16.0;
    final cardPadding =
        widget.isWideLayout ? 20.0 : (isSmallScreen ? 8.0 : 12.0);
    final headerFontSize =
        widget.isWideLayout ? 22.0 : (isSmallScreen ? 16.0 : 18.0);
    final standardFontSize =
        widget.isWideLayout ? 16.0 : (isSmallScreen ? 13.0 : 15.0);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child:
              widget.isWideLayout
                  ? _buildTabletLayout(
                    context,
                    spacing,
                    headerFontSize,
                    standardFontSize,
                    isTablet,
                  )
                  : _buildMobileLayout(
                    context,
                    spacing,
                    headerFontSize,
                    standardFontSize,
                  ),
        ),
      ),
    );
  }

  // Two-column layout optimized for tablets
  Widget _buildTabletLayout(
    BuildContext context,
    double spacing,
    double headerFontSize,
    double standardFontSize,
    bool isTablet,
  ) {
      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // 1) Current Date with Numpad Toggle
          Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
            Text(
              DateFormat('dd/MM/yy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
            _buildNumpadToggleButton(), // Numpad toggle button
            ],
          ),
          SizedBox(height: spacing),

          // Exchange rate and quantity in one row for portrait mode
          _buildCurrencyInputSection(),

          SizedBox(
            height: spacing * 3,
          ), // Increased spacing before total sum card
          // Total sum display
          _buildTotalSumCard(),
          SizedBox(height: spacing),

          // Currency selector now below total amount
          _buildCurrencySelection(),
          SizedBox(height: spacing),

        // 3) Purchase and Sell Button Options (moved below currency combobox)
          _buildOperationTypeButtons(),
          SizedBox(height: spacing),

        // 4) Amount
        _buildAmountInput(),
          SizedBox(height: spacing),

<<<<<<< Updated upstream:lib/screens/currency_converter.dart
              // Use row in landscape, column in portrait for tablets
              if (isLandscape) {
                return Stack(
                  children: [
                    // Main row with content
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column - main controls
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildCurrencyInputSection(),
                                SizedBox(
                                  height: spacing * 3,
                                ), // Increased spacing before total sum card
                                _buildTotalSumCard(),
                                SizedBox(height: spacing),
                                _buildCurrencySelection(),
                                SizedBox(height: spacing),
                                Text(
                                  _getTranslatedText("operation_type"),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: standardFontSize,
                                  ),
                                ),
                                SizedBox(height: 4),
                                _buildOperationTypeButtons(),
                                SizedBox(
                                  height: spacing * 3,
                                ), // Extra space for button at bottom
                              ],
                            ),
                          ),
                        ),
                        // Right column for numpad
                        if (isTablet) ...[
                          SizedBox(width: spacing),
                          Expanded(flex: 3, child: _buildNumpad()),
                        ],
                      ],
                    ),

                    // Positioned finish button at bottom right
                    Positioned(
                      right: 0,
                      bottom: 50, // Position it even higher (50px from bottom)
                      child: Container(
                        width: 250, // Maintain width
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                        ), // Add padding to fix overlap
                        child: _buildFinishButton(),
                      ),
                    ),
                  ],
                );
              } else {
                // Portrait tablet layout - make it more compact
                return Column(
                  children: [
                    // Currency input
                    _buildCurrencyInputSection(),
                    SizedBox(
                      height: spacing * 3,
                    ), // Increased spacing before total sum card
                    // Total sum card
                    _buildTotalSumCard(),
                    SizedBox(height: spacing),

                    // Currency selector below total
                    _buildCurrencySelection(),
                    SizedBox(height: spacing),

                    // Position numpad after currency selector
                    if (isTablet && _isNumpadVisible) _buildPortraitNumpad(),
                    SizedBox(height: spacing),

                    // Operation type and finish button
                    Text(
                      _getTranslatedText("operation_type"),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: standardFontSize,
                      ),
                    ),
                    SizedBox(height: 4),
                    _buildOperationTypeButtons(),
                    SizedBox(height: spacing),
                    _buildFinishButton(),
                    SizedBox(height: spacing * 2),
                  ],
                );
              }
            },
=======
        // 5) Exchange Rate
        _buildExchangeRateInput(),

        // Positioned finish button at bottom right
        Positioned(
          right: 0,
          bottom: 50, // Position it even higher (50px from bottom)
          child: Container(
            width: 250, // Maintain width
            padding: const EdgeInsets.symmetric(
              vertical: 2,
            ), // Add padding to fix overlap
            child: _buildFinishButton(),
>>>>>>> Stashed changes:lib/screens/currency_exchanger.dart
          ),
        ),
      ],
    );
  }

  // Column layout for mobile devices
  Widget _buildMobileLayout(
    BuildContext context,
    double spacing,
    double headerFontSize,
    double standardFontSize,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 30), // Larger spacing
        // Input fields
        _buildCurrencyInputSection(),

        SizedBox(height: 40), // Increased spacing before total sum card
        // Total amount card
        _buildTotalSumCard(),
        SizedBox(height: spacing * 2), // Doubled spacing
        // Currency selector (moved below total card)
        _buildCurrencySelection(),
        SizedBox(height: 40), // Larger spacing
        // Operation type buttons (Buy/Sell)
        _buildOperationTypeButtons(),
        SizedBox(height: spacing),

        // 4) Amount
        _buildAmountInput(),
        SizedBox(height: spacing),

        // 5) Exchange Rate
        _buildExchangeRateInput(),
        SizedBox(height: spacing),

        // 6) Total (Amount x Rate)
        _buildTotalSumCard(),
        SizedBox(height: spacing),

        // 7) Finish Button
        _buildFinishButton(),
        SizedBox(height: spacing),
        
        // 8) Recent Transaction History Section
        _buildCompactTransactionHistory(),
      ],
    );
  }

  // Add method to create toggle numpad button
  Widget _buildNumpadToggleButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0), // Increased padding
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _isNumpadVisible = !_isNumpadVisible;
          });
        },
        icon: Icon(
          _isNumpadVisible ? Icons.keyboard_hide : Icons.keyboard,
          size: 24, // Increased icon size
        ),
        label: Text(
          _isNumpadVisible
              ? _getTranslatedText('hide_numpad')
              : _getTranslatedText('show_numpad'),
          style: TextStyle(fontSize: 16), // Increased font size
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade800,
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 16,
          ), // Increased padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Increased border radius
            side: BorderSide(
              color: Colors.grey.shade400,
              width: 1.5,
            ), // Added border
          ),
          minimumSize: const Size(160, 48), // Minimum touch target size
        ),
      ),
    );
  }

  // Special numpad layout for portrait mode with buttons on the side
  Widget _buildPortraitNumpad() {
    // If numpad is hidden, return empty container
    if (!_isNumpadVisible) {
      return const SizedBox.shrink();
    }

    final activeColor =
        _isRateFieldActive ? Colors.blue.shade100 : Colors.green.shade100;
    final activeBorder =
        _isRateFieldActive ? Colors.blue.shade700 : Colors.green.shade700;

    // Calculate optimal button size - make buttons smaller
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonSize = (screenWidth - 250) / 8; // Smaller buttons

    return Container(
      key: const ValueKey('portrait_numpad'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8), // More padding
      margin: const EdgeInsets.symmetric(vertical: 8), // More margin
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Numpad grid with side buttons - more spacing between buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main number pad (3x4 grid)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPortraitNumpadButton('7', size: buttonSize),
                      const SizedBox(width: 12), // More spacing
                      _buildPortraitNumpadButton('8', size: buttonSize),
                      const SizedBox(width: 12), // More spacing
                      _buildPortraitNumpadButton('9', size: buttonSize),
                    ],
                  ),
                  const SizedBox(height: 12), // More spacing
                  // Second row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPortraitNumpadButton('4', size: buttonSize),
                      const SizedBox(width: 12), // More spacing
                      _buildPortraitNumpadButton('5', size: buttonSize),
                      const SizedBox(width: 12), // More spacing
                      _buildPortraitNumpadButton('6', size: buttonSize),
                    ],
                  ),
                  const SizedBox(height: 12), // More spacing
                  // Third row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPortraitNumpadButton('1', size: buttonSize),
                      const SizedBox(width: 12), // More spacing
                      _buildPortraitNumpadButton('2', size: buttonSize),
                      const SizedBox(width: 12), // More spacing
                      _buildPortraitNumpadButton('3', size: buttonSize),
                    ],
                  ),
                  const SizedBox(height: 12), // More spacing
                  // Fourth row (replaced backspace with 00)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPortraitNumpadButton('.', size: buttonSize),
                      const SizedBox(width: 12), // More spacing
                      _buildPortraitNumpadButton('0', size: buttonSize),
                      const SizedBox(width: 12), // More spacing
                      _buildPortraitNumpadButton('00', size: buttonSize),
                    ],
                  ),
                ],
              ),

              // Side buttons (same size as other buttons, no text)
              const SizedBox(width: 12), // More spacing
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Toggle button
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: ElevatedButton(
                      onPressed: _toggleActiveField,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero, // No padding
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade500,
                              Colors.blue.shade900,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [0.0, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade300.withOpacity(0.5),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: const Icon(Icons.swap_horiz, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12), // More spacing
                  // Backspace button (was previously clear button - swapped positions)
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: ElevatedButton(
                      onPressed: () => _handleNumpadInput('⌫'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero, // No padding
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.orange.shade900,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade300,
                              Colors.deepOrange.shade500,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [0.0, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade200.withOpacity(0.5),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.backspace,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12), // More spacing
                  // Clear button (was previously backspace - swapped positions)
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: ElevatedButton(
                      onPressed: _clearActiveField,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero, // No padding
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade500, Colors.red.shade800],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [0.0, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.shade300.withOpacity(0.5),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: const Text(
                            'C',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Special button for portrait mode with smaller size but larger font
  Widget _buildPortraitNumpadButton(
    String value, {
    required double size,
    bool isSpecial = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: () => _handleNumpadInput(value),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSpecial ? Colors.orange.shade100 : Colors.white,
          foregroundColor: isSpecial ? Colors.orange.shade900 : Colors.black,
          elevation: 2,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18, // Larger font relative to button size
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Numpad widget for tablets
  Widget _buildNumpad() {
    final screenWidth = MediaQuery.of(context).size.width;
    // Remove landscape check
    // final isLandscape = screenWidth > MediaQuery.of(context).size.height;
    final buttonSize = screenWidth > 600 ? 60.0 : 50.0;

    return Container(
      key: const ValueKey('numpad'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Number display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Text(
              _isRateFieldActive
                  ? (_currencyController.text.isEmpty
                      ? '0'
                      : _currencyController.text)
                  : (_quantityController.text.isEmpty
                      ? '0'
                      : _quantityController.text),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 6),

          // Numpad grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Numpad grid
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // First row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFixedSizeNumpadButton('7', size: buttonSize),
                        _buildFixedSizeNumpadButton('8', size: buttonSize),
                        _buildFixedSizeNumpadButton('9', size: buttonSize),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Second row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFixedSizeNumpadButton('4', size: buttonSize),
                        _buildFixedSizeNumpadButton('5', size: buttonSize),
                        _buildFixedSizeNumpadButton('6', size: buttonSize),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Third row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFixedSizeNumpadButton('1', size: buttonSize),
                        _buildFixedSizeNumpadButton('2', size: buttonSize),
                        _buildFixedSizeNumpadButton('3', size: buttonSize),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Fourth row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFixedSizeNumpadButton('.', size: buttonSize),
                        _buildFixedSizeNumpadButton('0', size: buttonSize),
                        _buildFixedSizeNumpadButton('00', size: buttonSize),
                      ],
                    ),
                  ],
                ),
              ),

              // Side buttons - removed landscape condition
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  // Switch button
                    SizedBox(
                      width: 60,
                      height: buttonSize * 1.3,
                      child: ElevatedButton(
                        onPressed: _toggleActiveField,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(4),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade500,
                                Colors.blue.shade900,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: [0.0, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade300.withOpacity(0.5),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            alignment: Alignment.center,
                            child: Icon(Icons.swap_vert, size: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Backspace button
                    SizedBox(
                      width: 60,
                      height: buttonSize * 1.3,
                      child: ElevatedButton(
                        onPressed: () => _handleNumpadInput('⌫'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.orange.shade900,
                          padding: const EdgeInsets.all(4),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade300,
                                Colors.deepOrange.shade500,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: [0.0, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.shade200.withOpacity(0.5),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.backspace,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Clear button
                    SizedBox(
                      width: 60,
                      height: buttonSize * 1.3,
                      child: ElevatedButton(
                        onPressed: _clearActiveField,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(4),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade500,
                                Colors.red.shade800,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: [0.0, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.shade300.withOpacity(0.5),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: const Text(
                              'C',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Clear button at bottom (only for portrait mode or if not using side buttons)
          if (!isLandscape) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: _clearActiveField,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade500, Colors.red.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade300.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: const Text(
                      'C',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Fixed size numpad button with smaller styling
  Widget _buildFixedSizeNumpadButton(
    String value, {
    required double size,
    bool isSpecial = false,
  }) {
    // Ensure minimum touch target size (48x48)
    final buttonSize = size < 48 ? 48.0 : size;

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: ElevatedButton(
        onPressed: () => _handleNumpadInput(value),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSpecial ? Colors.orange.shade100 : Colors.white,
          foregroundColor: isSpecial ? Colors.orange.shade900 : Colors.black,
          elevation: 3, // Increased elevation
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Increased border radius
            side: BorderSide(
              color: isSpecial ? Colors.orange.shade300 : Colors.grey.shade300,
              width: 1.5, // Thicker border
            ),
          ),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 22, // Increased font size
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Handle numpad button presses
  void _handleNumpadInput(String value) {
    final controller =
        _isRateFieldActive ? _currencyController : _quantityController;
    final currentText = controller.text;

    // Ensure controller has a valid selection
    if (controller.selection.baseOffset < 0) {
      controller.selection = TextSelection.collapsed(
        offset: currentText.length,
      );
    }

    final currentSelection = controller.selection;
    final selectionStart =
        currentSelection.start < 0 ? 0 : currentSelection.start;
    final selectionEnd = currentSelection.end < 0 ? 0 : currentSelection.end;

    if (value == '⌫') {
      // Handle backspace
      if (currentText.isEmpty) return;

      if (selectionStart == selectionEnd && selectionStart == 0) return;

      String newText;
      if (selectionStart == selectionEnd) {
        // Delete character before cursor
        final deletePos = selectionStart - 1;
        newText =
            currentText.substring(0, deletePos) +
            currentText.substring(selectionEnd);
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: deletePos);
      } else {
        // Delete selected text
        newText =
            currentText.substring(0, selectionStart) +
            currentText.substring(selectionEnd);
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: selectionStart);
      }
    } else if (value == '.') {
      // Only add decimal point if there isn't one already
      if (!currentText.contains('.')) {
        String newText;
        if (selectionStart != selectionEnd) {
          // Replace selected text
          newText =
              currentText.substring(0, selectionStart) +
              (currentText.isEmpty ? '0.' : '.') +
              currentText.substring(selectionEnd);
        } else {
          // Insert at cursor
          newText =
              currentText.isEmpty
                  ? '0.'
                  : currentText.substring(0, selectionStart) +
                      '.' +
                      currentText.substring(selectionEnd);
        }
        controller.text = newText;

        // Calculate new cursor position
        final newPosition = selectionStart + (currentText.isEmpty ? 2 : 1);
        controller.selection = TextSelection.collapsed(offset: newPosition);
      }
    } else if (value == '00') {
      // Handle double zero input - only add if there's already a non-zero number
      if (currentText.isNotEmpty && currentText != '0') {
        String newText;
        if (selectionStart != selectionEnd) {
          // Replace selected text
          newText =
              currentText.substring(0, selectionStart) +
              '00' +
              currentText.substring(selectionEnd);
        } else {
          // Insert at cursor
          newText =
              currentText.substring(0, selectionStart) +
              '00' +
              currentText.substring(selectionEnd);
        }

        controller.text = newText;
        controller.selection = TextSelection.collapsed(
          offset: selectionStart + 2,
        );
      } else if (currentText.isEmpty) {
        // Just insert a single 0 if the field is empty
        controller.text = '0';
        controller.selection = TextSelection.collapsed(offset: 1);
      }
    } else {
      // Handle number input
      String newText;
      if (selectionStart != selectionEnd) {
        // Replace selected text
        newText =
            currentText.substring(0, selectionStart) +
            value +
            currentText.substring(selectionEnd);
      } else {
        // Insert at cursor
        newText =
            currentText.substring(0, selectionStart) +
            value +
            currentText.substring(selectionEnd);
      }

      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: selectionStart + 1,
      );
    }

    // Recalculate total
    _calculateTotal();
  }

  // Toggle between rate and quantity fields
  void _toggleActiveField() {
    setState(() {
      _isRateFieldActive = !_isRateFieldActive;
      if (_isRateFieldActive) {
        _currencyFocusNode.requestFocus();
      } else {
        _quantityFocusNode.requestFocus();
      }
    });
  }

  // Clear the active input field
  void _clearActiveField() {
    if (_isRateFieldActive) {
      _currencyController.clear();
    } else {
      _quantityController.clear();
    }
    // Ensure total is calculated immediately after clearing
    _calculateTotal();
  }

  @override
  void dispose() {
    _currencyController.dispose();
    _quantityController.dispose();
    _currencyFocusNode.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  // Helper methods for amount and exchange rate inputs
  Widget _buildAmountInput() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return TextField(
      controller: _quantityController,
      focusNode: _quantityFocusNode,
      decoration: InputDecoration(
        labelText: _getTranslatedText('quantity'),
        labelStyle: TextStyle(fontSize: 18, color: Colors.blue.shade700),
        hintText: _getTranslatedText('amount_in_currency', {
          'code': _selectedCurrency,
        }),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade500, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade300, width: 2.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2.5),
        ),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        prefixIcon: Icon(
          Icons.numbers,
          color: Colors.blue.shade700,
          size: 24,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      readOnly: _isNumpadVisible,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _calculateTotal(),
    );
  }

  Widget _buildExchangeRateInput() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final isSomSelected = _selectedCurrency == 'SOM';
    
    return TextField(
      controller: _currencyController,
      focusNode: _currencyFocusNode,
      decoration: InputDecoration(
        labelText: _getTranslatedText('exchange_rate'),
        labelStyle: TextStyle(fontSize: 18, color: Colors.blue.shade700),
        hintText: _operationType == 'Purchase'
            ? _getTranslatedText('enter_buy_rate')
            : _getTranslatedText('enter_sell_rate'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade500, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade300, width: 2.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2.5),
        ),
        filled: true,
        fillColor: isSomSelected 
            ? Colors.grey.shade200  // Grayed out when SOM is selected
            : Theme.of(context).inputDecorationTheme.fillColor,
        prefixIcon: Icon(
          Icons.attach_money,
          color: isSomSelected ? Colors.grey.shade600 : Colors.blue.shade700,
          size: 24,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      readOnly: _isNumpadVisible || isSomSelected, // Disable editing when SOM is selected
      enabled: !isSomSelected, // Disable field when SOM is selected
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _calculateTotal(),
    );
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

    // Only add Analytics and Charts options for admin users
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

    // Settings available for all users
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

      // Handle the history screen refresh
      if (index == 1) {
        _historyScreenKey = UniqueKey();
      }

      // For Statistics and Analytics screens, always recreate them with a new key
      // to force a full refresh when they're selected
      if (index == 2 && currentUser?.role == 'admin') {
        // Statistics screen
        _statisticsKey = UniqueKey();
      } else if (index == 3 && currentUser?.role == 'admin') {
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
    // If no user is logged in, show login screen
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
          ), // Increased padding
          child: _buildCurrentPage(),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 8), // Increased padding
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.blue.shade50],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24), // Increased border radius
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100,
                spreadRadius: 2, // Increased spread
                blurRadius: 10, // Increased blur
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              24,
            ), // Match container border radius
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.blue.shade700,
              unselectedItemColor:
                  Colors
                      .grey
                      .shade400, // Lighter grey for better contrast
              showSelectedLabels: false,
              showUnselectedLabels: false,
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              iconSize: 32, // Increased icon size
              items: _navigationItems,
              mouseCursor: SystemMouseCursors.click, // Better cursor for web
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

  // Method for translations
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
  Key _historyScreenKey = UniqueKey();
  Key _statisticsKey = UniqueKey();
  Key _analyticsKey = UniqueKey();

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
      _pages.add(StatisticsScreen(key: _statisticsKey));
      _pages.add(AnalyticsScreen(key: _analyticsKey));
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

      if (index == 2 && currentUser?.role == 'admin') {
        _statisticsKey = UniqueKey();
      } else if (index == 3 && currentUser?.role == 'admin') {
        _analyticsKey = UniqueKey();
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

    final screenSize = MediaQuery.of(context).size;
    // Remove landscape check
    // final isLandscape = screenSize.width > screenSize.height;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: _buildPortraitLayout(),
      ),
      bottomNavigationBar:
          Padding(
                padding: const EdgeInsets.only(bottom: 12), // Increased padding
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ), // Increased margin
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.blue.shade50],
                    ),
                    borderRadius: BorderRadius.circular(
                      30,
                    ), // Increased border radius
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100.withOpacity(0.5),
                        blurRadius: 12, // Increased blur
                        spreadRadius: 2,
                        offset: const Offset(0, 4), // Deeper shadow
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      30,
                    ), // Match container border radius
                    child: BottomNavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      selectedItemColor: Colors.blue.shade700,
                      unselectedItemColor:
                          Colors
                              .grey
                              .shade400, // Lighter grey for better contrast
                      showSelectedLabels: false,
                      showUnselectedLabels: false,
                      type: BottomNavigationBarType.fixed,
                      currentIndex: _selectedIndex,
                      onTap: _onDestinationSelected,
                      iconSize: 36, // Larger icons for tablet
                      items:
                          _navigationDestinations.map((destination) {
                            return BottomNavigationBarItem(
                              icon: destination.icon,
                              label: '', // Empty label
                              activeIcon: Container(
                                padding: const EdgeInsets.all(
                                  8,
                                ), // Inner padding
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade100,
                                      Colors.blue.shade200,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ), // Rounded background
                                ),
                                child: destination.icon, // Use the same icon
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ),
    );
  }

<<<<<<< Updated upstream:lib/screens/currency_converter.dart
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.blue.shade50],
            ),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: Offset(1, 0),
              ),
            ],
          ),
          child: NavigationRail(
            extended: false,
            backgroundColor: Colors.transparent,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.none,
            destinations: _navigationDestinations,
            selectedIconTheme: IconThemeData(
              color: Colors.blue.shade700,
              size: 32, // Increased icon size
            ),
            unselectedIconTheme: IconThemeData(
              color: Colors.grey.shade400, // Lighter grey for better contrast
              size: 32, // Increased icon size
            ),
            useIndicator: true,
            indicatorColor: Colors.blue.shade100,
            minWidth: 72, // Increased width for larger touch target
            leading: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: IconButton(
                icon: Icon(Icons.menu, size: 32), // Larger menu icon
                onPressed: () {}, // Placeholder for menu functionality
                padding: const EdgeInsets.all(12), // Larger touch target
              ),
            ),
          ),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0), // Increased padding
            child: _pages[_selectedIndex],
          ),
        ),
      ],
    );
  }

=======
>>>>>>> Stashed changes:lib/screens/currency_exchanger.dart
  Widget _buildPortraitLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20.0,
        vertical: 20.0,
      ), // Increased padding
      child: _pages[_selectedIndex],
    );
  }

  // Method for translations
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
