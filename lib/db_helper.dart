import 'package:flutter/foundation.dart';
import 'dart:convert';
import './models/currency.dart';
import './models/history.dart';
import './models/user.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Main database helper class for SQLite local storage operations
class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();

  // Database version
  static const _dbVersion = 1;
  
  // Database instance
  Database? _database;

  // Tables
  static const String tableCurrencies = 'currencies';
  static const String tableHistory = 'history';
  static const String tableUsers = 'users';

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  DatabaseHelper._init();

  // Initialize the database
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'currency_changer.db');
    
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDb,
    );
  }

  // Create database tables
  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableCurrencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        quantity REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        default_buy_rate REAL NOT NULL DEFAULT 0,
        default_sell_rate REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        currency_code TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        rate REAL NOT NULL,
        quantity REAL NOT NULL,
        total REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableUsers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Initialize SOM currency
    await db.insert(tableCurrencies, {
      'code': 'SOM',
      'quantity': 0.0,
      'updated_at': DateTime.now().toIso8601String(),
      'default_buy_rate': 1.0,
      'default_sell_rate': 1.0,
    });

    // Create admin user
    await db.insert(tableUsers, {
      'username': 'a',
      'password': 'a',
      'role': 'admin',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Helper method to check if database exists
  Future<bool> _databaseExists() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'currency_changer.db');
    return await File(path).exists();
  }

  // Helper function to safely convert values to double
  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Check database availability - always returns true since this is local SQLite
  Future<bool> verifyDatabaseAvailability() async {
    return true;
  }

  // ========================
  // CURRENCY CRUD OPERATIONS
  // ========================

  Future<CurrencyModel> createOrUpdateCurrency(CurrencyModel currency) async {
    try {
      final db = await database;
      
      // Check if currency exists
      final List<Map<String, dynamic>> result = await db.query(
        tableCurrencies,
        where: 'code = ?',
        whereArgs: [currency.code],
      );
      
      if (result.isNotEmpty) {
        // Update existing currency
        await db.update(
          tableCurrencies,
          currency.toMap(),
          where: 'code = ?',
          whereArgs: [currency.code],
        );
      } else {
        // Insert new currency
        final id = await db.insert(tableCurrencies, currency.toMap());
        currency = currency.copyWith(id: id);
      }
      
      return currency;
    } catch (e) {
      debugPrint('Error in createOrUpdateCurrency: $e');
      rethrow;
    }
  }

  /// Get currency by code
  Future<CurrencyModel?> getCurrency(String code) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        tableCurrencies,
        where: 'code = ?',
        whereArgs: [code],
      );
      
      if (result.isNotEmpty) {
        return CurrencyModel.fromMap(result.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error in getCurrency: $e');
      rethrow;
    }
  }

  /// Insert new currency
  Future<int> insertCurrency(CurrencyModel currency) async {
    try {
      final db = await database;
      return await db.insert(tableCurrencies, currency.toMap());
    } catch (e) {
      debugPrint('Error in insertCurrency: $e');
      rethrow;
    }
  }

  /// Delete currency by ID
  Future<int> deleteCurrency(int id) async {
    try {
      final db = await database;
      return await db.delete(
        tableCurrencies,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error in deleteCurrency: $e');
      return 0; // Return 0 to indicate failure
    }
  }

  /// Get all currencies
  Future<List<CurrencyModel>> getAllCurrencies() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(tableCurrencies);
      
      return result.map((item) => CurrencyModel.fromMap(item)).toList();
    } catch (e) {
      debugPrint('Error in getAllCurrencies: $e');
      return [];
    }
  }

  /// Update currency
  Future<void> updateCurrency(CurrencyModel currency) async {
    try {
      final db = await database;
      await db.update(
        tableCurrencies,
        currency.toMap(),
        where: 'id = ?',
        whereArgs: [currency.id],
      );
    } catch (e) {
      debugPrint('Error in updateCurrency: $e');
      rethrow;
    }
  }

  /// Update currency quantity
  Future<void> updateCurrencyQuantity(String code, double newQuantity) async {
    try {
      final db = await database;
      await db.update(
        tableCurrencies,
        {
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'code = ?',
        whereArgs: [code],
      );
    } catch (e) {
      debugPrint('Error in updateCurrencyQuantity: $e');
      rethrow;
    }
  }

  // =====================
  // SYSTEM OPERATIONS
  // =====================

  /// Reset all data
  Future<void> resetAllData() async {
    try {
      final db = await database;
      
      // Only clear history table
      await db.delete(tableHistory);
      
      // Reset all currency quantities to 0, but keep the currencies
      final currencies = await getAllCurrencies();
      for (var currency in currencies) {
        await updateCurrencyQuantity(currency.code!, 0.0);
      }
      
      debugPrint('Transaction history reset. Currency quantities reset to 0. Users preserved.');
    } catch (e) {
      debugPrint('Error in resetAllData: $e');
      rethrow;
    }
  }

  /// Get summary of all currency balances
  Future<Map<String, dynamic>> getCurrencySummary() async {
    try {
      final db = await database;
      
      // Get SOM balance
      final somResult = await db.query(
        tableCurrencies,
        where: 'code = ?',
        whereArgs: ['SOM'],
      );
      
      double somBalance = 0.0;
      if (somResult.isNotEmpty) {
        somBalance = _safeDouble(somResult.first['quantity']);
      }
      
      // Get other currencies
      final currenciesResult = await db.query(
        tableCurrencies,
        where: 'code != ?',
        whereArgs: ['SOM'],
      );
      
      final otherCurrencies = <String, dynamic>{};
      for (var currency in currenciesResult) {
        otherCurrencies[currency['code'] as String] = {
          'quantity': _safeDouble(currency['quantity']),
          'default_buy_rate': _safeDouble(currency['default_buy_rate']),
          'default_sell_rate': _safeDouble(currency['default_sell_rate']),
        };
      }
      
      return {
        'som_balance': somBalance,
        'other_currencies': otherCurrencies,
      };
    } catch (e) {
      debugPrint('Error in getCurrencySummary: $e');
      return {'som_balance': 0, 'other_currencies': {}};
    }
  }

  // =====================
  // BALANCE OPERATIONS
  // =====================

  /// Add amount to SOM balance
  Future<void> addToSomBalance(double amount) async {
    try {
      final db = await database;
      
      // Get current SOM currency
      final somResult = await db.query(
        tableCurrencies,
        where: 'code = ?',
        whereArgs: ['SOM'],
      );
      
      if (somResult.isEmpty) {
        throw Exception('SOM currency not found');
      }
      
      final som = CurrencyModel.fromMap(somResult.first);

      // Calculate new balance
      final newBalance = som.quantity + amount;

      // Update SOM balance
      await db.update(
        tableCurrencies,
        {
          'quantity': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'code = ?',
        whereArgs: ['SOM'],
      );

      // Record deposit in history
      await db.insert(tableHistory, {
        'currency_code': 'SOM',
        'operation_type': 'Deposit',
        'rate': 1.0,
        'quantity': amount,
        'total': amount,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error in addToSomBalance: $e');
      rethrow;
    }
  }

  /// Check if enough SOM available for purchase
  Future<bool> hasEnoughSomForPurchase(double requiredSom) async {
    try {
      final db = await database;
      
      final somResult = await db.query(
        tableCurrencies,
        where: 'code = ?',
        whereArgs: ['SOM'],
      );
      
      if (somResult.isNotEmpty) {
        final som = CurrencyModel.fromMap(somResult.first);
        return som.quantity >= requiredSom;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error in hasEnoughSomForPurchase: $e');
      return false;
    }
  }

  /// Check if enough currency available to sell
  Future<bool> hasEnoughCurrencyToSell(
    String currencyCode,
    double quantity,
  ) async {
    try {
      if (currencyCode == 'SOM') return false;

      final db = await database;
      
      final currencyResult = await db.query(
        tableCurrencies,
        where: 'code = ?',
        whereArgs: [currencyCode],
      );
      
      if (currencyResult.isNotEmpty) {
        final currency = CurrencyModel.fromMap(currencyResult.first);
        return currency.quantity >= quantity;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error in hasEnoughCurrencyToSell: $e');
      return false;
    }
  }

  // =====================
  // CURRENCY EXCHANGE
  // =====================

  Future<void> performCurrencyExchange({
    required String currencyCode,
    required String operationType,
    required double rate,
    required double quantity,
  }) async {
    try {
      final db = await database;
      final totalSom = quantity * rate;

      // Run in transaction to ensure data integrity
      await db.transaction((txn) async {
        if (operationType == 'Buy') {
          // Check if we have enough SOM
          final somResult = await txn.query(
            tableCurrencies,
            where: 'code = ?',
            whereArgs: ['SOM'],
          );
          
          if (somResult.isEmpty) {
            throw Exception('SOM currency not found');
          }
          
          final som = CurrencyModel.fromMap(somResult.first);
          if (som.quantity < totalSom) {
            throw Exception('Insufficient SOM balance for purchase');
          }
          
          // Update SOM quantity (decrease)
          await txn.update(
            tableCurrencies,
            {
              'quantity': som.quantity - totalSom,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'code = ?',
            whereArgs: ['SOM'],
          );
          
          // Update foreign currency quantity (increase)
          final currencyResult = await txn.query(
            tableCurrencies,
            where: 'code = ?',
            whereArgs: [currencyCode],
          );
          
          if (currencyResult.isNotEmpty) {
            final currency = CurrencyModel.fromMap(currencyResult.first);
            await txn.update(
              tableCurrencies,
              {
                'quantity': currency.quantity + quantity,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'code = ?',
              whereArgs: [currencyCode],
            );
          } else {
            // Currency doesn't exist, create it
            await txn.insert(tableCurrencies, {
              'code': currencyCode,
              'quantity': quantity,
              'updated_at': DateTime.now().toIso8601String(),
              'default_buy_rate': rate,
              'default_sell_rate': rate * 1.02, // 2% markup as default
            });
          }
        } else if (operationType == 'Sell') {
          // Check if we have enough of the foreign currency
          final currencyResult = await txn.query(
            tableCurrencies,
            where: 'code = ?',
            whereArgs: [currencyCode],
          );
          
          if (currencyResult.isEmpty) {
            throw Exception('Currency not found: $currencyCode');
          }
          
          final currency = CurrencyModel.fromMap(currencyResult.first);
          if (currency.quantity < quantity) {
            throw Exception('Insufficient $currencyCode balance for sale');
          }
          
          // Update foreign currency quantity (decrease)
          await txn.update(
            tableCurrencies,
            {
              'quantity': currency.quantity - quantity,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'code = ?',
            whereArgs: [currencyCode],
          );
          
          // Update SOM quantity (increase)
          final somResult = await txn.query(
            tableCurrencies,
            where: 'code = ?',
            whereArgs: ['SOM'],
          );
          
          if (somResult.isNotEmpty) {
            final som = CurrencyModel.fromMap(somResult.first);
            await txn.update(
              tableCurrencies,
              {
                'quantity': som.quantity + totalSom,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'code = ?',
              whereArgs: ['SOM'],
            );
          } else {
            throw Exception('SOM currency not found');
          }
        }
        
        // Record transaction in history
        await txn.insert(tableHistory, {
          'currency_code': currencyCode,
          'operation_type': operationType,
          'rate': rate,
          'quantity': quantity,
          'total': totalSom,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
    } catch (e) {
      debugPrint('Error in performCurrencyExchange: $e');
      rethrow;
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
    try {
      final db = await database;
      
      final fromDateStr = fromDate.toIso8601String();
      final toDateStr = toDate.toIso8601String();
      
      String whereClause = 'created_at BETWEEN ? AND ?';
      List<dynamic> whereArgs = [fromDateStr, toDateStr];

      if (currencyCode != null && currencyCode.isNotEmpty) {
        whereClause += ' AND currency_code = ?';
        whereArgs.add(currencyCode);
      }

      if (operationType != null && operationType.isNotEmpty) {
        whereClause += ' AND operation_type = ?';
        whereArgs.add(operationType);
      }
      
      final List<Map<String, dynamic>> result = await db.query(
        tableHistory,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );
      
      return result.map((item) => HistoryModel.fromMap(item)).toList();
    } catch (e) {
      debugPrint('Error in getFilteredHistoryByDate: $e');
      return [];
    }
  }

  /// Create new history entry
  Future<HistoryModel> createHistoryEntry(HistoryModel historyEntry) async {
    try {
      final db = await database;
      
      final id = await db.insert(tableHistory, historyEntry.toMap());
      
      return historyEntry.copyWith(id: id);
    } catch (e) {
      debugPrint('Error in createHistoryEntry: $e');
      rethrow;
    }
  }

  /// Get history entries with optional filters
  Future<List<HistoryModel>> getHistoryEntries({
    int? limit,
    String? currencyCode,
  }) async {
    try {
      final db = await database;

      String? whereClause;
      List<dynamic>? whereArgs;

      if (currencyCode != null && currencyCode.isNotEmpty) {
        whereClause = 'currency_code = ?';
        whereArgs = [currencyCode];
      }
      
      final List<Map<String, dynamic>> result = await db.query(
        tableHistory,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
        limit: limit,
      );
      
      return result.map((item) => HistoryModel.fromMap(item)).toList();
    } catch (e) {
      debugPrint('Error in getHistoryEntries: $e');
      return [];
    }
  }

  /// Update history
  Future<int> updateHistory({
    required HistoryModel newHistory,
    required HistoryModel oldHistory,
  }) async {
    try {
      final db = await database;
      
      // Debug output to track the update process
      debugPrint('Updating history entry:');
      debugPrint('Old entry: ${oldHistory.toString()}');
      debugPrint('New entry: ${newHistory.toString()}');
      
      // Convert to maps for detailed comparison
      final oldMap = oldHistory.toMap();
      final newMap = newHistory.toMap();
      
      // Print what changed
      final changes = <String>[];
      newMap.forEach((key, value) {
        if (oldMap[key] != value && key != 'id') {
          changes.add('$key: ${oldMap[key]} -> $value');
        }
      });
      
      debugPrint('Changes: ${changes.join(', ')}');
      debugPrint('Using ID for update: ${newHistory.id}');
      
      // Perform the update
      final result = await db.update(
        tableHistory,
        newHistory.toMap(),
        where: 'id = ?',
        whereArgs: [newHistory.id],
      );
      
      // Debug the result
      debugPrint('Update result (rows affected): $result');
      
      return result;
    } catch (e) {
      debugPrint('Error in updateHistory: $e');
      return 0; // Return 0 to indicate failure
    }
  }

  /// Delete history
  Future<int> deleteHistory(dynamic history) async {
    try {
      final db = await database;
      
      final id = history is HistoryModel ? history.id : history as int;

      return await db.delete(
        tableHistory,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error in deleteHistory: $e');
      return 0; // Return 0 to indicate failure
    }
  }

  /// Get list of unique currency codes from history
  Future<List<String>> getHistoryCurrencyCodes() async {
    try {
      final db = await database;
      
      final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT DISTINCT currency_code FROM $tableHistory ORDER BY currency_code'
      );
      
      return result.map((item) => item['currency_code'] as String).toList();
    } catch (e) {
      debugPrint('Error in getHistoryCurrencyCodes: $e');
      return [];
    }
  }

  /// Get list of unique operation types from history
  Future<List<String>> getHistoryOperationTypes() async {
    try {
      final db = await database;
      
      final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT DISTINCT operation_type FROM $tableHistory ORDER BY operation_type'
      );
      
      return result.map((item) => item['operation_type'] as String).toList();
    } catch (e) {
      debugPrint('Error in getHistoryOperationTypes: $e');
      return [];
    }
  }

  /// Insert history
  Future<int> insertHistory(HistoryModel history) async {
    try {
      final db = await database;
      
      return await db.insert(tableHistory, history.toMap());
    } catch (e) {
      debugPrint('Error in insertHistory: $e');
      return 0;
    }
  }

  // =====================
  // ANALYTICS OPERATIONS
  // =====================

  /// Calculate currency statistics for analytics
  Future<Map<String, dynamic>> calculateAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await database;
      
      // Set default date range if not provided
      final fromDate = startDate ?? DateTime(2000);
      final toDate = endDate ?? DateTime.now();
      
      // Get profitable currencies data
      final profitData = await getMostProfitableCurrencies(
        startDate: fromDate,
        endDate: toDate,
        limit: 1000, // High limit to get all currencies
      );

      // Get all currencies
      final currencies = await getAllCurrencies();

      // Combine data
      final currencyStats = <Map<String, dynamic>>[];
      double totalProfit = 0.0;

      for (var currency in currencies) {
        // Find matching profit data
        final profitEntry = profitData.firstWhere(
          (p) => p['currency_code'] == currency.code,
          orElse: () => <String, dynamic>{
                'amount': 0.0,
                'avg_purchase_rate': 0.0,
                'avg_sale_rate': 0.0,
                'total_purchased': 0.0,
                'total_sold': 0.0,
                'cost_of_sold': 0.0,
              },
        );

        final profit = _safeDouble(profitEntry['amount']);

        if (currency.code != 'SOM') {
          totalProfit += profit;
        }

        currencyStats.add({
          'currency': currency.code,
          'avg_purchase_rate': _safeDouble(profitEntry['avg_purchase_rate']),
          'total_purchased': _safeDouble(profitEntry['total_purchased']),
          'total_purchase_amount': _safeDouble(profitEntry['avg_purchase_rate']) *
              _safeDouble(profitEntry['total_purchased']),
          'avg_sale_rate': _safeDouble(profitEntry['avg_sale_rate']),
          'total_sold': _safeDouble(profitEntry['total_sold']),
          'total_sale_amount': _safeDouble(profitEntry['avg_sale_rate']) *
              _safeDouble(profitEntry['total_sold']),
          'current_quantity': currency.quantity,
          'profit': profit,
          'cost_of_sold': _safeDouble(profitEntry['cost_of_sold']),
        });
      }

      return {'currency_stats': currencyStats, 'total_profit': totalProfit};
    } catch (e) {
      debugPrint('Error in calculateAnalytics: $e');
      return {'currency_stats': [], 'total_profit': 0.0};
    }
  }

  /// Enhanced pie chart data with multiple metrics
  Future<Map<String, dynamic>> getEnhancedPieChartData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await database;
      
      // Set default date range if not provided
      final fromDate = startDate ?? DateTime(2000);
      final toDate = endDate ?? DateTime.now();
      
      final fromDateStr = fromDate.toIso8601String();
      final toDateStr = toDate.toIso8601String();
      
      // Get purchase data
      final purchaseQuery = '''
        SELECT 
          currency_code, 
          SUM(total) as total_value,
          COUNT(*) as count
        FROM $tableHistory
        WHERE operation_type = 'Purchase'
        AND created_at BETWEEN ? AND ?
        GROUP BY currency_code
        ORDER BY total_value DESC
      ''';
      
      final purchaseResult = await db.rawQuery(
        purchaseQuery,
        [fromDateStr, toDateStr],
      );
      
      // Get sales data
      final salesQuery = '''
        SELECT 
          currency_code, 
          SUM(total) as total_value,
          COUNT(*) as count
        FROM $tableHistory
        WHERE operation_type = 'Sale'
        AND created_at BETWEEN ? AND ?
        GROUP BY currency_code
        ORDER BY total_value DESC
      ''';
      
      final salesResult = await db.rawQuery(
        salesQuery,
        [fromDateStr, toDateStr],
      );
      
      // Format the data
      final purchases = purchaseResult.map((item) => {
        'currency': item['currency_code'],
        'total_value': _safeDouble(item['total_value']),
        'count': item['count'],
            }).toList();
      
      final sales = salesResult.map((item) => {
        'currency': item['currency_code'],
        'total_value': _safeDouble(item['total_value']),
        'count': item['count'],
            }).toList();
      
      return {'purchases': purchases, 'sales': sales};
    } catch (e) {
      debugPrint('Error in getEnhancedPieChartData: $e');
      return {'purchases': [], 'sales': []};
    }
  }

  Future<List<Map<String, dynamic>>> getDailyData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = await database;
      
      final fromDateStr = startDate.toIso8601String();
      final toDateStr = endDate.toIso8601String();

      debugPrint('Fetching daily data from $fromDateStr to $toDateStr');
      
      // First get purchase and sale data by date and currency
      final query = '''
        SELECT 
          substr(created_at, 1, 10) as date,
          currency_code,
          operation_type,
          SUM(total) as total_amount,
          SUM(quantity) as total_quantity,
          COUNT(*) as transaction_count
        FROM $tableHistory
        WHERE created_at BETWEEN ? AND ?
        GROUP BY substr(created_at, 1, 10), currency_code, operation_type
        ORDER BY date
      ''';
      
      final result = await db.rawQuery(query, [fromDateStr, toDateStr]);
      debugPrint('Raw daily data: ${result.length} records found');
      
      // Group transactions by date first
      final Map<String, Map<String, dynamic>> dailyData = {};
      
      // Process all transactions first
      for (var item in result) {
        final date = item['date'] as String;
        final operationType = item['operation_type'] as String;
        final currencyCode = item['currency_code'] as String;
        final amount = _safeDouble(item['total_amount']);
        final quantity = _safeDouble(item['total_quantity']);
        
        // Initialize daily data entry
        if (!dailyData.containsKey(date)) {
          dailyData[date] = {
            'day': date,
            'purchases': 0.0,
            'sales': 0.0,
            'profit': 0.0,
            'deposits': 0.0,
            'currencies': <String, Map<String, dynamic>>{},
          };
        }
        
        // Initialize currency entry for this day
        if (!(dailyData[date]!['currencies'] as Map).containsKey(currencyCode)) {
          (dailyData[date]!['currencies'] as Map)[currencyCode] = {
            'purchase_amount': 0.0,
            'purchase_quantity': 0.0,
            'sale_amount': 0.0,
            'sale_quantity': 0.0,
          };
        }
        
        // Add transaction data
        final currencyData = (dailyData[date]!['currencies'] as Map)[currencyCode] as Map<String, dynamic>;
        
        if (operationType == 'Purchase') {
          dailyData[date]!['purchases'] = (dailyData[date]!['purchases'] as double) + amount;
          currencyData['purchase_amount'] = (currencyData['purchase_amount'] as double) + amount;
          currencyData['purchase_quantity'] = (currencyData['purchase_quantity'] as double) + quantity;
        } else if (operationType == 'Sale') {
          dailyData[date]!['sales'] = (dailyData[date]!['sales'] as double) + amount;
          currencyData['sale_amount'] = (currencyData['sale_amount'] as double) + amount;
          currencyData['sale_quantity'] = (currencyData['sale_quantity'] as double) + quantity;
        } else if (operationType == 'Deposit') {
          dailyData[date]!['deposits'] = (dailyData[date]!['deposits'] as double) + amount;
        }
      }
      
      // Now calculate profit based on selling cost only for sold currencies
      for (var date in dailyData.keys) {
        final dayData = dailyData[date]!;
        double dailyProfit = 0.0;
        
        debugPrint('Calculating profit for date: $date');
        
        // For each currency, calculate profit on the sold amount
        for (var currencyCode in (dayData['currencies'] as Map).keys) {
          final currencyData = (dayData['currencies'] as Map)[currencyCode] as Map<String, dynamic>;
          final saleAmount = currencyData['sale_amount'] as double;
          final saleQuantity = currencyData['sale_quantity'] as double;
          
          debugPrint('  Currency: $currencyCode, Sale Amount: $saleAmount, Sale Quantity: $saleQuantity');
          
          if (saleQuantity > 0) {
            // Get average purchase rate from the database for this currency up to this date
            final avgRateQuery = '''
              SELECT
                CASE 
                  WHEN SUM(quantity) > 0 THEN SUM(total) / SUM(quantity)
                  ELSE 0 
                END as avg_rate
              FROM $tableHistory
              WHERE operation_type = 'Purchase'
              AND currency_code = ?
              AND created_at <= ?
            ''';
            
            final avgRateResult = await db.rawQuery(
              avgRateQuery, 
              [currencyCode, '$date 23:59:59.999Z']
            );
            
            final avgPurchaseRate = _safeDouble(avgRateResult.first['avg_rate']);
            
            // Calculate cost of sold currency
            final costOfSold = saleQuantity * avgPurchaseRate;
            
            // Calculate profit for this currency on this day
            final currencyProfit = saleAmount - costOfSold;
            
            debugPrint('    Avg Purchase Rate: $avgPurchaseRate, Cost of Sold: $costOfSold, Profit: $currencyProfit');
            
            // Add to daily profit
            dailyProfit += currencyProfit;
          }
        }
        
        // Update daily profit
        dayData['profit'] = dailyProfit;
        debugPrint('  Total daily profit for $date: $dailyProfit');
        
        // Extra validation to ensure profit field is properly set
        if (!dayData.containsKey('profit') || dayData['profit'] == null) {
          debugPrint('  WARNING: Profit field was null or missing, setting to 0.0');
          dayData['profit'] = 0.0;
        }
      }
      
      // Convert to list and sort by date
      final formattedResult = dailyData.values.toList();
      formattedResult.sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));
      
      if (formattedResult.isNotEmpty) {
        debugPrint('First day data: ${formattedResult.first}');
      }
      
      return formattedResult;
    } catch (e) {
      debugPrint('Error in getDailyData: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMostProfitableCurrencies({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 5,
  }) async {
    try {
      final db = await database;
      
      final fromDateStr = startDate.toIso8601String();
      final toDateStr = endDate.toIso8601String();
      
      // SQLite doesn't support FULL OUTER JOIN, so we need to do this differently
      final buysQuery = '''
        SELECT 
          currency_code,
          SUM(quantity) as total_quantity,
          SUM(total) as total_spent,
          CASE 
            WHEN SUM(quantity) > 0 THEN SUM(total) / SUM(quantity)
            ELSE 0 
          END as avg_rate
        FROM $tableHistory
        WHERE operation_type = 'Purchase'
        AND created_at BETWEEN ? AND ?
        GROUP BY currency_code
      ''';
      
      final sellsQuery = '''
        SELECT 
          currency_code,
          SUM(quantity) as total_quantity,
          SUM(total) as total_earned,
          CASE 
            WHEN SUM(quantity) > 0 THEN SUM(total) / SUM(quantity)
            ELSE 0 
          END as avg_rate
        FROM $tableHistory
        WHERE operation_type = 'Sale'
        AND created_at BETWEEN ? AND ?
        GROUP BY currency_code
      ''';
      
      final buysResult = await db.rawQuery(buysQuery, [fromDateStr, toDateStr]);
      final sellsResult = await db.rawQuery(sellsQuery, [fromDateStr, toDateStr]);
      
      // Get all currency codes from both results
      final Set<String> allCurrencyCodes = {};
      for (var item in buysResult) {
        allCurrencyCodes.add(item['currency_code'] as String);
      }
      for (var item in sellsResult) {
        allCurrencyCodes.add(item['currency_code'] as String);
      }
      
      // Combine the results
      final List<Map<String, dynamic>> profitData = [];
      
      for (var code in allCurrencyCodes) {
        final buyData = buysResult.firstWhere(
          (item) => item['currency_code'] == code,
          orElse: () => {
            'total_quantity': 0,
            'total_spent': 0,
            'avg_rate': 0,
          },
        );
        
        final sellData = sellsResult.firstWhere(
          (item) => item['currency_code'] == code,
          orElse: () => {
            'total_quantity': 0,
            'total_earned': 0,
            'avg_rate': 0,
          },
        );
        
        final totalQuantitySold = _safeDouble(sellData['total_quantity']);
        final avgPurchaseRate = _safeDouble(buyData['avg_rate']);
        final totalEarned = _safeDouble(sellData['total_earned']);
        
        // Calculate profit only on the amount that was sold
        final costOfSoldCurrency = totalQuantitySold * avgPurchaseRate;
        final profit = totalEarned - costOfSoldCurrency;
        
        // Only add a profit record if there were actual sales
        // or if the currency has been both bought and sold
        final shouldAdd = totalQuantitySold > 0 || (_safeDouble(buyData['total_quantity']) > 0 && _safeDouble(sellData['total_quantity']) > 0);
        
        if (shouldAdd) {
          profitData.add({
            'currency_code': code,
            'amount': profit,
            'avg_purchase_rate': avgPurchaseRate,
            'avg_sale_rate': _safeDouble(sellData['avg_rate']),
            'total_purchased': _safeDouble(buyData['total_quantity']),
            'total_sold': totalQuantitySold,
            'cost_of_sold': costOfSoldCurrency, // Add this for debugging or future use
          });
        }
      }
      
      // Sort by profit and limit
      profitData.sort((a, b) => 
        (_safeDouble(b['amount']) - _safeDouble(a['amount'])).toInt()
      );
      
      if (profitData.length > limit) {
        return profitData.sublist(0, limit);
      }
      
      return profitData;
    } catch (e) {
      debugPrint('Error in getMostProfitableCurrencies: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDailyDataByCurrency({
    required DateTime startDate,
    required DateTime endDate,
    required String currencyCode,
  }) async {
    try {
      final db = await database;
      
      final fromDateStr = startDate.toIso8601String();
      final toDateStr = endDate.toIso8601String();
      
      debugPrint('Fetching daily data for currency $currencyCode from $fromDateStr to $toDateStr');
      
      final query = '''
        SELECT 
          substr(created_at, 1, 10) as date,
          operation_type,
          SUM(total) as total_amount,
          SUM(quantity) as total_quantity,
          COUNT(*) as transaction_count
        FROM $tableHistory
        WHERE created_at BETWEEN ? AND ?
        AND currency_code = ?
        GROUP BY substr(created_at, 1, 10), operation_type
        ORDER BY date
      ''';
      
      final result = await db.rawQuery(
        query, 
        [fromDateStr, toDateStr, currencyCode]
      );
      
      debugPrint('Raw daily data: ${result.length} records found for $currencyCode');
      if (result.isNotEmpty) {
        debugPrint('Sample raw data: ${result.first}');
      }
      
      // Group transactions by date
      final Map<String, Map<String, dynamic>> dailyData = {};
      
      // Process all transactions
      for (var item in result) {
        final date = item['date'] as String;
        final operationType = item['operation_type'] as String;
        final amount = _safeDouble(item['total_amount']);
        final quantity = _safeDouble(item['total_quantity']);
        
        debugPrint('Processing $date - $operationType: Amount=$amount, Quantity=$quantity');
        
        // Initialize daily data entry
        if (!dailyData.containsKey(date)) {
          dailyData[date] = {
            'day': date,
            'purchases': 0.0,
            'purchase_quantity': 0.0,
            'sales': 0.0,
            'sale_quantity': 0.0,
            'profit': 0.0,
            'deposits': 0.0,
          };
        }
        
        // Add transaction data
        if (operationType == 'Purchase') {
          dailyData[date]!['purchases'] = (dailyData[date]!['purchases'] as double) + amount;
          dailyData[date]!['purchase_quantity'] = (dailyData[date]!['purchase_quantity'] as double) + quantity;
        } else if (operationType == 'Sale') {
          dailyData[date]!['sales'] = (dailyData[date]!['sales'] as double) + amount;
          dailyData[date]!['sale_quantity'] = (dailyData[date]!['sale_quantity'] as double) + quantity;
        } else if (operationType == 'Deposit') {
          dailyData[date]!['deposits'] = (dailyData[date]!['deposits'] as double) + amount;
        }
      }
      
      // Calculate profit for each day based on sold quantity
      for (var date in dailyData.keys) {
        final dayData = dailyData[date]!;
        final saleAmount = dayData['sales'] as double;
        final saleQuantity = dayData['sale_quantity'] as double;
        
        debugPrint('Calculating profit for $date - Sale Amount: $saleAmount, Sale Quantity: $saleQuantity');
        
        if (saleQuantity > 0) {
          // Get average purchase rate from the database for this currency up to this date
          final avgRateQuery = '''
            SELECT
              CASE 
                WHEN SUM(quantity) > 0 THEN SUM(total) / SUM(quantity)
                ELSE 0 
              END as avg_rate
            FROM $tableHistory
            WHERE operation_type = 'Purchase'
            AND currency_code = ?
            AND created_at <= ?
          ''';
          
          final avgRateResult = await db.rawQuery(
            avgRateQuery, 
            [currencyCode, '$date 23:59:59.999Z']
          );
          
          final avgPurchaseRate = _safeDouble(avgRateResult.first['avg_rate']);
          
          // Calculate cost of sold currency
          final costOfSold = saleQuantity * avgPurchaseRate;
          
          // Calculate profit for this currency on this day (sale amount minus cost of sold)
          final profit = saleAmount - costOfSold;
          dayData['profit'] = profit;
          
          debugPrint('  Avg Purchase Rate: $avgPurchaseRate, Cost of Sold: $costOfSold, Profit: $profit');
        } else {
          // If nothing was sold, profit is 0 (not negative)
          dayData['profit'] = 0.0;
          debugPrint('  No sales, profit is 0');
        }
        
        // Extra validation to ensure profit field is properly set
        if (!dayData.containsKey('profit') || dayData['profit'] == null) {
          debugPrint('  WARNING: Profit field was null or missing, setting to 0.0');
          dayData['profit'] = 0.0;
        }
      }
      
      // Convert to list and sort by date
      final formattedResult = dailyData.values.toList();
      formattedResult.sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));
      
      if (formattedResult.isNotEmpty) {
        debugPrint('First day formatted data: ${formattedResult.first}');
      }
      
      return formattedResult;
    } catch (e) {
      debugPrint('Error in getDailyDataByCurrency: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getBatchAnalyticsData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Get all the required data
      final pieChartData = await getEnhancedPieChartData(
        startDate: startDate,
        endDate: endDate,
      );
      
      final profitData = await getMostProfitableCurrencies(
        startDate: startDate,
        endDate: endDate,
      );
      
      final barChartData = await getDailyData(
        startDate: startDate,
        endDate: endDate,
      );
      
      return {
        'pieChartData': pieChartData,
        'profitData': profitData,
        'barChartData': barChartData,
      };
    } catch (e) {
      debugPrint('Error in getBatchAnalyticsData: $e');
      return {
        'pieChartData': {'purchases': [], 'sales': []},
        'profitData': [],
        'barChartData': [],
      };
    }
  }

  // =====================
  // USER OPERATIONS
  // =====================

  /// Get user by username and password (for login)
  Future<UserModel?> getUserByCredentials(
    String username,
    String password,
  ) async {
    try {
      final db = await database;
      
      final result = await db.query(
        tableUsers,
        where: 'username = ? AND password = ?',
        whereArgs: [username, password],
      );
      
      if (result.isNotEmpty) {
        return UserModel.fromMap(result.first);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error in getUserByCredentials: $e');
      rethrow;
    }
  }

  /// Get all users
  Future<List<UserModel>> getAllUsers() async {
    try {
      final db = await database;
      
      final result = await db.query(tableUsers);
      
      return result.map((item) => UserModel.fromMap(item)).toList();
    } catch (e) {
      debugPrint('Error in getAllUsers: $e');
      return [];
    }
  }

  /// Create new user
  Future<int> createUser(UserModel user) async {
    try {
      final db = await database;
      
      return await db.insert(tableUsers, user.toMap());
    } catch (e) {
      debugPrint('Error in createUser: $e');
      rethrow;
    }
  }

  /// Update user
  Future<int> updateUser(UserModel user) async {
    try {
      final db = await database;
      
      return await db.update(
        tableUsers,
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (e) {
      debugPrint('Error in updateUser: $e');
      return 0; // Return 0 to indicate failure
    }
  }

  /// Delete user
  Future<int> deleteUser(int id) async {
    try {
      final db = await database;
      
      return await db.delete(
        tableUsers,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error in deleteUser: $e');
      return 0; // Return 0 to indicate failure
    }
  }

  /// Check if a username already exists
  Future<bool> usernameExists(String username) async {
    try {
      final db = await database;
      
      final result = await db.query(
        tableUsers,
        where: 'username = ?',
        whereArgs: [username],
      );
      
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error in usernameExists: $e');
      return false;
    }
  }

  // Add a method to initialize default currencies if needed
  Future<void> initializeDefaultCurrenciesIfNeeded() async {
    try {
      final db = await database;
      
      // Check if currencies other than SOM exist
      final result = await db.query(
        tableCurrencies,
        where: 'code != ?',
        whereArgs: ['SOM'],
      );
      
      if (result.isEmpty) {
        // Add default currencies
        final defaultCurrencies = [
          {
            'code': 'USD',
            'quantity': 0.0,
            'updated_at': DateTime.now().toIso8601String(),
            'default_buy_rate': 89.0,
            'default_sell_rate': 90.0,
          },
          {
            'code': 'EUR',
            'quantity': 0.0,
            'updated_at': DateTime.now().toIso8601String(),
            'default_buy_rate': 97.0,
            'default_sell_rate': 98.0,
          },
          {
            'code': 'RUB',
            'quantity': 0.0,
            'updated_at': DateTime.now().toIso8601String(),
            'default_buy_rate': 0.9,
            'default_sell_rate': 1.0,
          },
        ];
        
        for (var currency in defaultCurrencies) {
          await db.insert(tableCurrencies, currency);
        }
      }
    } catch (e) {
      debugPrint('Error in initializeDefaultCurrenciesIfNeeded: $e');
    }
  }
  
  // Method to backup the database
  Future<String> backupDatabase() async {
    try {
      // Close the database to ensure all changes are written
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Get the database file path
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDirectory.path, 'currency_changer.db');
      
      // Create a backup file path with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupDir = join(documentsDirectory.path, 'backups');
      
      // Create backups directory if it doesn't exist
      final backupDirectory = Directory(backupDir);
      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }
      
      final backupPath = join(backupDir, 'currency_changer_$timestamp.db');
      
      // Copy the database file to the backup location
      final dbFile = File(dbPath);
      await dbFile.copy(backupPath);
      
      // Reopen the database
      _database = await _initDatabase();
      
      return backupPath;
    } catch (e) {
      debugPrint('Error in backupDatabase: $e');
      return '';
    }
  }
  
  // Method to restore the database from backup
  Future<bool> restoreDatabase(String backupPath) async {
    try {
      // Close the database to ensure all changes are written
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Get the database file path
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDirectory.path, 'currency_changer.db');
      
      // Copy the backup file to the database location
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.copy(dbPath);
        
        // Reopen the database
        _database = await _initDatabase();
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error in restoreDatabase: $e');
      return false;
    }
  }

  // Check if database is accessible
  Future<bool> checkDatabaseAccess() async {
    // For local SQLite, we just check if the database exists
    return await _databaseExists();
  }

  // Initialize database if needed
  Future<bool> initializeDatabaseIfNeeded() async {
    try {
      final db = await database;
      return true;
    } catch (e) {
      debugPrint('Error initializing database: $e');
      return false;
    }
  }
}

// Extension methods for model copying
extension CurrencyModelCopy on CurrencyModel {
  CurrencyModel copyWith({
    int? id,
    String? code,
    double? quantity,
    DateTime? updatedAt,
    double? defaultBuyRate,
    double? defaultSellRate,
  }) {
    return CurrencyModel(
      id: id ?? this.id,
      code: code ?? this.code,
      quantity: quantity ?? this.quantity,
      updatedAt: updatedAt ?? this.updatedAt,
      defaultBuyRate: defaultBuyRate ?? this.defaultBuyRate,
      defaultSellRate: defaultSellRate ?? this.defaultSellRate,
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
