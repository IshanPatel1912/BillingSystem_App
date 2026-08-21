import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load inventory as soon as the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadInventory();
    });
  }

  // Multi-Row Add Stock Modal
  void _showAddStockModal(BuildContext context) {
    // Local state for the dynamic list of rows
    List<Map<String, TextEditingController>> rows = [
      {'name': TextEditingController(), 'qty': TextEditingController(text: "0")}
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows it to move up with the keyboard
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom, // Avoid keyboard
                left: 16, right: 16, top: 20
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Add / Update Stock", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2AA2B8))),
                  const SizedBox(height: 15),
                  
                  // Dynamic List of Inputs
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: rows[index]['name'],
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(hintText: "Item Name"),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: rows[index]['qty'],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(hintText: "Qty"),
                                ),
                              ),
                              if (rows.length > 1) // Only show delete if there's more than 1 row
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                  onPressed: () => setModalState(() => rows.removeAt(index)),
                                )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  TextButton.icon(
                    icon: const Icon(Icons.add, color: Color(0xFF2AA2B8)),
                    label: const Text("Add Another Row", style: TextStyle(color: Color(0xFF2AA2B8))),
                    onPressed: () {
                      setModalState(() {
                        rows.add({'name': TextEditingController(), 'qty': TextEditingController(text: "0")});
                      });
                    },
                  ),
                  
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF107C10),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text("SAVE ALL STOCK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      onPressed: () async {
                        // Extract data from controllers
                        List<Map<String, dynamic>> stockData = rows.map((r) => {
                          'name': r['name']!.text,
                          'qty': r['qty']!.text,
                        }).toList();

                        var result = await Provider.of<InventoryProvider>(context, listen: false).saveStock(stockData);
                        
                        if (context.mounted) {
                          Navigator.pop(ctx); // Close modal
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Stock Added! New: ${result['added']} | Updated: ${result['updated']}'), backgroundColor: Colors.green)
                          );
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
    final state = Provider.of<InventoryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // FLOATING ACTION BUTTON (To trigger Add Stock)
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF008CBA),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Stock", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddStockModal(context),
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search Inventory...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    state.loadInventory();
                  },
                ),
              ),
              onChanged: (val) => state.loadInventory(val), // Live Search
            ),
          ),
          
          // INVENTORY LIST
          Expanded(
            child: state.isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2AA2B8)))
              : state.items.isEmpty 
                ? const Center(child: Text("No items found in inventory.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2AA2B8).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text("Qty: ${item.quantity.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2AA2B8))),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () {
                                  // CONFIRMATION DIALOG
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Confirm Delete"),
                                      content: Text("Delete '${item.itemName}' from inventory?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                          onPressed: () {
                                            state.deleteItem(item.itemName);
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text("Delete", style: TextStyle(color: Colors.white)),
                                        )
                                      ],
                                    )
                                  );
                                },
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