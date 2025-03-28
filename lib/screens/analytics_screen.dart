import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../db_helper.dart';

enum ChartType { pie, line }
enum PieSubType { bought, sold }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with WidgetsBindingObserver {
  // Current selected chart type
  ChartType _selectedChartType = ChartType.pie;
  // Current selected pie subtype
  PieSubType _selectedPieSubType = PieSubType.bought;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _forceRefresh = false;
  DateTime? _lastRefreshTime;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshData();
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
      _refreshData();
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Always force refresh when the screen becomes visible
    _lastRefreshTime = null; // Reset last refresh time
    _forceRefresh = !_forceRefresh; // Toggle refresh state to force update
  }
  
  void _refreshData() {
    setState(() {
      _forceRefresh = !_forceRefresh; // Toggle to force rebuild of FutureBuilder
      _lastRefreshTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Chart type selector
          _buildChartTypeSelector(),
          // Pie subtype selector (only visible when pie is selected)
          if (_selectedChartType == ChartType.pie) _buildPieSubTypeSelector(),
          // Main chart area
          Expanded(
            child: FutureBuilder<dynamic>(
              // Use current timestamp + other state variables to force refresh
              key: ValueKey("${DateTime.now().millisecondsSinceEpoch}-$_selectedChartType-$_selectedPieSubType"),
              future: _selectedChartType == ChartType.pie
                  ? _dbHelper.getPieChartData()
                  : _dbHelper.calculateAnalytics(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error loading data: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                
                if (!snapshot.hasData) {
                  return const Center(child: Text('No analytics data available'));
                }
                
                if (_selectedChartType == ChartType.pie) {
                  return _buildPieChart(snapshot.data!);
                } else {
                  return _buildLineChart(snapshot.data!);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              ChartType.values.map((type) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(_getChartTypeName(type)),
                    selected: _selectedChartType == type,
                    onSelected: (selected) {
                      setState(() {
                        _selectedChartType = type;
                      });
                    },
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildPieSubTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              PieSubType.values.map((subType) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(_getPieSubTypeName(subType)),
                    selected: _selectedPieSubType == subType,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPieSubType = subType;
                      });
                    },
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildPieChart(dynamic data) {
    List<Map<String, dynamic>> chartData =
        _selectedPieSubType == PieSubType.bought
            ? data['purchases'] as List<Map<String, dynamic>>
            : data['sales'] as List<Map<String, dynamic>>;

    // Filter out SOM currency
    chartData =
        chartData.where((item) => item['currency_code'] != 'SOM').toList();

    final valueKey =
        _selectedPieSubType == PieSubType.bought
            ? 'total_purchase_amount'
            : 'total_sale_amount';

    return _buildSyncfusionPieChart(
      title:
          _selectedPieSubType == PieSubType.bought
              ? 'Purchased Currencies (excl. SOM)'
              : 'Sold Currencies (excl. SOM)',
      data: chartData,
      valueKey: valueKey,
      labelKey: 'currency_code',
    );
  }

  Widget _buildSyncfusionPieChart({
    required String title,
    required List<Map<String, dynamic>> data,
    required String valueKey,
    required String labelKey,
  }) {
    // Sort data by value descending and limit to top 5 + others
    data.sort(
      (a, b) => (b[valueKey] as double).compareTo(a[valueKey] as double),
    );

    List<Map<String, dynamic>> displayData = [];
    if (data.length > 5) {
      displayData = data.take(5).toList();
      double othersValue = data
          .skip(5)
          .fold(0.0, (sum, item) => sum + (item[valueKey] as double));
      displayData.add({labelKey: 'Others', valueKey: othersValue});
    } else {
      displayData = data;
    }

    final totalAmount = displayData.fold(
      0.0,
      (sum, item) => sum + (item[valueKey] as double),
    );

    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              height: 300,
              child: SfCircularChart(
                title: ChartTitle(text: 'Distribution by Amount'),
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                series: <CircularSeries>[
                  PieSeries<Map<String, dynamic>, String>(
                    dataSource: displayData,
                    xValueMapper:
                        (Map<String, dynamic> data, _) =>
                            data[labelKey] as String,
                    yValueMapper:
                        (Map<String, dynamic> data, _) =>
                            data[valueKey] as double,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      labelIntersectAction: LabelIntersectAction.shift,
                      connectorLineSettings: ConnectorLineSettings(
                        type: ConnectorType.curve,
                        length: '20%',
                      ),
                    ),
                    enableTooltip: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Total: ${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(dynamic data) {
    // Implementation of _buildLineChart method
    return Center(child: Text('Line Chart - Coming Soon'));
  }
}

// Helper methods for display names
String _getChartTypeName(ChartType type) {
  switch (type) {
    case ChartType.pie:
      return 'Pie Chart';
    case ChartType.line:
      return 'Line Chart';
  }
}

String _getPieSubTypeName(PieSubType subType) {
  switch (subType) {
    case PieSubType.bought:
      return 'Bought';
    case PieSubType.sold:
      return 'Sold';
  }
} 