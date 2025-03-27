import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../db_helper.dart';

class AnalyticsDiagramScreen extends StatefulWidget {
  @override
  _AnalyticsDiagramScreenState createState() => _AnalyticsDiagramScreenState();
}

class _AnalyticsDiagramScreenState extends State<AnalyticsDiagramScreen> {
  // Current selected chart type
  ChartType _selectedChartType = ChartType.pie;
  // Current selected pie subtype
  PieSubType _selectedPieSubType = PieSubType.bought;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Currency Analytics')),
      body: Column(
        children: [
          // Chart type selector
          _buildChartTypeSelector(),
          // Pie subtype selector (only visible when pie is selected)
          if (_selectedChartType == ChartType.pie) _buildPieSubTypeSelector(),
          // Main chart area
          Expanded(child: _buildCurrentChart()),
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

  Widget _buildCurrentChart() {
    switch (_selectedChartType) {
      case ChartType.pie:
        return _buildPieChart();
      case ChartType.bar:
        return Center(child: Text('Bar Chart - Coming Soon'));
      case ChartType.line:
        return Center(child: Text('Line Chart - Coming Soon'));
      default:
        return Center(child: Text('Select a chart type'));
    }
  }

  Widget _buildPieChart() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dbHelper.getPieChartData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading data'));
        }

        final data = snapshot.data!;
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
      },
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
                'Total: \$${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Enums for chart types
enum ChartType { pie, bar, line }

enum PieSubType { bought, sold }

// Helper methods for display names
String _getChartTypeName(ChartType type) {
  switch (type) {
    case ChartType.pie:
      return 'Pie Chart';
    case ChartType.bar:
      return 'Bar Chart';
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
