import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database_helper.dart';

class PortfolioProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;

  double totalSales = 0.0;
  double totalPurchases = 0.0;
  double totalExpenses = 0.0;
  double netProfit = 0.0;
  bool isLoading = false;

  Future<void> calculatePortfolio(DateTime start, DateTime end) async {
    isLoading = true;
    notifyListeners();

    final db = await dbHelper.database;
    // Format to YYYY-MM-DD for SQLite date functions
    String startStr = DateFormat('yyyy-MM-dd').format(start);
    String endStr = DateFormat('yyyy-MM-dd').format(end);

    // 1. Sales - Matches your 'Paid & Not Deleted' desktop logic
    final sRes = await db.rawQuery(
      "SELECT SUM(net_total) as total FROM sales WHERE paid_status = 1 AND (is_deleted = 0 OR is_deleted IS NULL) AND date(date_time) BETWEEN ? AND ?",
      [startStr, endStr]
    );
    totalSales = (sRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2. Purchases
    final pRes = await db.rawQuery(
      "SELECT SUM(total_amount) as total FROM purchases WHERE (is_deleted = 0 OR is_deleted IS NULL) AND date(date_time) BETWEEN ? AND ?",
      [startStr, endStr]
    );
    totalPurchases = (pRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 3. Expenditures
    final eRes = await db.rawQuery(
      "SELECT SUM(amount) as total FROM expenditures WHERE (is_deleted = 0 OR is_deleted IS NULL) AND date(date_time) BETWEEN ? AND ?",
      [startStr, endStr]
    );
    totalExpenses = (eRes.first['total'] as num?)?.toDouble() ?? 0.0;

    netProfit = totalSales - totalPurchases - totalExpenses;
    
    isLoading = false;
    notifyListeners();
  }
}