import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../db_helper.dart';

class ExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> exportData({
    required DateTime startDate,
    required DateTime endDate,
    required String format,
    required String fileName,
    required String exportType,
  }) async {
    // Get the Documents directory
    final directory = Directory('/storage/emulated/0/Documents');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    String filePath;

    if (format == 'excel') {
      filePath = await _exportToExcel(directory, fileName, startDate, endDate, exportType);
    } else {
      filePath = await _exportToPdf(directory, fileName, startDate, endDate, exportType);
    }

    return filePath;
  }

  Future<String> _exportToExcel(
    Directory directory, 
    String fileName, 
    DateTime startDate, 
    DateTime endDate,
    String exportType,
  ) async {
    final excel = Excel.createExcel();
    
    if (exportType == 'history') {
      await _exportHistoryData(excel, startDate, endDate);
    } else {
      await _exportAnalyticsData(excel, startDate, endDate);
    }
    
    final filePath = '${directory.path}/${fileName}.xlsx';
    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file');
    }
    
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
    return filePath;
  }

  Future<String> _exportToPdf(
    Directory directory, 
    String fileName, 
    DateTime startDate, 
    DateTime endDate,
    String exportType,
  ) async {
    final pdf = pw.Document();
    
    if (exportType == 'history') {
      // Get history data
      final historyData = await _dbHelper.getFilteredHistoryByDate(
        fromDate: startDate,
        toDate: endDate,
      );
      
      // Create PDF content
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Transaction History Report'),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Period: ${DateFormat('dd-MM-yyyy').format(startDate)} to ${DateFormat('dd-MM-yyyy').format(endDate)}',
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Date', 'Currency', 'Operation', 'Rate', 'Quantity', 'Total'],
              data: historyData.map((entry) => [
                DateFormat('dd-MM-yyyy HH:mm').format(entry.createdAt),
                entry.currencyCode,
                entry.operationType,
                entry.rate.toStringAsFixed(2),
                entry.quantity.toStringAsFixed(2),
                entry.total.toStringAsFixed(2),
              ]).toList(),
            ),
          ],
        ),
      );
    } else {
      // Get analytics data
      final analyticsData = await _dbHelper.calculateAnalytics(
        startDate: startDate,
        endDate: endDate,
      );
      
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Analytics Report'),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Period: ${DateFormat('dd-MM-yyyy').format(startDate)} to ${DateFormat('dd-MM-yyyy').format(endDate)}',
            ),
            pw.SizedBox(height: 20),
            pw.Text('Total Profit: ${analyticsData['total_profit']}'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Currency', 'Avg Buy Rate', 'Total Bought', 'Avg Sell Rate', 'Total Sold', 'Profit'],
              data: (analyticsData['currency_stats'] as List).map((stat) => [
                stat['currency'],
                stat['avg_purchase_rate'].toStringAsFixed(2),
                stat['total_purchased'].toStringAsFixed(2),
                stat['avg_sale_rate'].toStringAsFixed(2),
                stat['total_sold'].toStringAsFixed(2),
                stat['profit'].toStringAsFixed(2),
              ]).toList(),
            ),
          ],
        ),
      );
    }
    
    final filePath = '${directory.path}/${fileName}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  // Export history data
  Future<void> _exportHistoryData(Excel excel, DateTime startDate, DateTime endDate) async {
    // Create a sheet for history data
    final sheet = excel['History'];
    
    // Add headers
    final headers = ['Date', 'Currency', 'Operation', 'Rate', 'Quantity', 'Total'];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers[i];
    }
    
    // Get history data
    final historyData = await _dbHelper.getFilteredHistoryByDate(
      fromDate: startDate,
      toDate: endDate,
    );
    
    // Add data rows
    for (var i = 0; i < historyData.length; i++) {
      final entry = historyData[i];
      final rowIndex = i + 1; // +1 because headers are at row 0
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
          DateFormat('dd-MM-yyyy HH:mm').format(entry.createdAt);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = entry.currencyCode;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = entry.operationType;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = entry.rate;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = entry.quantity;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = entry.total;
    }
    
    // Auto fit columns
    for (var i = 0; i < headers.length; i++) {
      sheet.setColWidth(i, 20.0); // Set a reasonable default width
    }
  }
  
  // Export analytics data
  Future<void> _exportAnalyticsData(Excel excel, DateTime startDate, DateTime endDate) async {
    // Get analytics data
    final analyticsData = await _dbHelper.calculateAnalytics(
      startDate: startDate,
      endDate: endDate,
    );
    
    // Create summary sheet
    final summarySheet = excel['Summary'];
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'Period';
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = 
        '${DateFormat('dd-MM-yyyy').format(startDate)} to ${DateFormat('dd-MM-yyyy').format(endDate)}';
    
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = 'Total Profit';
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = 
        analyticsData['total_profit'] as double;
    
    // Create currencies sheet
    final currencySheet = excel['Currency Statistics'];
    
    // Add headers
    final headers = [
      'Currency', 'Avg Purchase Rate', 'Total Purchased', 'Purchase Amount',
      'Avg Sale Rate', 'Total Sold', 'Sale Amount', 'Current Quantity', 'Profit'
    ];
    
    for (var i = 0; i < headers.length; i++) {
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers[i];
    }
    
    // Add data rows
    final currencyStats = analyticsData['currency_stats'] as List;
    for (var i = 0; i < currencyStats.length; i++) {
      final stat = currencyStats[i];
      final rowIndex = i + 1;
      
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
          stat['currency'] as String;
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = 
          stat['avg_purchase_rate'] as double;
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = 
          stat['total_purchased'] as double;
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = 
          stat['total_purchase_amount'] as double;
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = 
          stat['avg_sale_rate'] as double;
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = 
          stat['total_sold'] as double;
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = 
          stat['total_sale_amount'] as double;
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = 
          stat['current_quantity'] as double;
      currencySheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = 
          stat['profit'] as double;
    }
    
    // Auto fit columns
    for (var i = 0; i < headers.length; i++) {
      currencySheet.setColWidth(i, 20.0); // Set a reasonable default width
    }

    // Get daily profit data
    final dailyProfitData = await _dbHelper.getDailyProfitData(
      startDate: startDate,
      endDate: endDate,
    );

    // Create daily profit sheet
    final dailySheet = excel['Daily Profit'];
    dailySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'Date';
    dailySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = 'Profit';

    for (var i = 0; i < dailyProfitData.length; i++) {
      final day = dailyProfitData[i];
      final rowIndex = i + 1;
      dailySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
          day['day'] as String;
      dailySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = 
          day['profit'] as double;
    }

    // Set column widths for daily profit sheet
    dailySheet.setColWidth(0, 15.0); // Date column
    dailySheet.setColWidth(1, 15.0); // Profit column
  }
} 