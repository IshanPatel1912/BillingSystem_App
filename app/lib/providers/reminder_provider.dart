import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/database_helper.dart';

class ServiceReminderModel {
  final int id;
  final String customerName;
  final String carNumber;
  final String mobileNumber;
  final DateTime dueDate;

  ServiceReminderModel({
    required this.id, required this.customerName, required this.carNumber,
    required this.mobileNumber, required this.dueDate
  });
}

class ReminderProvider extends ChangeNotifier {
  final dbHelper = DatabaseHelper.instance;
  List<ServiceReminderModel> dueReminders = [];
  bool isLoading = false;

  int get reminderCount => dueReminders.length;

  Future<void> loadReminders() async {
    isLoading = true;
    notifyListeners();

    final db = await dbHelper.database;
    // Get today's date at midnight to compare
    String todayStr = DateTime.now().toIso8601String();

    final results = await db.rawQuery('''
      SELECT * FROM service_reminders 
      WHERE service_due_date <= ? AND is_notified = 0
      ORDER BY service_due_date ASC
    ''', [todayStr]);

    dueReminders = results.map((r) => ServiceReminderModel(
      id: r['id'] as int,
      customerName: r['customer_name'].toString(),
      carNumber: r['car_number'].toString(),
      mobileNumber: r['mobile_number'].toString(),
      dueDate: DateTime.parse(r['service_due_date'].toString()),
    )).toList();

    isLoading = false;
    notifyListeners();
  }

  // Exact message format from your desktop app
  Future<void> sendWhatsAppReminder(ServiceReminderModel reminder) async {
    final bizData = await dbHelper.database.then((db) => db.query('business_details'));
    String bizName = bizData.isNotEmpty ? bizData.first['name'].toString() : "Service Center";
    
    String formattedDate = "${reminder.dueDate.day}-${reminder.dueDate.month}-${reminder.dueDate.year}";

    String message = "🔔 *Vehicle Service Reminder*\n"
        "Hello ${reminder.customerName},\n"
        "This is a reminder that the next service of your vehicle is due.\n"
        "🚗 Car Number: ${reminder.carNumber}\n"
        "📅 Service Due Date: $formattedDate\n"
        "Please contact us for booking.\n"
        "Thank you!\n"
        "– $bizName";

    // Format phone number to ensure it has country code
    String phone = reminder.mobileNumber;
    if (!phone.startsWith('+91')) phone = "+91$phone";
    phone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    // Launch WhatsApp
    final Uri whatsappUri = Uri.parse("whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}");
    
    try {
      await launchUrl(whatsappUri);
      await markAsNotified(reminder.id);
    } catch (e) {
      debugPrint("Could not launch WhatsApp");
    }
  }

  Future<void> markAsNotified(int id) async {
    final db = await dbHelper.database;
    await db.update('service_reminders', {'is_notified': 1}, where: 'id = ?', whereArgs: [id]);
    await loadReminders(); // Refresh the list
  }
}