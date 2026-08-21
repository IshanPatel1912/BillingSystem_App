import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/purchase_history_provider.dart';
import '../../providers/inventory_provider.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PurchaseHistoryProvider>(context, listen: false).loadHistory();
    });
  }

  void _pickDate(BuildContext context, PurchaseHistoryProvider state) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      state.updateDate(picked);
    }
  }

  void _showEditModal(BuildContext context, HistoryItem item, PurchaseHistoryProvider state) {
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final rateCtrl = TextEditingController(text: item.rate.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Edit: ${item.itemName}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2AA2B8))),
              const SizedBox(height: 15),
              TextField(
                controller: qtyCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Quantity"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rateCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Rate / Cost"),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10), padding: const EdgeInsets.symmetric(vertical: 15)),
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text("UPDATE & FIX INVENTORY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    double newQty = double.tryParse(qtyCtrl.text) ?? item.quantity;
                    double newRate = double.tryParse(rateCtrl.text) ?? item.rate;
                    
                    bool success = await state.editHistoryItem(item, newQty, newRate);
                    if (success && context.mounted) {
                      Provider.of<InventoryProvider>(context, listen: false).loadInventory(); // Sync master inventory UI
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully!'), backgroundColor: Colors.green));
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PurchaseHistoryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- FILTER BAR ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A2A2A)),
                    icon: const Icon(Icons.calendar_month, color: Colors.white),
                    label: Text("${state.selectedDate.day}-${state.selectedDate.month}-${state.selectedDate.year}", style: const TextStyle(color: Colors.white)),
                    onPressed: () => _pickDate(context, state),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.redAccent),
                  tooltip: "Clear Filter (Go to Today)",
                  onPressed: () => state.clearFilter(),
                )
              ],
            ),
          ),
          
          // --- HISTORY LIST ---
          Expanded(
            child: state.isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2AA2B8)))
              : state.historyItems.isEmpty 
                ? const Center(child: Text("No purchases found for this date.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: state.historyItems.length,
                    itemBuilder: (context, index) {
                      final item = state.historyItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(item.itemName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.isTracked ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: Text(item.isTracked ? "Tracked" : "General", style: TextStyle(color: item.isTracked ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text("${item.quantity} x ₹${item.rate.toStringAsFixed(2)}  =  ₹${item.amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, color: Colors.grey)),
                              const Divider(color: Colors.grey),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                                    label: const Text("Edit", style: TextStyle(color: Colors.grey)),
                                    onPressed: () => _showEditModal(context, item, state),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                    label: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Confirm Delete"),
                                          content: const Text("Delete this record? This will reverse inventory calculations."),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                              onPressed: () async {
                                                await state.deleteHistoryItem(item);
                                                if (context.mounted) {
                                                  Provider.of<InventoryProvider>(context, listen: false).loadInventory();
                                                  Navigator.pop(ctx);
                                                }
                                              },
                                              child: const Text("Delete", style: TextStyle(color: Colors.white)),
                                            )
                                          ],
                                        )
                                      );
                                    },
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}