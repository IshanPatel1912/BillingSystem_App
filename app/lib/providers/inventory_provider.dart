import 'package:flutter/material.dart';
import '../core/database_helper.dart';

class InventoryItem {
  final String itemName;
  final double quantity;

  InventoryItem({required this.itemName, required this.quantity});
}

class InventoryProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;
  
  List<InventoryItem> items = [];
  bool isLoading = false;

  // Load all items, with optional search filter
  Future<void> loadInventory([String searchQuery = '']) async {
    isLoading = true;
    notifyListeners();

    final db = await dbHelper.database;
    
    String query = 'SELECT item_name, quantity FROM inventory WHERE is_deleted = 0';
    List<dynamic> args = [];

    if (searchQuery.isNotEmpty) {
      query += ' AND item_name LIKE ?';
      args.add('%$searchQuery%');
    }
    
    query += ' ORDER BY item_name ASC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

    items = maps.map((map) => InventoryItem(
      itemName: map['item_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
    )).toList();

    isLoading = false;
    notifyListeners();
  }

  // Soft Delete Item (Protects historical billing data)
  Future<void> deleteItem(String itemName) async {
    final db = await dbHelper.database;
    await db.rawUpdate(
      'UPDATE inventory SET is_deleted = 1 WHERE item_name = ?',
      [itemName]
    );
    await loadInventory(); // Refresh list after deletion
  }

  // Save multiple stock items at once (Smart Add/Update)
  Future<Map<String, int>> saveStock(List<Map<String, dynamic>> stockData) async {
    final db = await dbHelper.database;
    int addedCount = 0;
    int updatedCount = 0;

    await db.transaction((txn) async {
      for (var item in stockData) {
        String name = item['name'].toString().trim();
        double qty = double.tryParse(item['qty'].toString()) ?? 0.0;

        if (name.isEmpty || qty <= 0) continue;

        // Check if item already exists (and is not deleted)
        final existing = await txn.query('inventory', 
          where: 'item_name = ? AND is_deleted = 0', 
          whereArgs: [name]
        );

        if (existing.isNotEmpty) {
          // UPDATE: Add new quantity to existing
          await txn.rawUpdate(
            'UPDATE inventory SET quantity = quantity + ? WHERE item_name = ?',
            [qty, name]
          );
          updatedCount++;
        } else {
          // CREATE: Insert new item
          await txn.insert('inventory', {
            'item_name': name,
            'quantity': qty,
            'cost_price': 0.0,
            'mrp': 0.0,
            'is_deleted': 0
          });
          addedCount++;
        }
      }
    });

    await loadInventory(); // Refresh the UI list
    return {'added': addedCount, 'updated': updatedCount};
  }
}