import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import 'package:intl/intl.dart';

class HistoryItem {
  final int id;
  final int purchaseId;
  final String itemName;
  final String category;
  final double quantity;
  final double rate;
  final double amount;
  final bool isTracked;

  HistoryItem({
    required this.id, required this.purchaseId, required this.itemName,
    required this.category, required this.quantity, required this.rate,
    required this.amount, required this.isTracked
  });
}

class PurchaseHistoryProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;
  
  List<HistoryItem> historyItems = [];
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  void updateDate(DateTime date) {
    selectedDate = date;
    loadHistory();
  }

  void clearFilter() {
    selectedDate = DateTime.now();
    loadHistory();
  }

  // Load history based on selected date
  Future<void> loadHistory() async {
    isLoading = true;
    notifyListeners();

    final db = await dbHelper.database;
    String datePrefix = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Join purchase_items with purchases to filter by the purchase date
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT pi.*, p.date_time 
      FROM purchase_items pi
      INNER JOIN purchases p ON pi.purchase_id = p.id
      WHERE p.date_time LIKE ? AND pi.is_deleted = 0
      ORDER BY pi.id DESC
    ''', ['$datePrefix%']);

    historyItems = maps.map((map) => HistoryItem(
      id: map['id'] as int,
      purchaseId: map['purchase_id'] as int,
      itemName: map['item_name'].toString(),
      category: map['category'].toString(),
      quantity: (map['quantity'] as num).toDouble(),
      rate: (map['rate'] as num).toDouble(),
      amount: (map['amount'] as num).toDouble(),
      isTracked: (map['track_item'] as int) == 1,
    )).toList();

    isLoading = false;
    notifyListeners();
  }

  // Edit item and reverse-calculate inventory (Matches Python logic)
  Future<bool> editHistoryItem(HistoryItem oldItem, double newQty, double newRate) async {
    final db = await dbHelper.database;
    double newAmount = newQty * newRate;
    double qtyDiff = newQty - oldItem.quantity;

    try {
      await db.transaction((txn) async {
        // 1. Adjust Inventory if it was a tracked item
        if (oldItem.isTracked) {
          await txn.rawUpdate(
            'UPDATE inventory SET quantity = quantity + ? WHERE item_name = ? AND is_deleted = 0',
            [qtyDiff, oldItem.itemName]
          );
        }

        // 2. Update the purchase item row
        await txn.update('purchase_items', 
          {'quantity': newQty, 'rate': newRate, 'amount': newAmount},
          where: 'id = ?', whereArgs: [oldItem.id]
        );

        // 3. Recalculate total amount for the master purchase record
        final allItems = await txn.query('purchase_items', where: 'purchase_id = ? AND is_deleted = 0', whereArgs: [oldItem.purchaseId]);
        double newTotal = allItems.fold(0.0, (sum, item) => sum + ((item['amount'] as num).toDouble()));
        
        await txn.update('purchases', {'total_amount': newTotal}, where: 'id = ?', whereArgs: [oldItem.purchaseId]);
      });

      await loadHistory();
      return true;
    } catch (e) {
      debugPrint("Edit Error: $e");
      return false;
    }
  }

  // Delete item and reverse-calculate inventory (Matches Python logic)
  Future<bool> deleteHistoryItem(HistoryItem item) async {
    final db = await dbHelper.database;

    try {
      await db.transaction((txn) async {
        // 1. Remove from Inventory if tracked
        if (item.isTracked) {
          await txn.rawUpdate(
            'UPDATE inventory SET quantity = quantity - ? WHERE item_name = ? AND is_deleted = 0',
            [item.quantity, item.itemName]
          );
        }

        // 2. Soft delete the item
        await txn.update('purchase_items', {'is_deleted': 1}, where: 'id = ?', whereArgs: [item.id]);

        // 3. Recalculate master purchase record total
        final allItems = await txn.query('purchase_items', where: 'purchase_id = ? AND is_deleted = 0', whereArgs: [item.purchaseId]);
        double newTotal = allItems.fold(0.0, (sum, i) => sum + ((i['amount'] as num).toDouble()));
        
        await txn.update('purchases', {'total_amount': newTotal}, where: 'id = ?', whereArgs: [item.purchaseId]);
      });

      await loadHistory();
      return true;
    } catch (e) {
      debugPrint("Delete Error: $e");
      return false;
    }
  }
}