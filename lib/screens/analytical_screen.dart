import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrencyStats();
  }

  Future<void> _loadCurrencyStats() async {
    try {
      final stats = await _calculateCurrencyStats();
      setState(() {
        _currencyStats = stats;
        _totalProfit = stats.fold(
          0.0,
          (sum, item) => sum + (item['profit'] as double),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading analytics: ${e.toString()}')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _calculateCurrencyStats() async {
    final db = await _dbHelper.database;

    // Query to get purchase stats
    final purchaseStats = await db.rawQuery('''
      SELECT 
        currency_code,
        AVG(rate) as avg_purchase_rate,
        SUM(quantity) as total_purchased,
        SUM(total) as total_purchase_amount
      FROM history
      WHERE operation_type = 'Purchase'
      GROUP BY currency_code
    ''');

    // Query to get sale stats
    final saleStats = await db.rawQuery('''
      SELECT 
        currency_code,
        AVG(rate) as avg_sale_rate,
        SUM(quantity) as total_sold,
        SUM(total) as total_sale_amount
      FROM history
      WHERE operation_type = 'Sale'
      GROUP BY currency_code
    ''');

    // Query to get current quantities
    final currentQuantities = await db.rawQuery('''
      SELECT code, quantity FROM currencies
    ''');

    // Combine all data
    final Map<String, Map<String, dynamic>> combinedStats = {};

    // Add purchase stats
    for (var stat in purchaseStats) {
      combinedStats[stat['currency_code'] as String] = {
        'currency': stat['currency_code'],
        'avg_purchase_rate': stat['avg_purchase_rate'] as double? ?? 0.0,
        'total_purchased': stat['total_purchased'] as double? ?? 0.0,
        'total_purchase_amount':
            stat['total_purchase_amount'] as double? ?? 0.0,
      };
    }

    // Add sale stats
    for (var stat in saleStats) {
      final currency = stat['currency_code'] as String;
      if (combinedStats.containsKey(currency)) {
        combinedStats[currency]!.addAll({
          'avg_sale_rate': stat['avg_sale_rate'] as double? ?? 0.0,
          'total_sold': stat['total_sold'] as double? ?? 0.0,
          'total_sale_amount': stat['total_sale_amount'] as double? ?? 0.0,
        });
      } else {
        combinedStats[currency] = {
          'currency': currency,
          'avg_purchase_rate': 0.0,
          'total_purchased': 0.0,
          'total_purchase_amount': 0.0,
          'avg_sale_rate': stat['avg_sale_rate'] as double? ?? 0.0,
          'total_sold': stat['total_sold'] as double? ?? 0.0,
          'total_sale_amount': stat['total_sale_amount'] as double? ?? 0.0,
        };
      }
    }

    // Add current quantities
    for (var quantity in currentQuantities) {
      final currency = quantity['code'] as String;
      if (combinedStats.containsKey(currency)) {
        combinedStats[currency]!['current_quantity'] =
            quantity['quantity'] as double? ?? 0.0;
      } else {
        combinedStats[currency] = {
          'currency': currency,
          'avg_purchase_rate': 0.0,
          'total_purchased': 0.0,
          'total_purchase_amount': 0.0,
          'avg_sale_rate': 0.0,
          'total_sold': 0.0,
          'total_sale_amount': 0.0,
          'current_quantity': quantity['quantity'] as double? ?? 0.0,
        };
      }
    }

    // Calculate profit for each currency
    final List<Map<String, dynamic>> result = [];
    combinedStats.forEach((currency, stats) {
      final avgPurchaseRate = stats['avg_purchase_rate'] as double;
      final avgSaleRate = stats['avg_sale_rate'] as double;
      final totalSold = stats['total_sold'] as double;

      final profit = (avgSaleRate - avgPurchaseRate) * totalSold;

      result.add({
        'currency': currency,
        'avg_purchase_rate': avgPurchaseRate,
        'avg_sale_rate': avgSaleRate,
        'current_quantity': stats['current_quantity'] as double,
        'profit': profit,
        'total_purchased': stats['total_purchased'] as double,
        'total_sold': stats['total_sold'] as double,
      });
    });

    return result;
  }

  Widget _buildMobileTable() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _currencyStats.length,
      itemBuilder: (context, index) {
        final stat = _currencyStats[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat['currency'].toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildTabletTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        horizontalMargin: 12,
        headingRowColor: MaterialStateProperty.resolveWith<Color>(
          (states) => Colors.blue.shade50,
        ),
        columns: const [
          DataColumn(
            label: Text(
              'Currency',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Avg Buy Rate',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Avg Sell Rate',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Purchased',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text('Sold', style: TextStyle(fontWeight: FontWeight.bold)),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Remaining',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Profit',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            numeric: true,
          ),
        ],
        rows:
            _currencyStats.map((stat) {
              return DataRow(
                cells: [
                  DataCell(Text(stat['currency'].toString())),
                  DataCell(Text(stat['avg_purchase_rate'].toStringAsFixed(4))),
                  DataCell(Text(stat['avg_sale_rate'].toStringAsFixed(4))),
                  DataCell(Text(stat['total_purchased'].toStringAsFixed(2))),
                  DataCell(Text(stat['total_sold'].toStringAsFixed(2))),
                  DataCell(Text(stat['current_quantity'].toStringAsFixed(2))),
                  DataCell(
                    Text(
                      stat['profit'].toStringAsFixed(2),
                      style: TextStyle(
                        color:
                            (stat['profit'] as double) >= 0
                                ? Colors.green
                                : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
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
    final isTablet = MediaQuery.of(context).size.width > 600;

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
      body: Column(
        children: [
          if (!_isLoading && _currencyStats.isNotEmpty) _buildTotalProfitCard(),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _currencyStats.isEmpty
                    ? const Center(child: Text('No analytics data available'))
                    : isTablet
                    ? _buildTabletTable()
                    : _buildMobileTable(),
          ),
        ],
      ),
    );
  }
}
