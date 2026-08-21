import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/dashboard_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).loadDashboardData();
    });
  }

  void _pickDate(BuildContext context, DashboardProvider state) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) state.updateDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<DashboardProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2AA2B8)),
            onPressed: () => state.loadDashboardData(),
          )
        ],
      ),
      body: state.isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2AA2B8)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- DATE FILTER & STATS CARD ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('EEEE, MMM d, yyyy').format(state.selectedDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                    IconButton(
                      icon: const Icon(Icons.calendar_month, color: Colors.white),
                      onPressed: () => _pickDate(context, state),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Card(
                  color: const Color(0xFF2AA2B8).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFF2AA2B8), width: 1), borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Paid Sales", style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 5),
                              Text(state.salesCount.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 50, color: const Color(0xFF2AA2B8).withValues(alpha: 0.5)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Revenue (Paid)", style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 5),
                              Text("₹${state.totalRevenue.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // --- PURCHASES SECTION ---
                const Text("Itemized Purchases", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF107C10))),
                const SizedBox(height: 10),
                if (state.purchases.isEmpty)
                  const Padding(padding: EdgeInsets.only(bottom: 20), child: Text("No purchases recorded for this date.", style: TextStyle(color: Colors.grey)))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.purchases.length,
                    itemBuilder: (context, index) {
                      final p = state.purchases[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Text(p.time, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          title: Text(p.itemName),
                          trailing: Text("₹${p.amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),

                // --- EXPENSES SECTION ---
                const Text("Operating Expenses", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD83B01))),
                const SizedBox(height: 10),
                if (state.expenses.isEmpty)
                  const Padding(padding: EdgeInsets.only(bottom: 20), child: Text("No expenses recorded for this date.", style: TextStyle(color: Colors.grey)))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.expenses.length,
                    itemBuilder: (context, index) {
                      final e = state.expenses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long, color: Colors.grey),
                          title: Text(e.description),
                          trailing: Text("₹${e.amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
    );
  }
}