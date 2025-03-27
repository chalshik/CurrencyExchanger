import 'package:flutter/material.dart';
import '../db_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _currencyStats = [];
  double _totalProfit = 0.0;
  double _somBalance = 0.0;
  double _kassaValue = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrencyStats();
  }

  Future<void> _loadCurrencyStats() async {
    if (!mounted) return;

    try {
      setState(() => _isLoading = true);

      final analytics = await _dbHelper.calculateAnalytics();

      if (!mounted) return;

      // Calculate SOM balance and kassa value
      double somBalance = 0.0;
      double kassaValue = 0.0;

      final stats = analytics['currency_stats'] as List<Map<String, dynamic>>;
      for (var stat in stats) {
        if (stat['currency'] == 'SOM') {
          somBalance = stat['current_quantity'] as double;
        } else {
          kassaValue +=
              (stat['current_quantity'] as double) *
              (stat['avg_sale_rate'] as double);
        }
      }

      setState(() {
        _currencyStats = stats;
        _totalProfit = analytics['total_profit'] as double;
        _somBalance = somBalance;
        _kassaValue = kassaValue;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading analytics: ${e.toString()}')),
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
            _buildStatRow(
              'Avg Buy Rate',
              stat['avg_purchase_rate'].toStringAsFixed(4),
            ),
            _buildStatRow(
              'Avg Sell Rate',
              stat['avg_sale_rate'].toStringAsFixed(4),
            ),
            _buildStatRow(
              'Purchased',
              stat['total_purchased'].toStringAsFixed(2),
            ),
            _buildStatRow('Sold', stat['total_sold'].toStringAsFixed(2)),
            _buildStatRow(
              'Remaining',
              stat['current_quantity'].toStringAsFixed(2),
            ),
            _buildProfitRow(stat['profit'] as double),
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
      appBar: AppBar(
        title: const Text('Currency Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurrencyStats,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currencyStats.isEmpty
              ? const Center(child: Text('No analytics data available'))
              : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSummaryCards(),
                    _buildTotalProfitCard(),
                    // Show all currencies including SOM (now properly highlighted)
                    ..._currencyStats.map((stat) => _buildCurrencyCard(stat)),
                  ],
                ),
              ),
    );
  }
}
