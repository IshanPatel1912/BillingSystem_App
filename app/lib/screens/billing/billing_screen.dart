import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/reminder_provider.dart';
import 'package:share_plus/share_plus.dart';


class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  // Standard Controllers
  bool _isPaid = true;
  bool _sendWhatsApp = true;

  final _mobileCtrl = TextEditingController();
  final _carModelCtrl = TextEditingController();
  final _carNoCtrl = TextEditingController();
  final _carKmCtrl = TextEditingController();
  final _qtyController = TextEditingController(text: "1");
  final _rateController = TextEditingController(text: "0");
  final _discountController = TextEditingController(text: "0.00");

  // Autocomplete Controllers
  TextEditingController? _autoCustNameCtrl;
  TextEditingController? _autoItemCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
      Provider.of<InventoryProvider>(context, listen: false).loadInventory();
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = Provider.of<BillingProvider>(context, listen: false);
    
    // If we are in edit mode, sync the controllers once
    if (state.currentBillId != null) {
      _autoCustNameCtrl?.text = state.customerName;
      _mobileCtrl.text = state.mobile;
      _carModelCtrl.text = state.carModel;
      _carNoCtrl.text = state.carNumber;
      _carKmCtrl.text = state.carKm;
      _discountController.text = state.discountPercent.toString();
    }
  }

  void _clearAllUI(BillingProvider state) {
    state.clearForm();
    _autoCustNameCtrl?.clear(); 
    _mobileCtrl.clear();
    _carModelCtrl.clear();
    _carNoCtrl.clear();
    _carKmCtrl.clear();
    _autoItemCtrl?.clear();     
    _qtyController.text = "1";
    _rateController.text = "0";
    _discountController.text = "0.00";
    setState(() {}); // Force UI refresh
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<BillingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.currentBillId != null ? 'Edit Invoice' : 'New Invoice', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.clear_all, color: Colors.white),
            label: const Text("Clear", style: TextStyle(color: Colors.white)),
            onPressed: () => _clearAllUI(state),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CUSTOMER DETAILS CARD ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 1. SMART CUSTOMER AUTOCOMPLETE (WITH MULTI-CAR LOGIC)
                    Autocomplete<CustomerData>(
                      displayStringForOption: (CustomerData option) => option.name,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<CustomerData>.empty();
                        final custState = Provider.of<CustomerProvider>(context, listen: false);
                        return custState.customers.where((c) => 
                          c.name.toLowerCase().contains(textEditingValue.text.toLowerCase())
                        );
                      },
                      onSelected: (CustomerData selection) {
                        state.customerName = selection.name;
                        _mobileCtrl.text = selection.mobile;
                        state.mobile = selection.mobile;
                        
                        if (selection.cars.length == 1) {
                          // Only 1 car -> Auto-fill instantly
                          _carModelCtrl.text = selection.cars.first['car_model'].toString();
                          state.carModel = _carModelCtrl.text;
                          _carNoCtrl.text = selection.cars.first['car_number'].toString();
                          state.carNumber = _carNoCtrl.text;
                        } else if (selection.cars.length > 1) {
                          // Multiple cars -> Ask user to select (Replicating Desktop Logic)
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Select Vehicle", style: TextStyle(color: Color(0xFF2AA2B8), fontWeight: FontWeight.bold)),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: selection.cars.length,
                                  itemBuilder: (context, index) {
                                    final car = selection.cars[index];
                                    return ListTile(
                                      leading: const Icon(Icons.directions_car, color: Color(0xFF2AA2B8)),
                                      title: Text(car['car_model'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(car['car_number'].toString()),
                                      onTap: () {
                                        _carModelCtrl.text = car['car_model'].toString();
                                        state.carModel = _carModelCtrl.text;
                                        _carNoCtrl.text = car['car_number'].toString();
                                        state.carNumber = _carNoCtrl.text;
                                        Navigator.pop(ctx);
                                      },
                                    );
                                  },
                                ),
                              ),
                            )
                          );
                        }
                      },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                        _autoCustNameCtrl = controller;
                        if (state.currentBillId != null && controller.text.isEmpty) {
                          controller.text = state.customerName;
                        }
                        controller.addListener(() => state.customerName = controller.text);
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Customer Name', prefixIcon: Icon(Icons.person)),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mobileCtrl,
                      decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      onChanged: (val) => state.mobile = val,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _carModelCtrl,
                            decoration: const InputDecoration(labelText: 'Car Model'),
                            textInputAction: TextInputAction.next,
                            onChanged: (val) => state.carModel = val,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _carNoCtrl,
                            decoration: const InputDecoration(labelText: 'Car No. (GJ05...)'),
                            textInputAction: TextInputAction.next,
                            onChanged: (val) => state.carNumber = val,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _carKmCtrl,
                      decoration: const InputDecoration(labelText: 'KM Reading', prefixIcon: Icon(Icons.speed)),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (val) => state.carKm = val,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- ADD ITEM (WITH AUTOCOMPLETE) ---
            Row(
              children: [
                Expanded(
                  flex: 3, 
                  child: Autocomplete<InventoryItem>(
                    displayStringForOption: (InventoryItem option) => option.itemName,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable<InventoryItem>.empty();
                      final invState = Provider.of<InventoryProvider>(context, listen: false);
                      return invState.items.where((item) => 
                        item.itemName.toLowerCase().contains(textEditingValue.text.toLowerCase())
                      );
                    },
                    onSelected: (InventoryItem selection) {},
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      _autoItemCtrl = controller;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(hintText: 'Item Name (Auto-fills)')
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1, 
                  child: TextField(
                    controller: _qtyController, 
                    keyboardType: TextInputType.number, 
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Qty')
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2, 
                  child: TextField(
                    controller: _rateController, 
                    keyboardType: TextInputType.number, 
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(hintText: 'Rate')
                  )
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF2AA2B8), size: 36),
                  onPressed: () async {
                    if (_autoItemCtrl == null) return;
                    String? error = await state.checkAndAddItem(
                      _autoItemCtrl!.text,
                      double.tryParse(_qtyController.text) ?? 1,
                      double.tryParse(_rateController.text) ?? 0,
                    );
                    
                    if (error != null && context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Stock Alert", style: TextStyle(color: Colors.redAccent)),
                          content: Text(error),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
                        )
                      );
                    } else {
                      _autoItemCtrl!.clear();
                      _qtyController.text = "1";
                      _rateController.text = "0";
                    }
                  },
                )
              ],
            ),
            const SizedBox(height: 20),

            // --- CART LIST ---
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.cart.length,
              itemBuilder: (context, index) {
                final item = state.cart[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${item.quantity} x ₹${item.rate.toStringAsFixed(2)}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("₹${item.amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => state.removeItem(index))
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // --- CHECKBOXES ---
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterChip(
                  label: const Text("WhatsApp"),
                  selected: _sendWhatsApp,
                  onSelected: (val) {
                    setState(() {
                      _sendWhatsApp = val;
                    });
                  },
                  selectedColor: const Color(0xFF25D366).withValues(alpha: 0.3),
                ),
                FilterChip(
                  label: const Text("Next Service Reminder"),
                  selected: state.nextServiceReminder,
                  onSelected: (val) => state.toggleReminder(val),
                ),
                FilterChip(
                  label: const Text("Paid"),
                  selected: _isPaid,
                  onSelected: (val) {
                    setState(() {
                      _isPaid = val;
                    });
                  },
                  selectedColor: Colors.greenAccent.withValues(alpha: 0.3),
                ),
              ],
            ),
          ],
        ),
      ),
      
      // --- BOTTOM SAVE BAR ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), border: Border(top: BorderSide(color: Colors.grey.shade800))),
        child: SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Disc %"),
                  onChanged: (val) => state.updateDiscount(val),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total: ₹${state.netTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF107C10),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final wasEditing = state.currentBillId != null; 
                  String? result = await state.saveBill(_isPaid, _sendWhatsApp);
                  
                  if (result != null && context.mounted) {
                    _clearAllUI(state); 
                    Provider.of<ReminderProvider>(context, listen: false).loadReminders();
                    if (result == "SUCCESS") {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bill Saved Successfully!'), backgroundColor: Colors.green)
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Chat opened! Tap to attach PDF 👉', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          backgroundColor: const Color(0xFF25D366),
                          duration: const Duration(seconds: 15),
                          action: SnackBarAction(
                            label: 'ATTACH PDF',
                            textColor: Colors.white,
                            backgroundColor: Colors.black,
                            onPressed: () async {
                              // ignore: deprecated_member_use
                              await Share.shareXFiles(
                                [XFile(result)], 
                                text: "Here is your detailed PDF Invoice.",
                                subject: "Invoice"
                              );
                            },
                          ),
                        )
                      );
                    }

                    if (wasEditing) {
                      Navigator.pop(context);
                    }
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}