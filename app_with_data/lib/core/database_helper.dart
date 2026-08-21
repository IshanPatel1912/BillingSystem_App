import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart'; // <--- NEW: Required to read the asset file
import 'dart:io'; // <--- NEW: Required to write the file to the device

class DatabaseHelper {
  static const _databaseName = "billing_data.db";
  static const _databaseVersion = 1;

  // Singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  
  // 🚦 NEW: The "Traffic Light" to prevent multiple simultaneous copies
  static Future<Database>? _databaseFuture; 

  Future<Database> get database {
    if (_database != null) return Future.value(_database!);
    
    // If the database is already in the process of initializing/copying, 
    // force the other providers to wait for this future to finish!
    _databaseFuture ??= _initDatabase().then((db) {
      _database = db;
      return db;
    });
    
    return _databaseFuture!;
  }

  // --- UPDATED LOGIC: Asset Copying ---
  // --- UPDATED LOGIC: Asset Copying ---
  // --- UPDATED LOGIC: Bulletproof Asset Copying & Migration ---
  Future<Database> _initDatabase() async {
    final dbFolder = await getDatabasesPath();
    final path = join(dbFolder, _databaseName);
    
    // 1. Check if the database already exists
    final exists = await databaseExists(path);

    if (!exists) {
      print("First launch! Copying database from assets...");
      try {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load("assets/$_databaseName");
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        print("Database copied successfully!");
      } catch (e) {
        print("Error copying database: $e");
      }
    } else {
      print("Opening existing database...");
    }

    // 2. Open the database
    Database db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );

    // ==========================================
    // 🚀 BULLETPROOF MIGRATION: RUNS EVERY TIME
    // ==========================================
    // Helper function to safely add a column only if it is missing
    Future<void> addColumn(String table, String col) async {
      try {
        var res = await db.rawQuery("PRAGMA table_info($table)");
        // If the column doesn't exist in the table, add it
        if (!res.any((r) => r['name'] == col)) {
          await db.execute("ALTER TABLE $table ADD COLUMN $col INTEGER DEFAULT 0");
          print("✅ Added $col to $table");
        }
      } catch (e) {
        print("⚠️ Could not check/add column to $table (Table might not exist yet)");
      }
    }

    // Check EVERY table and add 'is_deleted' if it is missing
    final tablesToUpdate = [
      'users', 'inventory', 'customers', 'customer_cars', 
      'sales', 'sale_items', 'purchases', 'purchase_items', 
      'expenditures', 'service_reminders', 'business_details'
    ];
    
    for (String table in tablesToUpdate) {
      await addColumn(table, 'is_deleted');
    }

    // 🔑 OVERWRITE OLD PYTHON PASSWORD HASH
    try {
      await db.rawUpdate(
        "UPDATE users SET password_hash = ? WHERE username = 'admin'",
        ['240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9'] 
      );
    } catch (e) {
      print("⚠️ Could not update admin password");
    }
    // ==========================================

    return db;
  }

   

  // ... (Leave your _onCreate function exactly as it is below this) ...

  // --- EXISTING LOGIC: Completely untouched ---
  // --- EXISTING LOGIC: Updated with IF NOT EXISTS ---
  Future _onCreate(Database db, int version) async {
    // 1. Sales Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        bill_id TEXT PRIMARY KEY,
        date_time TEXT,
        customer_name TEXT,
        mobile_number TEXT,
        car_number TEXT,
        car_model TEXT,
        car_km TEXT,
        subtotal REAL DEFAULT 0.0,
        discount_percent REAL DEFAULT 0.0,
        net_total REAL DEFAULT 0.0,
        paid_status INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 2. Sale Items Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_bill_id TEXT,
        sr_no INTEGER,
        item_name TEXT,
        quantity REAL,
        rate REAL,
        amount REAL,
        is_tracked INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (sale_bill_id) REFERENCES sales (bill_id)
      )
    ''');

    // 3. Inventory Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name TEXT UNIQUE,
        quantity REAL DEFAULT 0.0,
        cost_price REAL DEFAULT 0.0,
        mrp REAL DEFAULT 0.0,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 4. Customers Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        mobile TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 5. Customer Cars Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_cars (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        car_model TEXT,
        car_number TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // 6. Purchases Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_time TEXT,
        total_amount REAL DEFAULT 0.0,
        track_item INTEGER DEFAULT 0,
        category TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 7. Purchase Items Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER,
        item_name TEXT,
        quantity REAL,
        rate REAL,
        amount REAL,
        category TEXT,
        track_item INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id)
      )
    ''');

    // 8. Expenditures Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenditures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_time TEXT,
        description TEXT,
        amount REAL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 9. Service Reminders Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS service_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id TEXT,
        car_number TEXT,
        customer_name TEXT,
        mobile_number TEXT,
        service_due_date TEXT,
        is_notified INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 10. Users & Business Details
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password_hash TEXT,
        role TEXT DEFAULT 'admin',
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS business_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT DEFAULT 'Your Business Name',
        address TEXT DEFAULT '123 Business Street, City',
        phone TEXT DEFAULT '+1234567890',
        owner_name TEXT DEFAULT 'Owner Name',
        logo_path TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // Use INSERT OR IGNORE so it doesn't crash if admin already exists
    await db.execute('''
      INSERT OR IGNORE INTO users (username, password_hash) 
      VALUES ('admin', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9')
    ''');
    
    // Check if business details exist before inserting a default row
    final bizCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM business_details'));
    if (bizCount == 0) {
      await db.execute('''
        INSERT INTO business_details (name) VALUES ('My Android Garage')
      ''');
    }
  }}