import 'package:flutter/material.dart';
import '../db_helper.dart';

// This file is now renamed to statistics_screen.dart
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with WidgetsBindingObserver {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _currencyStats = [];
  double _totalProfit = 0.0;
  double _somBalance = 0.0;
  double _kassaValue = 0.0;
  bool _isLoading = false;
  DateTime? _lastLoadTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrencyStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh data when app resumes from background
    if (state == AppLifecycleState.resumed) {
      _loadCurrencyStats();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Always force refresh when the screen becomes visible
    _lastLoadTime = null; // Reset last load time
    _loadCurrencyStats();
  }

  Future<void> _loadCurrencyStats() async {
    if (!mounted || _isLoading) return;

    setState(() => _isLoading = true);
    _lastLoadTime = DateTime.now();

    try {
      final analytics = await _dbHelper.calculateAnalytics();

      if (!mounted) return;

      // Calculate SOM balance and kassa value
      double somBalance = 0.0;
      double kassaValue = 0.0;

      if (analytics.containsKey('currency_stats')) {
        final stats = analytics['currency_stats'] as List<dynamic>;

        // Convert to proper format and filter out invalid entries
        final currencyStats =
            stats
                .where(
                  (item) =>
                      item is Map<String, dynamic> &&
                      item.containsKey('currency'),
                )
                .map((item) => item as Map<String, dynamic>)
                .toList();

        for (var stat in currencyStats) {
          if (stat['currency'] == 'SOM') {
            somBalance = stat['current_quantity'] as double? ?? 0.0;
          } else {
            final currentQuantity = stat['current_quantity'] as double? ?? 0.0;
            final avgSaleRate = stat['avg_sale_rate'] as double? ?? 0.0;
            kassaValue += currentQuantity * avgSaleRate;
          }
        }

        setState(() {
          _currencyStats = currencyStats;
          _totalProfit = analytics['total_profit'] as double? ?? 0.0;
          _somBalance = somBalance;
          _kassaValue = kassaValue;
          _isLoading = false;
        });
      } else {
        setState(() {
          _currencyStats = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      if (!mounted) return;

      setState(() {
        _currencyStats = [];
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading statistics: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blue.shade50, // Light blue background for SOM
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Main Currency (SOM)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatRow(
                  'Balance',
                  _somBalance.toStringAsFixed(2),
                  valueColor: Colors.blue,
                ),
              ],
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Foreign Currency Value',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildStatRow(
                  'Total Kassa Value',
                  _kassaValue.toStringAsFixed(2),
                  valueColor: Colors.green,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyCard(Map<String, dynamic> stat) {
    final isSom = stat['currency'] == 'SOM';

    // Handle possible null values with defaults
    final avgPurchaseRate = stat['avg_purchase_rate'] as double? ?? 0.0;
    final avgSaleRate = stat['avg_sale_rate'] as double? ?? 0.0;
    final totalPurchased = stat['total_purchased'] as double? ?? 0.0;
    final totalSold = stat['total_sold'] as double? ?? 0.0;
    final currentQuantity = stat['current_quantity'] as double? ?? 0.0;
    final profit = stat['profit'] as double? ?? 0.0;
    if (isSom) return const SizedBox();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSom ? Colors.blue.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  stat['currency'].toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSom ? Colors.blue : null,
                  ),
                ),
                if (isSom)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      '(Main Currency)',
                      style: TextStyle(
                        color: Colors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatRow('Avg Buy Rate', avgPurchaseRate.toStringAsFixed(4)),
            _buildStatRow('Avg Sell Rate', avgSaleRate.toStringAsFixed(4)),
            _buildStatRow('Purchased', totalPurchased.toStringAsFixed(2)),
            _buildStatRow('Sold', totalSold.toStringAsFixed(2)),
            _buildStatRow('Remaining', currentQuantity.toStringAsFixed(2)),
            _buildProfitRow(profit),
            const Divider(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitRow(double profit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Profit', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
            profit.toStringAsFixed(2),
            style: TextStyle(
              color: profit >= 0 ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalProfitCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Profit:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _totalProfit.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _totalProfit >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currencyStats.isEmpty
              ? const Center(child: Text('No statistics data available'))
              : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildSummaryCards(),
                    _buildTotalProfitCard(),
                    // Show all currencies including SOM (now properly highlighted)
                    ..._currencyStats
                        .where(
                          (stat) =>
                              stat.containsKey('currency') &&
                              stat['currency'] != null,
                        )
                        .map((stat) => _buildCurrencyCard(stat))
                        .toList(),
                  ],
                ),
              ),
    );
  }
}
