import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/expenditure_provider.dart';

class ExpenditureScreen extends StatefulWidget {
  const ExpenditureScreen({super.key});

  @override
  State<ExpenditureScreen> createState() => _ExpenditureScreenState();
}

class _ExpenditureScreenState extends State<ExpenditureScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExpenditureProvider>(context, listen: false).loadExpenditures();
    });
  }

  void _pickFilterDate(BuildContext context, ExpenditureProvider state) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: state.filterDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) state.updateFilterDate(picked);
  }

  // Dynamic Add/Edit Modal
  void _showExpenseModal(BuildContext context, {ExpenditureItem? editItem}) {
    final descCtrl = TextEditingController(text: editItem?.description ?? '');
    final amtCtrl = TextEditingController(text: editItem?.amount.toString() ?? '');
    DateTime selectedInputDate = editItem?.date ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 20
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(editItem != null ? "Edit Expense" : "Add Expense", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFD83B01))),
                  const SizedBox(height: 15),
                  
                  // Date Picker for the specific expense
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedInputDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) setModalState(() => selectedInputDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Expense Date', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(DateFormat('dd-MM-yyyy').format(selectedInputDate)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  TextField(controller: descCtrl, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: "Description (e.g. Rent, Salary)", prefixIcon: Icon(Icons.notes))),
                  const SizedBox(height: 10),
                  TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount", prefixIcon: Icon(Icons.currency_rupee))),
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10), padding: const EdgeInsets.symmetric(vertical: 15)),
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: Text(editItem != null ? "UPDATE EXPENSE" : "SAVE EXPENSE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        bool success = await Provider.of<ExpenditureProvider>(context, listen: false).saveExpense(
                          id: editItem?.id,
                          date: selectedInputDate,
                          description: descCtrl.text,
                          amount: double.tryParse(amtCtrl.text) ?? 0,
                        );
                        if (success && context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense Saved!'), backgroundColor: Colors.green));
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<ExpenditureProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenditures', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD83B01), // Orange/Red color for expenses
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Expense", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showExpenseModal(context),
      ),
      body: Column(
        children: [
          // FILTER BAR
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A2A2A), padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.calendar_month, color: Colors.white),
                    label: Text("Filter: ${DateFormat('dd-MM-yyyy').format(state.filterDate)}", style: const TextStyle(color: Colors.white)),
                    onPressed: () => _pickFilterDate(context, state),
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Daily Total", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text("₹${state.totalExpense.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                )
              ],
            ),
          ),
          
          // EXPENSE LIST
          Expanded(
            child: state.isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD83B01)))
              : state.expenses.isEmpty 
                ? const Center(child: Text("No expenses recorded for this date.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: state.expenses.length,
                    itemBuilder: (context, index) {
                      final exp = state.expenses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF2A2A2A),
                            child: Icon(Icons.receipt_long, color: Colors.redAccent),
                          ),
                          title: Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text(DateFormat('dd-MMM-yyyy').format(exp.date)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("₹${exp.amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              PopupMenuButton<String>(
                                color: const Color(0xFF2A2A2A),
                                onSelected: (value) {
                                  if (value == 'edit') _showExpenseModal(context, editItem: exp);
                                  if (value == 'delete') {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Confirm Delete"),
                                        content: const Text("Remove this expense record?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () { state.deleteExpense(exp.id); Navigator.pop(ctx); },
                                            child: const Text("Delete", style: TextStyle(color: Colors.white)),
                                          )
                                        ],
                                      )
                                    );
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.white), SizedBox(width: 8), Text("Edit")])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.redAccent), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.redAccent))])),
                                ],
                              ),
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