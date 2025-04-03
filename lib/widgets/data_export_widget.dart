import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../db_helper.dart';
import '../models/history.dart';

class DataExportWidget extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const DataExportWidget({super.key, required this.dbHelper});

  @override
  State<DataExportWidget> createState() => _DataExportWidgetState();
}

class _DataExportWidgetState extends State<DataExportWidget> {
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedFormat = 'excel';

  @override
  void dispose() {
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
          _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _endDate = picked;
          _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  Future<void> _exportData() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end dates')),
      );
      return;
    }

    try {
      final historyList = await widget.dbHelper.getFilteredHistoryByDate(
        fromDate: _startDate!,
        toDate: _endDate!,
      );

      // Convert HistoryModel list to Map list
      final transactions =
          historyList
              .map(
                (history) => {
                  'date': history.createdAt,
                  'currency': history.currencyCode,
                  'type': history.operationType,
                  'amount': history.quantity,
                  'rate': history.rate,
                  'total': history.total,
                  'user': 'System', // Since we don't have user info in history
                },
              )
              .toList();

      if (_selectedFormat == 'excel') {
        await _exportToExcel(transactions);
      } else {
        await _exportToPDF(transactions);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> transactions) async {
    final excel = Excel.createExcel();
    final sheet = excel['Transactions'];

    // Add headers
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Currency'),
      TextCellValue('Type'),
      TextCellValue('Amount'),
      TextCellValue('Rate'),
      TextCellValue('Total'),
      TextCellValue('User'),
    ]);

    // Add data
    for (final transaction in transactions) {
      sheet.appendRow([
        TextCellValue(
          DateFormat('yyyy-MM-dd').format(DateTime.parse(transaction['date'])),
        ),
        TextCellValue(transaction['currency'].toString()),
        TextCellValue(transaction['type'].toString()),
        TextCellValue(transaction['amount'].toString()),
        TextCellValue(transaction['rate'].toString()),
        TextCellValue(transaction['total'].toString()),
        TextCellValue(transaction['user'].toString()),
      ]);
    }

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
    );
    await file.writeAsBytes(excel.encode()!);
  }

  Future<void> _exportToPDF(List<Map<String, dynamic>> transactions) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children:
                    [
                          'Date',
                          'Currency',
                          'Type',
                          'Amount',
                          'Rate',
                          'Total',
                          'User',
                        ]
                        .map(
                          (header) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(header),
                          ),
                        )
                        .toList(),
              ),
              ...transactions.map((transaction) {
                return pw.TableRow(
                  children:
                      [
                            DateFormat(
                              'yyyy-MM-dd',
                            ).format(DateTime.parse(transaction['date'])),
                            transaction['currency'].toString(),
                            transaction['type'].toString(),
                            transaction['amount'].toString(),
                            transaction['rate'].toString(),
                            transaction['total'].toString(),
                            transaction['user'].toString(),
                          ]
                          .map(
                            (value) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(value),
                            ),
                          )
                          .toList(),
                );
              }).toList(),
            ],
          );
        },
      ),
    );

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Export',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _startDateController,
                decoration: const InputDecoration(
                  labelText: 'Start Date',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _endDateController,
                decoration: const InputDecoration(
                  labelText: 'End Date',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedFormat,
          decoration: const InputDecoration(
            labelText: 'Export Format',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'excel', child: Text('Excel')),
            DropdownMenuItem(value: 'pdf', child: Text('PDF')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedFormat = value;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _exportData,
          child: const Text('Export Data'),
        ),
      ],
    );
  }
}
