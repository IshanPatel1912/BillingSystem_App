import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/reminder_provider.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReminderProvider>(context, listen: false).loadReminders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<ReminderProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Service Reminders Due"),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: state.isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2AA2B8)))
        : state.dueReminders.isEmpty 
          ? const Center(child: Text("No pending reminders!", style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.dueReminders.length,
              itemBuilder: (context, index) {
                final rem = state.dueReminders[index];
                return Card(
                  color: const Color(0xFF2A2A2A),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(rem.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text("🚗 ${rem.carNumber}", style: const TextStyle(color: Colors.white70)),
                        Text("📱 Ph: ${rem.mobileNumber}", style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 5),
                        Text("Due: ${DateFormat('dd-MMM-yyyy').format(rem.dueDate)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.wechat, color: Color(0xFF25D366), size: 36), // WhatsApp Icon
                          tooltip: "Send WhatsApp Reminder",
                          onPressed: () => state.sendWhatsAppReminder(rem),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}