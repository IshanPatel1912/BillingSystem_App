import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "billing_data.db";
  static const _databaseVersion = 1;

  // Singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    // 1. Sales Table
    await db.execute('''
      CREATE TABLE sales (
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
      CREATE TABLE sale_items (
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
      CREATE TABLE inventory (
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
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        mobile TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 5. Customer Cars Table
    await db.execute('''
      CREATE TABLE customer_cars (
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
      CREATE TABLE purchases (
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
      CREATE TABLE purchase_items (
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
      CREATE TABLE expenditures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_time TEXT,
        description TEXT,
        amount REAL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 9. Service Reminders Table
    await db.execute('''
      CREATE TABLE service_reminders (
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
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password_hash TEXT,
        role TEXT DEFAULT 'admin',
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE business_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT DEFAULT 'Your Business Name',
        address TEXT DEFAULT '123 Business Street, City',
        phone TEXT DEFAULT '+1234567890',
        owner_name TEXT DEFAULT 'Owner Name',
        logo_path TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // Insert default admin user (Password: admin123 hashed via SHA256 for mobile simplicity)
    await db.execute('''
      INSERT INTO users (username, password_hash) 
      VALUES ('admin', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9')
    ''');
    
    await db.execute('''
      INSERT INTO business_details (name) VALUES ('My Android Garage')
    ''');
  }
}