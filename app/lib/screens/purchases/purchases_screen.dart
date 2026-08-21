import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/inventory_provider.dart';
import 'purchase_history_screen.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Purchases', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.history, color: Color(0xFF2AA2B8)),
              tooltip: "View Purchase History",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PurchaseHistoryScreen()),
                );
              },
            )
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF2AA2B8),
            tabs: [
              Tab(icon: Icon(Icons.inventory), text: "📦 Tracked (Stock)"),
              Tab(icon: Icon(Icons.receipt), text: "📝 General Purchase"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PurchaseTabLayout(isTracked: true),
            _PurchaseTabLayout(isTracked: false),
          ],
        ),
      ),
    );
  }
}

class _PurchaseTabLayout extends StatefulWidget {
  final bool isTracked;
  const _PurchaseTabLayout({required this.isTracked});

  @override
  State<_PurchaseTabLayout> createState() => _PurchaseTabLayoutState();
}

class _PurchaseTabLayoutState extends State<_PurchaseTabLayout> {
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();
  
  // This special controller fixes the Autocomplete not clearing bug
  TextEditingController? _autoCompleteCtrl;

  void _pickDate(BuildContext context, PurchaseProvider state) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != state.selectedDate) {
      state.updateDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PurchaseProvider>(context);
    final cart = widget.isTracked ? state.trackedCart : state.generalCart;
    final totalAmount = cart.fold(0.0, (sum, item) => sum + item.amount);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- REDESIGNED INPUT AREA (Mobile Friendly) ---
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // Row 1: Full width Item Name
                        widget.isTracked 
                          ? Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                                final invState = Provider.of<InventoryProvider>(context, listen: false);
                                return invState.items
                                    .map((e) => e.itemName)
                                    .where((name) => name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                              },
                              onSelected: (String selection) {
                                _itemController.text = selection;
                              },
                              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                                // Save reference to the hidden controller so we can clear it later
                                _autoCompleteCtrl = controller;
                                controller.addListener(() { _itemController.text = controller.text; });
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'Item Name (Auto-fills)', prefixIcon: Icon(Icons.search)),
                                );
                              },
                            )
                          : TextField(
                              controller: _itemController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Genral Purchase', prefixIcon: Icon(Icons.description)),
                            ),
                        
                        const SizedBox(height: 12),
                        
                        // Row 2: Qty, Rate, and Add Button
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _qtyController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(labelText: 'Qty'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _rateController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(labelText: widget.isTracked ? 'Cost Price' : 'Rate'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.isTracked ? const Color(0xFF107C10) : const Color(0xFFD83B01),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Icon(Icons.add, color: Colors.white),
                              onPressed: () {
                                state.addItem(
                                  isTracked: widget.isTracked,
                                  name: _itemController.text,
                                  qty: double.tryParse(_qtyController.text) ?? 0,
                                  rate: double.tryParse(_rateController.text) ?? 0,
                                );
                                // CLEAR EVERYTHING PROPERLY
                                _itemController.clear();
                                _autoCompleteCtrl?.clear(); 
                                _qtyController.clear();
                                _rateController.clear();
                              },
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- LIST OF ITEMS ---
                if (cart.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("List is empty. Add items above.", style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${item.quantity} x ₹${item.rate.toStringAsFixed(2)}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("₹${item.amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => state.removeItem(isTracked: widget.isTracked, index: index),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),

        // --- REDESIGNED BOTTOM SAVE BAR (Overflow Proof) ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), 
            border: Border(top: BorderSide(color: Colors.grey.shade800)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5))]
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Takes only needed height
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                      label: Text(
                        "${state.selectedDate.day}-${state.selectedDate.month}-${state.selectedDate.year}", 
                        style: const TextStyle(color: Colors.white70)
                      ),
                      onPressed: () => _pickDate(context, state),
                    ),
                    Text("Total: ₹${totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, // Full width button
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isTracked ? const Color(0xFF107C10) : const Color(0xFFD83B01),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: Text(widget.isTracked ? "SAVE STOCK PURCHASE" : "SAVE EXPENSE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: () async {
                      bool success = await state.savePurchase(widget.isTracked);
                      if (success && context.mounted) {
                        Provider.of<InventoryProvider>(context, listen: false).loadInventory();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Saved Successfully!'), backgroundColor: Colors.green));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}