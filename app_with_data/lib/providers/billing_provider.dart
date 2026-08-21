import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CartItem {
  final String itemName;
  final double quantity;
  final double rate;
  final double amount;

  CartItem({required this.itemName, required this.quantity, required this.rate}) 
    : amount = quantity * rate;
}

class BillingProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;

  // Form State
  String? currentBillId; // Used if editing an existing bill
  String customerName = '';
  String mobile = '';
  String carModel = '';
  String carNumber = '';
  String carKm = '';
  
  // Checkboxes
  bool isPaid = true;
  bool sendWhatsapp = true;
  bool nextServiceReminder = false;
  
  // Cart State
  List<CartItem> cart = [];
  double discountPercent = 0.0;

  double get subtotal => cart.fold(0, (sum, item) => sum + item.amount);
  double get discountAmount => subtotal * (discountPercent / 100);
  double get netTotal => subtotal - discountAmount;

  Future<String> generateBillId() async {
    final db = await dbHelper.database;
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sales WHERE bill_id LIKE 'INV-$today-%'"
    );
    int count = Sqflite.firstIntValue(result) ?? 0;
    int nextNum = count + 1;
    
    return "INV-$today-${nextNum.toString().padLeft(4, '0')}";
  }

  // UPDATED: Strict Stock Validation like Python
  Future<String?> checkAndAddItem(String name, double qty, double rate) async {
    if (name.isEmpty || qty <= 0 || rate < 0) return "Invalid input.";

    final db = await dbHelper.database;
    final invCheck = await db.query('inventory', 
      where: 'item_name = ? AND is_deleted = 0', whereArgs: [name]);

    if (invCheck.isNotEmpty) {
      double available = (invCheck.first['quantity'] as num).toDouble();
      if (qty > available) {
        return "Insufficient Stock!\n\nItem: $name\nAvailable: $available\nRequested: $qty"; // Matches Python Warning
      }
    }

    cart.add(CartItem(itemName: name, quantity: qty, rate: rate));
    notifyListeners();
    return null; // Null means success
  }

  void removeItem(int index) {
    cart.removeAt(index);
    notifyListeners();
  }

  void updateDiscount(String val) {
    discountPercent = double.tryParse(val) ?? 0.0;
    notifyListeners();
  }

  void togglePaid(bool val) { isPaid = val; notifyListeners(); }
  void toggleWhatsapp(bool val) { sendWhatsapp = val; notifyListeners(); }
  void toggleReminder(bool val) { nextServiceReminder = val; notifyListeners(); }
  // --- ADD THIS FUNCTION FOR THE EDIT FEATURE ---
  Future<void> loadBillForEdit(String billId) async {
    final db = await dbHelper.database;
    
    // Fetch Sale Data
    final saleData = await db.query('sales', where: 'bill_id = ?', whereArgs: [billId]);
    if (saleData.isEmpty) return;
    final sale = saleData.first;

    // Fill the variables
    currentBillId = billId;
    customerName = sale['customer_name'].toString();
    mobile = sale['mobile_number'].toString();
    carModel = sale['car_model'].toString();
    carNumber = sale['car_number'].toString();
    carKm = sale['car_km'].toString();
    isPaid = (sale['paid_status'] as int) == 1;
    discountPercent = (sale['discount_percent'] as num).toDouble();

    // Fetch Items
    final itemsData = await db.query('sale_items', where: 'sale_bill_id = ?', whereArgs: [billId]);
    cart = itemsData.map((item) => CartItem(
      itemName: item['item_name'].toString(),
      quantity: (item['quantity'] as num).toDouble(),
      rate: (item['rate'] as num).toDouble(),
    )).toList();

    notifyListeners();
  }
  Future<void> _syncCustomerAndCar(Transaction txn) async {
    if (customerName.isEmpty || mobile.isEmpty) return;

    // 1. Check if Customer exists
    final List<Map<String, dynamic>> customerCheck = await txn.query(
      'customers', 
      where: 'name = ? AND mobile = ?', 
      whereArgs: [customerName, mobile]
    );

    int customerId;
    if (customerCheck.isEmpty) {
      // Create new customer if not found
      customerId = await txn.insert('customers', {
        'name': customerName,
        'mobile': mobile,
      });
    } else {
      customerId = customerCheck.first['id'] as int;
    }

    // 2. Check if this specific Car Number exists for this customer
    if (carNumber.isNotEmpty) {
      final List<Map<String, dynamic>> carCheck = await txn.query(
        'customer_cars', 
        where: 'customer_id = ? AND car_number = ?', 
        whereArgs: [customerId, carNumber]
      );

      if (carCheck.isEmpty) {
        // Add new car to this customer's profile
        await txn.insert('customer_cars', {
          'customer_id': customerId,
          'car_model': carModel,
          'car_number': carNumber,
        });
      }
    }
  }
  // Notice we now pass BOTH isPaid and sendWhatsApp from the UI screen
  // Changed from Future<bool> to Future<String?>
  Future<String?> saveBill(bool isPaid, bool sendWhatsApp) async {
    if (cart.isEmpty) return null;

    final db = await dbHelper.database;
    final String finalBillId = currentBillId ?? _generateNewBillId();

    try {
      await db.transaction((txn) async {
        // --- 1. SAVE TO DATABASE ---
        await _syncCustomerAndCar(txn);
        if (currentBillId != null) {
          await txn.delete('sale_items', where: 'sale_bill_id = ?', whereArgs: [finalBillId]);
          await txn.update('sales', {
            'customer_name': customerName,
            'mobile_number': mobile,
            'car_model': carModel,
            'car_number': carNumber,
            'car_km': carKm,
            'subtotal': subtotal,
            'discount_percent': discountPercent,
            'net_total': netTotal,
            'paid_status': isPaid ? 1 : 0,
          }, where: 'bill_id = ?', whereArgs: [finalBillId]);
        } else {
          await txn.insert('sales', {
            'bill_id': finalBillId,
            'customer_name': customerName,
            'mobile_number': mobile,
            'car_model': carModel,
            'car_number': carNumber,
            'car_km': carKm,
            'subtotal': subtotal,
            'discount_percent': discountPercent,
            'net_total': netTotal,
            'paid_status': isPaid ? 1 : 0,
            'date_time': DateTime.now().toIso8601String(),
            'is_deleted': 0
          });
        }

        for (int i = 0; i < cart.length; i++) {
          final item = cart[i];
          await txn.insert('sale_items', {
            'sale_bill_id': finalBillId,
            'sr_no': i + 1,
            'item_name': item.itemName,
            'quantity': item.quantity,
            'rate': item.rate,
            'amount': item.amount,
            'is_tracked': 0 
          });
          await txn.rawUpdate(
            'UPDATE inventory SET quantity = quantity - ? WHERE item_name = ?',
            [item.quantity, item.itemName]
          );
        }
      
    

      if (nextServiceReminder) {
          // TEST MODE: Set to exactly 1 day ago to guarantee the red dot triggers!
          DateTime dueDate = DateTime.now().add(const Duration(days: 364)); 

          await txn.insert('service_reminders', {
            'bill_id': finalBillId,
            'customer_name': customerName,
            'mobile_number': mobile,
            'car_number': carNumber,
            'service_due_date': dueDate.toIso8601String(),
            'is_notified': 0 
          });
        }
      });

      // --- 2. GENERATE PROFESSIONAL TEAL PDF ---
      final bizData = await db.query('business_details');
      final biz = bizData.isNotEmpty ? bizData.first : {'name': 'Billing System', 'address': '', 'phone': '', 'owner_name': ''};
      final tealColor = PdfColor.fromInt(0xFF2AA2B8); 

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(35),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(biz['name'].toString().toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: tealColor)),
                        pw.Text(biz['address'].toString(), style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("Phone: ${biz['phone']}", style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("INVOICE", style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: tealColor)),
                        pw.Text("Invoice #: $finalBillId"),
                        pw.Text("Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}"),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 2, color: tealColor),
                pw.SizedBox(height: 15),
                pw.Text("BILL TO:", style: pw.TextStyle(color: tealColor, fontWeight: pw.FontWeight.bold)),
                pw.Text(customerName.isEmpty ? "Walk-in Customer" : customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Phone: $mobile"),
                pw.Text("Vehicle: $carModel ($carNumber)"),
                pw.Text("KM Reading: $carKm"),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ["Sr.", "Item Description", "Qty", "Rate", "Amount"],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: pw.BoxDecoration(color: tealColor),
                  cellAlignment: pw.Alignment.centerRight,
                  cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft},
                  data: cart.asMap().entries.map((entry) {
                    int idx = entry.key;
                    CartItem item = entry.value;
                    return [(idx + 1).toString(), item.itemName, item.quantity.toString(), item.rate.toStringAsFixed(2), item.amount.toStringAsFixed(2)];
                  }).toList(),
                ),
                pw.SizedBox(height: 10),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Sub Total: Rs. ${subtotal.toStringAsFixed(2)}"),
                      pw.Text("Discount ($discountPercent%): - Rs. ${discountAmount.toStringAsFixed(2)}"),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        color: PdfColors.grey100,
                        child: pw.Text("Grand Total: Rs. ${netTotal.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: tealColor)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/Invoice_$finalBillId.pdf';
      final file = File(tempFilePath);
      await file.writeAsBytes(await pdf.save());

      // --- 3. WHATSAPP DIRECT TEXT ---
      if (sendWhatsApp && mobile.isNotEmpty) {
        String textInvoice = "🧾 *INVOICE: $finalBillId*\n"
            "👤 Customer: ${customerName.isEmpty ? 'Cash' : customerName}\n"
            "🚗 Vehicle: $carModel ($carNumber)\n"
            "💰 *TOTAL AMOUNT: ₹${netTotal.toStringAsFixed(2)}*\n\n"
            "Thank you for your business!\n"
            "– ${biz['name']}\n\n"
            "(Detailed PDF Invoice attaching next...)";

        String phone = mobile.startsWith('+91') ? mobile : '+91$mobile';
        phone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
        
        final Uri whatsappUri = Uri.parse("whatsapp://send?phone=$phone&text=${Uri.encodeComponent(textInvoice)}");
        
        try {
          await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint("Could not launch WhatsApp");
        }

        // Return the file path to the UI so it can pop the Share Menu safely!
        return tempFilePath;
      }
      else {
  // If unticked, just return SUCCESS so the UI knows to clear the form
  return "SUCCESS"; 
}

      

    } catch (e) {
      debugPrint("Error saving bill: $e");
      return null;
    }
  }
  // Helper function (if you don't already have it)
  String _generateNewBillId() {
    final now = DateTime.now();
    final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final randomId = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return "INV-$dateStr-$randomId";
  }

  void clearForm() {
    currentBillId = null;
    customerName = '';
    mobile = '';
    carModel = '';
    carNumber = '';
    carKm = '';
    cart.clear();
    discountPercent = 0.0;
    isPaid = true;
    sendWhatsapp = true;
    nextServiceReminder = false;
    notifyListeners();
  }
}