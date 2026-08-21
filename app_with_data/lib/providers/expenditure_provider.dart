import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database_helper.dart';

class ExpenditureItem {
  final int id;
  final DateTime date;
  final String description;
  final double amount;

  ExpenditureItem({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
  });
}

class ExpenditureProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;
  
  List<ExpenditureItem> expenses = [];
  DateTime filterDate = DateTime.now();
  bool isLoading = false;

  double get totalExpense => expenses.fold(0, (sum, item) => sum + item.amount);

  void updateFilterDate(DateTime date) {
    filterDate = date;
    loadExpenditures();
  }

  // Load expenses based on the selected filter date
  Future<void> loadExpenditures() async {
    isLoading = true;
    notifyListeners();

    final db = await dbHelper.database;
    String datePrefix = DateFormat('yyyy-MM-dd').format(filterDate);

    final List<Map<String, dynamic>> maps = await db.query(
      'expenditures',
      where: 'date_time LIKE ? AND is_deleted = 0',
      whereArgs: ['$datePrefix%'],
      orderBy: 'id DESC'
    );

    expenses = maps.map((map) => ExpenditureItem(
      id: map['id'] as int,
      date: DateTime.parse(map['date_time'].toString()),
      description: map['description'].toString(),
      amount: (map['amount'] as num).toDouble(),
    )).toList();

    isLoading = false;
    notifyListeners();
  }

  // Save or Update an Expense
  Future<bool> saveExpense({int? id, required DateTime date, required String description, required double amount}) async {
    if (description.isEmpty || amount <= 0) return false;
    
    final db = await dbHelper.database;
    String formattedDate = date.toIso8601String();

    try {
      if (id != null) {
        // Update
        await db.update('expenditures', 
          {'date_time': formattedDate, 'description': description, 'amount': amount},
          where: 'id = ?', whereArgs: [id]
        );
      } else {
        // Insert
        await db.insert('expenditures', {
          'date_time': formattedDate,
          'description': description,
          'amount': amount,
          'is_deleted': 0
        });
      }
      
      await loadExpenditures();
      return true;
    } catch (e) {
      debugPrint("Error saving expenditure: $e");
      return false;
    }
  }

  // Soft Delete
  Future<bool> deleteExpense(int id) async {
    final db = await dbHelper.database;
    try {
      await db.update('expenditures', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
      await loadExpenditures();
      return true;
    } catch (e) {
      return false;
    }
  }
}