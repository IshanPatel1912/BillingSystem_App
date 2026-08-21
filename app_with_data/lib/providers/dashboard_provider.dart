import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database_helper.dart';

class DashPurchaseItem {
  final String time;
  final String itemName;
  final double amount;
  DashPurchaseItem({required this.time, required this.itemName, required this.amount});
}

class DashExpenseItem {
  final String description;
  final double amount;
  DashExpenseItem({required this.description, required this.amount});
}

class DashboardProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;
  
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  // Stats
  int salesCount = 0;
  double totalRevenue = 0.0;
  
  // Lists
  List<DashPurchaseItem> purchases = [];
  List<DashExpenseItem> expenses = [];

  void updateDate(DateTime date) {
    selectedDate = date;
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    isLoading = true;
    notifyListeners();

    final db = await dbHelper.database;
    String datePrefix = DateFormat('yyyy-MM-dd').format(selectedDate);

    // 1. REVENUE CALCULATION (Matches Python: Paid Only, Not Deleted)
    final salesResult = await db.rawQuery('''
      SELECT COUNT(*) as cnt, SUM(net_total) as total 
      FROM sales 
      WHERE date_time LIKE ? AND paid_status = 1 AND is_deleted = 0
    ''', ['$datePrefix%']);
    
    if (salesResult.isNotEmpty) {
      salesCount = (salesResult.first['cnt'] as num?)?.toInt() ?? 0;
      totalRevenue = (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    } else {
      salesCount = 0;
      totalRevenue = 0.0;
    }

    // 2. ITEMIZED PURCHASES (Joined query matching Python's SQLAlchemy join)
    final pResult = await db.rawQuery('''
      SELECT p.date_time, pi.item_name, pi.amount 
      FROM purchase_items pi
      INNER JOIN purchases p ON pi.purchase_id = p.id
      WHERE p.date_time LIKE ? AND pi.is_deleted = 0
      ORDER BY p.date_time DESC
    ''', ['$datePrefix%']);

    purchases = pResult.map((map) {
      DateTime dt = DateTime.parse(map['date_time'].toString());
      return DashPurchaseItem(
        time: DateFormat('HH:mm').format(dt),
        itemName: map['item_name'].toString(),
        amount: (map['amount'] as num).toDouble(),
      );
    }).toList();

    // 3. TODAY'S EXPENSES
    final eResult = await db.query(
      'expenditures',
      where: 'date_time LIKE ? AND is_deleted = 0',
      whereArgs: ['$datePrefix%'],
      orderBy: 'id DESC'
    );

    expenses = eResult.map((map) => DashExpenseItem(
      description: map['description'].toString(),
      amount: (map['amount'] as num).toDouble(),
    )).toList();

    isLoading = false;
    notifyListeners();
  }
}