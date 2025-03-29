import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';

enum ChartType { distribution, bar }

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
  String _activeTab = 'purchases'; // Track active tab for distribution view

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
                  case ChartType.bar:
                    return _buildBarChart(snapshot.data!);
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pie chart icon for distribution
          Material(
            color: _selectedChartType == ChartType.distribution 
                ? Theme.of(context).primaryColor.withOpacity(0.2) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _selectedChartType = ChartType.distribution),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.pie_chart,
                  size: 24,
                  color: _selectedChartType == ChartType.distribution
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Bar chart icon
          Material(
            color: _selectedChartType == ChartType.bar 
                ? Theme.of(context).primaryColor.withOpacity(0.2) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _selectedChartType = ChartType.bar),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.bar_chart,
                  size: 24,
                  color: _selectedChartType == ChartType.bar
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
              ),
            ),
          ),
        ],
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
        // Get profit data for the tab
        data['profit'] = await _dbHelper.getMostProfitableCurrencies(
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
        );
        return data;
      case ChartType.bar:
        return await _dbHelper.getDailyProfitData(
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
        );
    }
  }

  Widget _buildBarChart(dynamic data) {
    final dailyData = List<Map<String, dynamic>>.from(data);

    if (dailyData.isEmpty) {
      return const Center(
        child: Text('No profit data available', style: TextStyle(fontSize: 18)),
      );
    }

    // Convert data to ensure proper types
    final chartData =
        dailyData.map((item) {
          return {
            'day': item['day'] as String,
            'profit': (item['profit'] as num?)?.toDouble() ?? 0.0,
          };
        }).toList();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Daily Profit', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(title: AxisTitle(text: 'Date')),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Profit (SOM)'),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<Map<String, dynamic>, String>(
                    dataSource: chartData,
                    xValueMapper: (data, _) => data['day'],
                    yValueMapper: (data, _) => data['profit'],
                    name: 'Profit',
                    color: Colors.blue,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.top,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Total Profit: ${NumberFormat.currency(symbol: 'SOM ', decimalDigits: 2).format(_calculateTotalProfit(chartData))}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionChart(dynamic data) {
    final purchases = List<Map<String, dynamic>>.from(data['purchases']);
    final sales = List<Map<String, dynamic>>.from(data['sales']);
    final profitData = List<Map<String, dynamic>>.from(data['profit'] ?? []);
    final totalProfit = _calculateTotalProfit(profitData);

    return Column(
      children: [
        // Tab bar with purchases, sales, and profit
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(child: _buildDistributionTab('purchases', 'Purchases')),
              Expanded(child: _buildDistributionTab('sales', 'Sales')),
              Expanded(child: _buildDistributionTab('profit', 'Profit')),
            ],
          ),
        ),
        // Chart area
        Expanded(
          child: _buildActiveTabContent(
            activeTab: _activeTab,
            purchases: purchases,
            sales: sales,
            profitData: profitData,
            totalProfit: totalProfit,
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionTab(String tabName, String label) {
    return InkWell(
      onTap: () => setState(() => _activeTab = tabName),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color:
                  _activeTab == tabName
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight:
                  _activeTab == tabName ? FontWeight.bold : FontWeight.normal,
              color:
                  _activeTab == tabName
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent({
    required String activeTab,
    required List<Map<String, dynamic>> purchases,
    required List<Map<String, dynamic>> sales,
    required List<Map<String, dynamic>> profitData,
    required double totalProfit,
  }) {
    switch (activeTab) {
      case 'purchases':
        return _buildPieChart(
          title: 'Purchased Currencies',
          data: purchases,
          valueKey: 'total_value',
          labelKey: 'currency_code',
          isCurrency: true,
        );
      case 'sales':
        return _buildPieChart(
          title: 'Sold Currencies',
          data: sales,
          valueKey: 'total_value',
          labelKey: 'currency_code',
          isCurrency: true,
        );
      case 'profit':
        return _buildProfitPieChart(profitData, totalProfit);
      default:
        return const Center(child: Text('No data available'));
    }
  }

  double _calculateTotalProfit(List<Map<String, dynamic>> profitData) {
    return profitData.fold<double>(
      0,
      (sum, item) => sum + ((item['profit'] as num?)?.toDouble() ?? 0.0),
    );
  }

  Widget _buildProfitPieChart(
    List<Map<String, dynamic>> data,
    double totalProfit,
  ) {
    if (data.isEmpty) {
      return const Center(
        child: Text('No profit data available', style: TextStyle(fontSize: 18)),
      );
    }

    return Column(
      children: [
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
    if (data.isEmpty) {
      return Center(
        child: Text(
          isProfit ? 'No profit data' : 'No data available',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

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
                      final value = data[valueKey];
                      return value is double ? value : 0.0;
                    },
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      useSeriesColor: true,
                    ),
                    enableTooltip: true,
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
}
