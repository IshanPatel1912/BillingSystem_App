import 'package:flutter/material.dart';
import '../core/database_helper.dart';

class CustomerData {
  final int id;
  final String name;
  final String mobile;
  final List<Map<String, dynamic>> cars;

  CustomerData({required this.id, required this.name, required this.mobile, required this.cars});
}

class CustomerProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;
  
  List<CustomerData> customers = [];
  bool isLoading = false;

  Future<void> loadCustomers([String searchQuery = '']) async {
    isLoading = true;
    notifyListeners();

    final db = await dbHelper.database;
    
    String query = 'SELECT id, name, mobile FROM customers WHERE is_deleted = 0';
    final List<Map<String, dynamic>> custMaps = await db.rawQuery(query);
    List<CustomerData> loadedCustomers = [];

    for (var c in custMaps) {
      int custId = c['id'] as int;
      
      final List<Map<String, dynamic>> carMaps = await db.query(
        'customer_cars',
        where: 'customer_id = ? AND is_deleted = 0',
        whereArgs: [custId]
      );

      bool matchesSearch = false;
      if (searchQuery.isEmpty) {
        matchesSearch = true;
      } else {
        String s = searchQuery.toLowerCase();
        if (c['name'].toString().toLowerCase().contains(s) || 
            c['mobile'].toString().toLowerCase().contains(s)) {
          matchesSearch = true;
        } else {
          for (var car in carMaps) {
            if (car['car_model'].toString().toLowerCase().contains(s) || 
                car['car_number'].toString().toLowerCase().contains(s)) {
              matchesSearch = true;
              break;
            }
          }
        }
      }

      if (matchesSearch) {
        loadedCustomers.add(CustomerData(
          id: custId,
          name: c['name'].toString(),
          mobile: c['mobile'].toString(),
          cars: carMaps,
        ));
      }
    }

    customers = loadedCustomers;
    isLoading = false;
    notifyListeners();
  }

  // UPDATED: Now accepts a full list of cars and syncs them perfectly!
  Future<bool> saveCustomer({int? id, required String name, required String mobile, required List<Map<String, String>> cars}) async {
    if (name.isEmpty) return false;
    
    final db = await dbHelper.database;

    try {
      await db.transaction((txn) async {
        int customerId;
        
        if (id != null) {
          // 1. Update Existing Customer Profile
          await txn.update('customers', {'name': name, 'mobile': mobile}, where: 'id = ?', whereArgs: [id]);
          customerId = id;
          
          // 2. Soft-delete all cars temporarily (we will restore the ones kept in the UI list)
          await txn.update('customer_cars', {'is_deleted': 1}, where: 'customer_id = ?', whereArgs: [customerId]);
        } else {
          // 1. Insert New Customer
          customerId = await txn.insert('customers', {'name': name, 'mobile': mobile, 'is_deleted': 0});
        }

        // 3. Insert or Restore Cars
        for (var car in cars) {
          String model = car['car_model'].toString().trim();
          String number = car['car_number'].toString().trim();
          
          if (number.isEmpty) continue; // Skip empty rows

          // Check if this specific car already exists in history for this customer
          final existingCar = await txn.query('customer_cars', 
            where: 'customer_id = ? AND car_number = ?', 
            whereArgs: [customerId, number]
          );

          if (existingCar.isNotEmpty) {
            // Restore and update model name
            await txn.update('customer_cars', 
              {'car_model': model, 'is_deleted': 0}, 
              where: 'id = ?', 
              whereArgs: [existingCar.first['id']]
            );
          } else {
            // Insert brand new car
            await txn.insert('customer_cars', {
              'customer_id': customerId,
              'car_model': model,
              'car_number': number,
              'is_deleted': 0
            });
          }
        }
      });

      await loadCustomers();
      return true;
    } catch (e) {
      debugPrint("Error saving customer: $e");
      return false;
    }
  }

  Future<void> deleteCustomer(int id) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.update('customers', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
      await txn.update('customer_cars', {'is_deleted': 1}, where: 'customer_id = ?', whereArgs: [id]);
    });
    await loadCustomers();
  }
}