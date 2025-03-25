import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import './models/currency.dart';
import './models/history.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('currency_converter.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Currencies Table
    await db.execute('''
      CREATE TABLE currencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        quantity REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // History Table
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        currency_code TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        rate REAL NOT NULL,
        quantity REAL NOT NULL,
        total REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Seed initial currencies
    final List<CurrencyModel> initialCurrencies = [
      CurrencyModel(code: 'USD', quantity: 0),
      CurrencyModel(code: 'EUR', quantity: 0),
      CurrencyModel(code: 'GBP', quantity: 0),
      CurrencyModel(code: 'JPY', quantity: 0),
      CurrencyModel(code: 'AUD', quantity: 0),
      CurrencyModel(code: 'CAD', quantity: 0),
    ];

    for (var currency in initialCurrencies) {
      await db.insert('currencies', currency.toMap());
    }
  }

  // Currencies CRUD Operations
  Future<CurrencyModel> createOrUpdateCurrency(CurrencyModel currency) async {
    final db = await instance.database;

    // Try to update existing currency
    final updateCount = await db.update(
      'currencies',
      currency.toMap(),
      where: 'code = ?',
      whereArgs: [currency.code],
    );

    // If no row was updated, insert new currency
    if (updateCount == 0) {
      currency = currency.copyWith(
        id: await db.insert('currencies', currency.toMap()),
      );
    }

    return currency;
  }

  Future<CurrencyModel?> getCurrency(String code) async {
    final db = await instance.database;
    final maps = await db.query(
      'currencies',
      where: 'code = ?',
      whereArgs: [code],
    );

    return maps.isNotEmpty ? CurrencyModel.fromMap(maps.first) : null;
  }

  Future<int> insertCurrency(CurrencyModel currency) async {
    final db = await instance.database;
    return await db.insert(
      'currencies',
      currency.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteCurrency(int id) async {
    final db = await instance.database;
    return await db.delete('currencies', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CurrencyModel>> getAllCurrencies() async {
    final db = await instance.database;
    final maps = await db.query('currencies', orderBy: 'updated_at DESC');
    return maps.map((map) => CurrencyModel.fromMap(map)).toList();
  }

  Future<List<HistoryModel>> getFilteredHistoryByDate({
    required DateTime fromDate,
    required DateTime toDate,
    String? currencyCode,
    String? operationType,
  }) async {
    final db = await instance.database;

    final whereParts = <String>['created_at BETWEEN ? AND ?'];
    final whereArgs = <dynamic>[
      fromDate.toIso8601String(),
      toDate.toIso8601String(),
    ];

    if (currencyCode != null && currencyCode.isNotEmpty) {
      whereParts.add('currency_code = ?');
      whereArgs.add(currencyCode);
    }

    if (operationType != null && operationType.isNotEmpty) {
      whereParts.add('operation_type = ?');
      whereArgs.add(operationType);
    }

    final where = whereParts.join(' AND ');

    final maps = await db.query(
      'history',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => HistoryModel.fromMap(map)).toList();
  }

  // History CRUD Operations
  Future<HistoryModel> createHistoryEntry(HistoryModel historyEntry) async {
    final db = await instance.database;
    final id = await db.insert('history', historyEntry.toMap());
    return historyEntry.copyWith(id: id);
  }

  Future<List<HistoryModel>> getHistoryEntries({
    int? limit,
    String? currencyCode,
  }) async {
    final db = await instance.database;

    String? where;
    List<dynamic>? whereArgs;

    if (currencyCode != null) {
      where = 'currency_code = ?';
      whereArgs = [currencyCode];
    }

    final maps = await db.query(
      'history',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => HistoryModel.fromMap(map)).toList();
  }

  // Transaction to update currency and create history entry
  Future<void> performCurrencyOperation({
    required String currencyCode,
    required String operationType,
    required double rate,
    required double quantity,
    required double total,
  }) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // Get current currency
      final currencyMaps = await txn.query(
        'currencies',
        where: 'code = ?',
        whereArgs: [currencyCode],
      );

      // Update currency quantity based on operation type
      double currentQuantity =
          currencyMaps.isNotEmpty
              ? currencyMaps.first['quantity'] as double
              : 0.0;

      final updatedQuantity =
          operationType == 'Purchase'
              ? currentQuantity + quantity
              : currentQuantity - quantity;

      // Update currency
      await txn.update(
        'currencies',
        {
          'quantity': updatedQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'code = ?',
        whereArgs: [currencyCode],
      );

      // Create history entry
      await txn.insert('history', {
        'currency_code': currencyCode,
        'operation_type': operationType,
        'rate': rate,
        'quantity': quantity,
        'total': total,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  // Utility method to get summary
  Future<Map<String, dynamic>> getCurrencySummary() async {
    final db = await instance.database;

    // Get total quantities
    final quantityResults = await db.rawQuery(
      'SELECT currency_code, SUM(quantity) as total_quantity, '
      'SUM(CASE WHEN operation_type = "Purchase" THEN total ELSE -total END) as net_total '
      'FROM history GROUP BY currency_code',
    );

    return {
      'currency_quantities': {
        for (var result in quantityResults)
          result['currency_code']: {
            'total_quantity': result['total_quantity'],
            'net_total': result['net_total'],
          },
      },
    };
  }

  Future<List<String>> getHistoryCurrencyCodes() async {
    final db = await instance.database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT currency_code FROM history ORDER BY currency_code',
    );
    return maps.map((map) => map['currency_code'] as String).toList();
  }

  // Get all operation types from history
  Future<List<String>> getHistoryOperationTypes() async {
    final db = await instance.database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT operation_type FROM history ORDER BY operation_type',
    );
    return maps.map((map) => map['operation_type'] as String).toList();
  }

  // Get filtered history with pagination
  Future<List<HistoryModel>> getFilteredHistory({
    String? currencyCode,
    String? operationType,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await instance.database;

    final whereParts = <String>[];
    final whereArgs = <dynamic>[];

    if (currencyCode != null && currencyCode.isNotEmpty) {
      whereParts.add('currency_code = ?');
      whereArgs.add(currencyCode);
    }

    if (operationType != null && operationType.isNotEmpty) {
      whereParts.add('operation_type = ?');
      whereArgs.add(operationType);
    }

    final where = whereParts.isNotEmpty ? whereParts.join(' AND ') : null;

    final maps = await db.query(
      'history',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => HistoryModel.fromMap(map)).toList();
  }

  // Close database
  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}

// Extension for easy copying of models
extension CurrencyModelCopy on CurrencyModel {
  CurrencyModel copyWith({
    int? id,
    String? code,
    double? quantity,
    DateTime? updatedAt,
  }) {
    return CurrencyModel(
      id: id ?? this.id,
      code: code ?? this.code,
      quantity: quantity ?? this.quantity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension HistoryModelCopy on HistoryModel {
  HistoryModel copyWith({
    int? id,
    String? currencyCode,
    String? operationType,
    double? rate,
    double? quantity,
    double? total,
    DateTime? createdAt,
  }) {
    return HistoryModel(
      id: id ?? this.id,
      currencyCode: currencyCode ?? this.currencyCode,
      operationType: operationType ?? this.operationType,
      rate: rate ?? this.rate,
      quantity: quantity ?? this.quantity,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
