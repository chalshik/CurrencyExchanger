import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';

enum ChartType { distribution, profit }

enum TimeRange { day, week, month }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with WidgetsBindingObserver {
  ChartType _selectedChartType = ChartType.distribution;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _forceRefresh = false;
  TimeRange _selectedTimeRange = TimeRange.week;
  DateTime _selectedStartDate = DateTime.now().subtract(
    const Duration(days: 7),
  );
  DateTime _selectedEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateDateRange();
    _refreshData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    setState(() {
      switch (_selectedTimeRange) {
        case TimeRange.day:
          _selectedStartDate = DateTime(now.year, now.month, now.day);
          _selectedEndDate = now;
          break;
        case TimeRange.week:
          _selectedStartDate = now.subtract(const Duration(days: 7));
          _selectedEndDate = now;
          break;
        case TimeRange.month:
          _selectedStartDate = DateTime(now.year, now.month - 1, now.day);
          _selectedEndDate = now;
          break;
      }
    });
  }

  void _refreshData() {
    setState(() => _forceRefresh = !_forceRefresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: Column(
        children: [
          // Time range selector
          _buildTimeRangeSelector(),
          // Chart type selector
          _buildChartTypeSelector(),
          // Date range display
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              '${DateFormat('MMM d, y').format(_selectedStartDate)} '
              'to ${DateFormat('MMM d, y').format(_selectedEndDate)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          // Main chart area
          Expanded(
            child: FutureBuilder<dynamic>(
              key: ValueKey(
                "$_forceRefresh-$_selectedChartType-"
                "${_selectedTimeRange.name}-"
                "${_selectedStartDate.millisecondsSinceEpoch}-"
                "${_selectedEndDate.millisecondsSinceEpoch}",
              ),
              future: _getChartData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData ||
                    (snapshot.data is Map && snapshot.data!.isEmpty) ||
                    (snapshot.data is List && snapshot.data!.isEmpty)) {
                  return const Center(child: Text('No data available'));
                }

                switch (_selectedChartType) {
                  case ChartType.distribution:
                    return _buildDistributionChart(snapshot.data!);
                  case ChartType.profit:
                    return _buildProfitChart(snapshot.data!);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children:
              TimeRange.values.map((range) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FilterChip(
                    label: Text(range.name.toUpperCase()),
                    selected: _selectedTimeRange == range,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTimeRange = range;
                        _updateDateRange();
                        _refreshData();
                      });
                    },
                    selectedColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children:
              ChartType.values.map((type) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FilterChip(
                    label: Text(_getChartTypeName(type)),
                    selected: _selectedChartType == type,
                    onSelected: (selected) {
                      setState(() => _selectedChartType = type);
                    },
                    selectedColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Future<dynamic> _getChartData() async {
    switch (_selectedChartType) {
      case ChartType.distribution:
        final data = await _dbHelper.getEnhancedPieChartData(
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
        );
        // Filter out SOM currency
        data['purchases'] =
            (data['purchases'] as List)
                .where((item) => item['currency_code'] != 'SOM')
                .toList();
        data['sales'] =
            (data['sales'] as List)
                .where((item) => item['currency_code'] != 'SOM')
                .toList();
        return data;
      case ChartType.profit:
        final profitData = await _dbHelper.getMostProfitableCurrencies(
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
        );
        return {
          'summary': profitData ?? [], // Provide empty list if null
          'total': _calculateTotalProfit(profitData ?? []),
        };
    }
  }

  double _calculateTotalProfit(List<Map<String, dynamic>> profitData) {
    return profitData.fold<double>(
      0,
      (sum, item) => sum + (item['profit'] as double? ?? 0.0),
    );
  }

  Widget _buildDistributionChart(dynamic data) {
    final purchases = List<Map<String, dynamic>>.from(data['purchases']);
    final sales = List<Map<String, dynamic>>.from(data['sales']);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'PURCHASES'), Tab(text: 'SALES')]),
          Expanded(
            child: TabBarView(
              children: [
                _buildPieChart(
                  title: 'Purchased Currencies',
                  data: purchases,
                  valueKey: 'total_value',
                  labelKey: 'currency_code',
                  isCurrency: true,
                ),
                _buildPieChart(
                  title: 'Sold Currencies',
                  data: sales,
                  valueKey: 'total_value',
                  labelKey: 'currency_code',
                  isCurrency: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitChart(dynamic data) {
    final summaryData = List<Map<String, dynamic>>.from(data['summary'] ?? []);
    final totalProfit = data['total'] as double? ?? 0.0;

    return _buildProfitPieChart(summaryData, totalProfit);
  }

  Widget _buildProfitPieChart(
    List<Map<String, dynamic>> data,
    double totalProfit,
  ) {
    // If no data, show no profit message
    if (data.isEmpty) {
      return const Center(
        child: Text('No profit data available', style: TextStyle(fontSize: 18)),
      );
    }

    return Column(
      children: [
        // Main profit pie chart (with all currencies)
        Expanded(
          child: _buildPieChart(
            title: 'Total Profit by Currency',
            data: data,
            valueKey: 'profit',
            labelKey: 'currency_code',
            isCurrency: true,
            isProfit: true,
            total: totalProfit,
            showTotal: true,
          ),
        ),
        // Net profit
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            color: totalProfit >= 0 ? Colors.green[50] : Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    totalProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: totalProfit >= 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Net ${totalProfit >= 0 ? 'Profit' : 'Loss'}: ${NumberFormat.currency(symbol: 'SOM ', decimalDigits: 2).format(totalProfit.abs())}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: totalProfit >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart({
    required String title,
    required List<Map<String, dynamic>> data,
    required String valueKey,
    required String labelKey,
    bool isCurrency = false,
    bool isProfit = false,
    double? total,
    bool showTotal = false,
  }) {
    // If no data, show message
    if (data.isEmpty) {
      return Center(
        child: Text(
          isProfit ? 'No profit data' : 'No data available',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    // Use provided total or calculate if not provided
    final displayTotal =
        total ??
        data.fold<double>(
          0,
          (sum, item) => sum + (item[valueKey] as double? ?? 0.0),
        );

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (showTotal)
              Text(
                'Total: ${NumberFormat.currency(symbol: isCurrency ? 'SOM ' : '', decimalDigits: isProfit ? 2 : 0).format(displayTotal)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                series: <CircularSeries>[
                  PieSeries<Map<String, dynamic>, String>(
                    dataSource: data,
                    xValueMapper: (data, _) => data[labelKey],
                    yValueMapper: (data, _) {
                      // Add null check and default to 0.0 if null
                      final value = data[valueKey];
                      return value is double ? value : 0.0;
                    },
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      useSeriesColor: true,
                    ),
                    enableTooltip: true,
                    // Color mapping for profit (green) vs loss (red)
                    pointColorMapper:
                        isProfit
                            ? (data, _) {
                              final value = data[valueKey];
                              return (value is double && value > 0)
                                  ? Colors.green
                                  : Colors.red;
                            }
                            : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getChartTypeName(ChartType type) {
    switch (type) {
      case ChartType.distribution:
        return 'Distribution';
      case ChartType.profit:
        return 'Profit';
    }
  }
}
