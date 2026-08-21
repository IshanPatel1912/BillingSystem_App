import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for utf8
import '../core/database_helper.dart';

class UserModel {
  final int id;
  final String username;
  UserModel({required this.id, required this.username});
}

class SettingsProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;

  // Business State
  String bizName = '';
  String bizAddress = '';
  String bizPhone = '';
  String bizOwner = '';
  String logoPath = '';

  // User State
  List<UserModel> users = [];

  // App Settings State
  bool isBiometricEnabled = false;

  SettingsProvider() {
    _loadBiometricPreference();
  }

  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    isBiometricEnabled = prefs.getBool('use_biometrics') ?? false;
    notifyListeners();
  }

  Future<void> toggleBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_biometrics', value);
    isBiometricEnabled = value;
    notifyListeners();
  }

  Future<void> loadSettings() async {
    final db = await dbHelper.database;

    // Load Business Details
    final bizData = await db.query('business_details');
    if (bizData.isNotEmpty) {
      final biz = bizData.first;
      bizName = biz['name']?.toString() ?? '';
      bizAddress = biz['address']?.toString() ?? '';
      bizPhone = biz['phone']?.toString() ?? '';
      bizOwner = biz['owner_name']?.toString() ?? '';
      logoPath = biz['logo_path']?.toString() ?? '';
    }

    // Load Users (excluding deleted)
    final userData = await db.query('users', where: 'is_deleted = 0');
    users = userData.map((u) => UserModel(
      id: u['id'] as int,
      username: u['username'].toString()
    )).toList();

    notifyListeners();
  }

  Future<bool> saveBusinessDetails({
    required String name, required String address, 
    required String phone, required String owner, required String logo
  }) async {
    final db = await dbHelper.database;
    try {
      final bizData = await db.query('business_details');
      if (bizData.isEmpty) {
        await db.insert('business_details', {
          'name': name, 'address': address, 'phone': phone, 
          'owner_name': owner, 'logo_path': logo
        });
      } else {
        await db.update('business_details', {
          'name': name, 'address': address, 'phone': phone, 
          'owner_name': owner, 'logo_path': logo
        }, where: 'id = ?', whereArgs: [bizData.first['id']]);
      }
      
      bizName = name; bizAddress = address; bizPhone = phone;
      bizOwner = owner; logoPath = logo;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Uses SHA256 hashing to replace Python's bcrypt for mobile simplicity
  Future<String> saveUser(String username, String password) async {
    if (username.isEmpty || password.isEmpty) return "Missing fields";
    
    final db = await dbHelper.database;
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    final hashedPassword = digest.toString();

    try {
      final existing = await db.query('users', where: 'username = ?', whereArgs: [username]);
      
      if (existing.isNotEmpty) {
        await db.update('users', 
          {'password_hash': hashedPassword, 'is_deleted': 0}, 
          where: 'id = ?', whereArgs: [existing.first['id']]
        );
        await loadSettings();
        return "Password updated.";
      } else {
        await db.insert('users', {
          'username': username,
          'password_hash': hashedPassword,
          'role': 'admin',
          'is_deleted': 0
        });
        await loadSettings();
        return "New user added.";
      }
    } catch (e) {
      return "Error saving user.";
    }
  }

  Future<String> deleteUser(int id, String username) async {
    if (username.toLowerCase() == 'admin') {
      return "Cannot delete the default admin user.";
    }
    
    final db = await dbHelper.database;
    await db.update('users', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    await loadSettings();
    return "User deleted.";
  }
}