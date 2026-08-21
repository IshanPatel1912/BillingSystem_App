import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database_helper.dart';

class BillSummary {
  final String billId;
  final DateTime date;
  final String customerName;
  final String carNumber;
  final double netTotal;
  final bool isPaid;
  final bool isDeleted;

  BillSummary({
    required this.billId, required this.date, required this.customerName,
    required this.carNumber, required this.netTotal, required this.isPaid, required this.isDeleted
  });
}

class FindBillProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;
  
  List<BillSummary> bills = [];
  bool isLoading = false;

  // Filters
  String searchTerm = '';
  String searchCategory = 'Bill ID'; // Bill ID, Customer Name, Car Number, Mobile Number
  String statusFilter = 'All'; // All, Paid, Unpaid
  DateTime? dateFilter;
  bool showRecycleBin = false;

  void updateFilters({String? term, String? category, String? status, DateTime? date, bool? recycle}) {
    if (term != null) searchTerm = term;
    if (category != null) searchCategory = category;
    if (status != null) statusFilter = status;
    if (date != null) dateFilter = date;
    if (recycle != null) showRecycleBin = recycle;
    searchBills();
  }

  void clearDateFilter() {
    dateFilter = null;
    searchBills();
  }

  Future<void> searchBills() async {
    isLoading = true;
    notifyListeners();

    final db = await dbHelper.database;
    
    String query = 'SELECT * FROM sales WHERE is_deleted = ?';
    List<dynamic> args = [showRecycleBin ? 1 : 0];

    // 1. Text Search
    if (searchTerm.isNotEmpty) {
      String col = 'bill_id';
      if (searchCategory == 'Customer Name') col = 'customer_name';
      if (searchCategory == 'Car Number') col = 'car_number';
      if (searchCategory == 'Mobile Number') col = 'mobile_number';
      
      query += ' AND $col LIKE ?';
      args.add('%$searchTerm%');
    }

    // 2. Status Filter
    if (statusFilter == 'Paid') {
      query += ' AND paid_status = 1';
    } else if (statusFilter == 'Unpaid') {
      query += ' AND paid_status = 0';
    }

    // 3. Date Filter
    if (dateFilter != null) {
      String datePrefix = DateFormat('yyyy-MM-dd').format(dateFilter!);
      query += ' AND date_time LIKE ?';
      args.add('$datePrefix%');
    }

    query += ' ORDER BY date_time DESC LIMIT 100';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

    bills = maps.map((map) => BillSummary(
      billId: map['bill_id'].toString(),
      date: DateTime.parse(map['date_time'].toString()),
      customerName: map['customer_name'].toString(),
      carNumber: map['car_number'].toString(),
      netTotal: (map['net_total'] as num).toDouble(),
      isPaid: (map['paid_status'] as int) == 1,
      isDeleted: (map['is_deleted'] as int) == 1,
    )).toList();

    isLoading = false;
    notifyListeners();
  }

  // Soft Delete (Moves to Recycle Bin & RESTORES Inventory)
  // Soft Delete (Moves to Recycle Bin & RESTORES Inventory)
  Future<bool> deleteBill(String billId, bool permanent) async {
    final db = await dbHelper.database;
    try {
      await db.transaction((txn) async {
        if (permanent) {
          await txn.delete('sale_items', where: 'sale_bill_id = ?', whereArgs: [billId]);
          await txn.delete('sales', where: 'bill_id = ?', whereArgs: [billId]);
        } else {
          // 1. Mark the sale as deleted
          await txn.update('sales', {'is_deleted': 1}, where: 'bill_id = ?', whereArgs: [billId]);
          
          // 2. Fetch ALL items (Removed the strict 'is_tracked = 1' check to be safe)
          final items = await txn.query('sale_items', where: 'sale_bill_id = ?', whereArgs: [billId]);
          
          for (var item in items) {
            String name = item['item_name'].toString();
            double qty = (item['quantity'] as num).toDouble();
            
            // 3. Update the inventory
            final invCheck = await txn.query('inventory', where: 'item_name = ?', whereArgs: [name]);
            if (invCheck.isNotEmpty) {
              // Increase stock because the sale was cancelled
              await txn.rawUpdate('UPDATE inventory SET quantity = quantity + ? WHERE item_name = ?', [qty, name]);
            } else {
              // If the item was somehow deleted from inventory, recreate it
              await txn.insert('inventory', {'item_name': name, 'quantity': qty, 'cost_price': 0, 'mrp': item['rate'] ?? 0, 'is_deleted': 0});
            }
          }
        }
      });
      await searchBills(); // Refresh the list
      return true;
    } catch (e) {
      return false;
    }
  }

  // Restore from Recycle Bin (DEDUCTS Inventory again)
  Future<bool> restoreBill(String billId) async {
    final db = await dbHelper.database;
    try {
      await db.transaction((txn) async {
        // 1. Mark as active again
        await txn.update('sales', {'is_deleted': 0}, where: 'bill_id = ?', whereArgs: [billId]);
        
        // 2. Fetch all items
        final items = await txn.query('sale_items', where: 'sale_bill_id = ?', whereArgs: [billId]);
        
        for (var item in items) {
          String name = item['item_name'].toString();
          double qty = (item['quantity'] as num).toDouble();
          
          // 3. Deduct from inventory because the sale is active again
          final invCheck = await txn.query('inventory', where: 'item_name = ?', whereArgs: [name]);
          if (invCheck.isNotEmpty) {
            await txn.rawUpdate('UPDATE inventory SET quantity = quantity - ? WHERE item_name = ?', [qty, name]);
          } else {
            // Recreate with negative stock if missing
            await txn.insert('inventory', {'item_name': name, 'quantity': -qty, 'cost_price': 0, 'mrp': item['rate'] ?? 0, 'is_deleted': 0});
          }
        }
      });
      await searchBills();
      return true;
    } catch (e) {
      return false;
    }
  }
}