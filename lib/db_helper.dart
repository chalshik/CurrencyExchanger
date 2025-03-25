import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import './models/currency.dart';
import './models/history.dart';

/// Main database helper class for currency conversion operations
class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get database instance (initialize if needed)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('currency_converter.db');
    return _database!;
  }

  /// Initialize database file
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  /// Create database tables
  Future<void> _createDB(Database db, int version) async {
    // Create currencies table
    await db.execute('''
      CREATE TABLE currencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        quantity REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create history table
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

    // Initialize with SOM currency
    final somCurrency = CurrencyModel(code: 'SOM', quantity: 0);
    await db.insert('currencies', somCurrency.toMap());
  }

  // ========================
  // CURRENCY CRUD OPERATIONS
  // ========================

  /// Create or update currency record
  Future<CurrencyModel> createOrUpdateCurrency(CurrencyModel currency) async {
    final db = await instance.database;

    // Try update first
    final updateCount = await db.update(
      'currencies',
      currency.toMap(),
      where: 'code = ?',
      whereArgs: [currency.code],
    );

    // Insert if doesn't exist
    if (updateCount == 0) {
      currency = currency.copyWith(
        id: await db.insert('currencies', currency.toMap()),
      );
    }

    return currency;
  }

  /// Get currency by code
  Future<CurrencyModel?> getCurrency(String code) async {
    final db = await instance.database;
    final maps = await db.query(
      'currencies',
      where: 'code = ?',
      whereArgs: [code],
    );
    return maps.isNotEmpty ? CurrencyModel.fromMap(maps.first) : null;
  }

  /// Insert new currency
  Future<int> insertCurrency(CurrencyModel currency) async {
    final db = await instance.database;
    return await db.insert(
      'currencies',
      currency.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete currency by ID
  Future<int> deleteCurrency(int id) async {
    final db = await instance.database;
    return await db.delete('currencies', where: 'id = ?', whereArgs: [id]);
  }

  /// Get all currencies (except SOM)
  Future<List<CurrencyModel>> getAllCurrencies() async {
    final db = await instance.database;
    final maps = await db.query('currencies', orderBy: 'updated_at DESC');
    print(maps.map((map) => CurrencyModel.fromMap(map)).toList());
    print(maps.last.values);
    print(maps.last["quantity"]);
    return maps.map((map) => CurrencyModel.fromMap(map)).toList();
  }

  // =====================
  // BALANCE OPERATIONS
  // =====================

  /// Add amount to SOM balance
  Future<void> addToSomBalance(double amount) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // Get current SOM balance
      final somMaps = await txn.query(
        'currencies',
        where: 'code = ?',
        whereArgs: ['SOM'],
      );

      if (somMaps.isEmpty) throw Exception('SOM currency not found');
      print(somMaps.first['quantity']);
      print("this one");
      // Calculate new balance
      final newBalance = (somMaps.first['quantity'] as double) + amount;

      // Update SOM balance
      await txn.update(
        'currencies',
        {
          'quantity': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'code = ?',
        whereArgs: ['SOM'],
      );

      // Record deposit in history
      await txn.insert('history', {
        'currency_code': 'SOM',
        'operation_type': 'Deposit',
        'rate': 1.0,
        'quantity': amount,
        'total': amount,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Check if enough SOM available for purchase
  Future<bool> hasEnoughSomForPurchase(double requiredSom) async {
    final db = await instance.database;
    final somMaps = await db.query(
      'currencies',
      where: 'code = ?',
      whereArgs: ['SOM'],
    );

    if (somMaps.isEmpty) return false;

    // Safely extract and convert quantity
    final quantity = (somMaps.first['quantity'] as num?)?.toDouble() ?? 0.0;

    return quantity >= requiredSom;
  }

  /// Check if enough currency available to sell
  Future<bool> hasEnoughCurrencyToSell(
    String currencyCode,
    double quantity,
  ) async {
    if (currencyCode == 'SOM') return false;

    final db = await instance.database;
    final currencyMaps = await db.query(
      'currencies',
      where: 'code = ?',
      whereArgs: [currencyCode],
    );

    if (currencyMaps.isEmpty) return false;

    // Safely extract and convert quantity
    final availableQuantity =
        (currencyMaps.first['quantity'] as num?)?.toDouble() ?? 0.0;

    return availableQuantity >= quantity;
  }

  // =====================
  // CURRENCY EXCHANGE
  // =====================

  Future<void> performCurrencyExchange({
    required String currencyCode,
    required String operationType, // 'Buy' or 'Sell'
    required double rate,
    required double quantity,
  }) async {
    final db = await instance.database;

    try {
      // 1. Get SOM balance
      final somResult = await db.query(
        'currencies',
        where: 'code = ?',
        whereArgs: ['SOM'],
      );

      if (somResult.isEmpty) {
        throw Exception('SOM currency not found');
      }

      final somBalance = (somResult.first['quantity'] as num).toDouble();
      final totalSom = quantity * rate;

      // 2. Get target currency balance
      final targetResult = await db.query(
        'currencies',
        where: 'code = ?',
        whereArgs: [currencyCode],
      );
      print(currencyCode);
      print(targetResult);
      double targetBalance =
          targetResult.isNotEmpty
              ? (targetResult.first['quantity'] as num).toDouble()
              : 0.0;
      print(operationType);
      if (operationType == 'Purchase') {
        // Validate purchase
        if (somBalance < totalSom) {
          throw Exception('Not enough SOM to perform this operation');
        }

        // Update SOM balance (deduct total)
        await db.update(
          'currencies',
          {
            'quantity': somBalance - totalSom,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'code = ?',
          whereArgs: ['SOM'],
        );
        print(targetResult.isNotEmpty);
        // Update or create target currency (add quantity)
        if (targetResult.isNotEmpty) {
          print("targetvalue");
          await db.update(
            'currencies',
            {
              'quantity': targetBalance + quantity,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'code = ?',
            whereArgs: [currencyCode],
          );
        } else {
          print("isnottarget");
          await db.insert('currencies', {
            'code': currencyCode,
            'quantity': quantity,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      } else if (operationType == 'Sale') {
        print('sell');
        // Validate sale
        if (targetBalance < quantity) {
          throw Exception('Not enough $currencyCode to perform this operation');
        }

        // Update SOM balance (add total)
        await db.update(
          'currencies',
          {
            'quantity': somBalance + totalSom,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'code = ?',
          whereArgs: ['SOM'],
        );

        // Update target currency (deduct quantity)
        await db.update(
          'currencies',
          {
            'quantity': targetBalance - quantity,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'code = ?',
          whereArgs: [currencyCode],
        );
      }

      // Record transaction in history
      await db.insert('history', {
        'currency_code': currencyCode,
        'operation_type': operationType,
        'rate': rate,
        'quantity': quantity,
        'total': totalSom,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error performing currency exchange: $e');
      rethrow;
    }
  }

  // Helper method to update or create currency
  Future<void> _updateCurrencyBalance(
    Transaction txn,
    String code,
    double newBalance,
  ) async {
    await txn.update(
      'currencies',
      {'quantity': newBalance, 'updated_at': DateTime.now().toIso8601String()},
      where: 'code = ?',
      whereArgs: [code],
    );
  }

  // Helper method to create or update currency
  Future<void> _updateOrCreateCurrency(
    Transaction txn,
    String code,
    double newBalance,
  ) async {
    final existing = await txn.query(
      'currencies',
      where: 'code = ?',
      whereArgs: [code],
    );

    if (existing.isEmpty) {
      await txn.insert('currencies', {
        'code': code,
        'quantity': newBalance,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      await _updateCurrencyBalance(txn, code, newBalance);
    }
  }

  // =====================
  // HISTORY OPERATIONS
  // =====================

  /// Get filtered history by date range
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

  /// Create new history entry
  Future<HistoryModel> createHistoryEntry(HistoryModel historyEntry) async {
    final db = await instance.database;
    final id = await db.insert('history', historyEntry.toMap());
    return historyEntry.copyWith(id: id);
  }

  /// Get history entries with optional filters
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

  /// Get summary of all currency balances
  Future<Map<String, dynamic>> getCurrencySummary() async {
    final db = await instance.database;

    // Get SOM balance
    final somResult = await db.query(
      'currencies',
      where: 'code = ?',
      whereArgs: ['SOM'],
    );

    // Get other currencies
    final otherCurrencies = await db.query(
      'currencies',
      where: 'code != ?',
      whereArgs: ['SOM'],
    );

    return {
      'som_balance': somResult.isNotEmpty ? somResult.first['quantity'] : 0,
      'other_currencies': {
        for (var currency in otherCurrencies)
          currency['code']: currency['quantity'],
      },
    };
  }

  /// Get list of unique currency codes from history
  Future<List<String>> getHistoryCurrencyCodes() async {
    final db = await instance.database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT currency_code FROM history ORDER BY currency_code',
    );
    return maps.map((map) => map['currency_code'] as String).toList();
  }

  /// Get list of unique operation types from history
  Future<List<String>> getHistoryOperationTypes() async {
    final db = await instance.database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT operation_type FROM history ORDER BY operation_type',
    );
    return maps.map((map) => map['operation_type'] as String).toList();
  }

  /// Close database connection
  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}

// Extension methods for model copying
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
