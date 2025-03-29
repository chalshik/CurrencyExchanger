import 'package:flutter/material.dart';
import '../db_helper.dart';

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

  // Date range filter variables
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrencyStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = _formatDate(picked);
        } else {
          _endDate = picked;
          _endDateController.text = _formatDate(picked);
        }
      });
      _loadCurrencyStats();
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _loadCurrencyStats() async {
    if (!mounted || _isLoading) return;

    setState(() => _isLoading = true);
    _lastLoadTime = DateTime.now();

    try {
      final analytics = await _dbHelper.calculateAnalytics(
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;

      double somBalance = 0.0;
      double kassaValue = 0.0;

      if (analytics.containsKey('currency_stats')) {
        final stats = analytics['currency_stats'] as List<dynamic>;

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
            final avgPurchaseRate = stat['avg_purchase_rate'] as double? ?? 0.0;
            final totalPurchased = stat['total_purchased'] as double? ?? 0.0;
            kassaValue += avgPurchaseRate * totalPurchased;
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

  Widget _buildDateFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _startDateController,
              decoration: InputDecoration(
                labelText: 'From',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today, size: 20),
                  onPressed: () => _selectDate(context, true),
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              readOnly: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _endDateController,
              decoration: InputDecoration(
                labelText: 'To',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today, size: 20),
                  onPressed: () => _selectDate(context, false),
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              readOnly: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOM Balance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatRow(
                  'Amount',
                  '${_somBalance.toStringAsFixed(2)} SOM',
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
                  'Foreign Currency',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildStatRow(
                  'Total Value',
                  '${_kassaValue.toStringAsFixed(2)} SOM',
                  valueColor: Colors.green,
                ),
              ],
            ),
          ),
        ),
      ],
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width >= 600;
    final isLandscape = screenSize.width > screenSize.height;
    final isWideTablet = isTablet && isLandscape;
    final columnCount = isWideTablet ? 3 : (isTablet ? 2 : 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: RefreshIndicator(
        onRefresh: _loadCurrencyStats,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDateFilterRow(),
                      if (isWideTablet) _buildWideTabletSummary(),
                      if (!isWideTablet) _buildSummaryCards(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Currency Details',
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      isTablet
                          ? _buildCurrencyCardsGrid(columnCount)
                          : _buildCurrencyCardsList(),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildWideTabletSummary() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // SOM Balance
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SOM Balance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_somBalance.toStringAsFixed(2)} SOM',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),

            // Foreign Currency Value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foreign Currency',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_kassaValue.toStringAsFixed(2)} SOM',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),

            // Total Profit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Profit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_totalProfit.toStringAsFixed(2)} SOM',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                          _totalProfit >= 0
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyCard(Map<String, dynamic> stat) {
    final isSom = stat['currency'] == 'SOM';
    if (isSom) return const SizedBox();

    final avgPurchaseRate = stat['avg_purchase_rate'] as double? ?? 0.0;
    final avgSaleRate = stat['avg_sale_rate'] as double? ?? 0.0;
    final totalPurchased = stat['total_purchased'] as double? ?? 0.0;
    final totalSold = stat['total_sold'] as double? ?? 0.0;
    final currentQuantity = stat['current_quantity'] as double? ?? 0.0;
    final profit = stat['profit'] as double? ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stat['currency'].toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildStatRow('Buy Rate', avgPurchaseRate.toStringAsFixed(4)),
            _buildStatRow('Sell Rate', avgSaleRate.toStringAsFixed(4)),
            _buildStatRow('Purchased', totalPurchased.toStringAsFixed(2)),
            _buildStatRow('Sold', totalSold.toStringAsFixed(2)),
            _buildStatRow('Balance', currentQuantity.toStringAsFixed(2)),
            _buildStatRow(
              'Value',
              '${(avgPurchaseRate * totalPurchased).toStringAsFixed(2)} SOM',
              valueColor: Colors.blue,
            ),
            _buildProfitRow(profit),
          ],
        ),
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

  Widget _buildCurrencyCardsGrid(int columnCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          childAspectRatio: 1.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _currencyStats.length,
        itemBuilder: (context, index) {
          return _buildCurrencyCardForGrid(_currencyStats[index]);
        },
      ),
    );
  }

  Widget _buildCurrencyCardForGrid(Map<String, dynamic> stat) {
    final isSom = stat['currency'] == 'SOM';
    if (isSom) return const SizedBox();

    final avgPurchaseRate = stat['avg_purchase_rate'] as double? ?? 0.0;
    final avgSaleRate = stat['avg_sale_rate'] as double? ?? 0.0;
    final totalPurchased = stat['total_purchased'] as double? ?? 0.0;
    final currentQuantity = stat['current_quantity'] as double? ?? 0.0;
    final profit = stat['profit'] as double? ?? 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        profit >= 0
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                  ),
                  child: Center(
                    child: Icon(
                      profit >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                      color:
                          profit >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),

            Text(
              'Balance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currentQuantity.toStringAsFixed(2),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              'Value: ${(avgPurchaseRate * totalPurchased).toStringAsFixed(2)} SOM',
              style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
            ),
            const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Buy',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      avgPurchaseRate.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Sell',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      avgSaleRate.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Profit: ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  profit.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        profit >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyCardsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _currencyStats.length,
      itemBuilder: (context, index) {
        return _buildCurrencyCard(_currencyStats[index]);
      },
    );
  }
}
