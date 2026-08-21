import 'package:flutter/material.dart';
import '../core/database_helper.dart';

class PurchaseCartItem {
  final String itemName;
  final double quantity;
  final double rate;
  final double amount;

  PurchaseCartItem({required this.itemName, required this.quantity, required this.rate})
      : amount = quantity * rate;
}

class PurchaseProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;

  // Separate carts so switching tabs doesn't wipe your data
  List<PurchaseCartItem> trackedCart = [];
  List<PurchaseCartItem> generalCart = [];
  
  DateTime selectedDate = DateTime.now();

  // Add Item to respective cart
  void addItem({required bool isTracked, required String name, required double qty, required double rate}) {
    if (name.isEmpty || qty <= 0 || rate < 0) return;
    final item = PurchaseCartItem(itemName: name, quantity: qty, rate: rate);
    
    if (isTracked) {
      trackedCart.add(item);
    } else {
      generalCart.add(item);
    }
    notifyListeners();
  }

  // Remove Item
  void removeItem({required bool isTracked, required int index}) {
    if (isTracked) {
      trackedCart.removeAt(index);
    } else {
      generalCart.removeAt(index);
    }
    notifyListeners();
  }

  void updateDate(DateTime newDate) {
    selectedDate = newDate;
    notifyListeners();
  }

  // The unified save method handling both desktop logic flows
  Future<bool> savePurchase(bool isTracked) async {
    final cart = isTracked ? trackedCart : generalCart;
    if (cart.isEmpty) return false;

    final db = await dbHelper.database;
    double total = cart.fold(0, (sum, item) => sum + item.amount);
    String category = isTracked ? "Tracked" : "General";

    try {
      await db.transaction((txn) async {
        // 1. Log the Purchase Receipt
        int pId = await txn.insert('purchases', {
          'date_time': selectedDate.toIso8601String(),
          'total_amount': total,
          'track_item': isTracked ? 1 : 0,
          'category': category,
          'is_deleted': 0
        });

        // 2. Loop through items
        for (var item in cart) {
          await txn.insert('purchase_items', {
            'purchase_id': pId,
            'item_name': item.itemName,
            'quantity': item.quantity,
            'rate': item.rate,
            'amount': item.amount,
            'category': category,
            'track_item': isTracked ? 1 : 0,
            'is_deleted': 0
          });

          // 3. Update Inventory ONLY if it is a Tracked Purchase
          if (isTracked) {
            final invCheck = await txn.query('inventory', where: 'item_name = ?', whereArgs: [item.itemName]);
            
            if (invCheck.isNotEmpty) {
              // Add to existing stock, update cost price to latest rate, and un-delete if hidden
              await txn.rawUpdate(
                'UPDATE inventory SET quantity = quantity + ?, cost_price = ?, is_deleted = 0 WHERE item_name = ?',
                [item.quantity, item.rate, item.itemName]
              );
            } else {
              // Create brand new inventory entry
              await txn.insert('inventory', {
                'item_name': item.itemName,
                'quantity': item.quantity,
                'cost_price': item.rate,
                'mrp': 0.0, // MRP can be set later in inventory
                'is_deleted': 0
              });
            }
          }
        }
      });

      // Clear the cart on success
      if (isTracked) {
        trackedCart.clear();
      } else {
        generalCart.clear();
      }
      selectedDate = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error saving purchase: $e");
      return false;
    }
  }
}