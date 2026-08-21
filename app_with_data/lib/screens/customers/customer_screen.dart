import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/customer_provider.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
    });
  }

  Future<void> _exportToPDF(BuildContext context, CustomerProvider state) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Text("Customer Directory", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ["Name", "Mobile", "Vehicles"],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF005A9E)),
              cellAlignment: pw.Alignment.centerLeft,
              data: state.customers.map((c) {
                String cars = c.cars.map((car) => "${car['car_model']} (${car['car_number']})").join("\n");
                return [c.name, c.mobile, cars.isEmpty ? "None" : cars];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- UPDATED DYNAMIC ADD/EDIT MODAL ---
  void _showCustomerModal(BuildContext context, {CustomerData? editCustomer}) {
    final nameCtrl = TextEditingController(text: editCustomer?.name ?? '');
    final mobileCtrl = TextEditingController(text: editCustomer?.mobile ?? '');
    
    // Dynamic List to hold multiple vehicles
    List<Map<String, TextEditingController>> carRows = [];

    // Pre-fill existing cars if editing
    if (editCustomer != null && editCustomer.cars.isNotEmpty) {
      for (var car in editCustomer.cars) {
        carRows.add({
          'model': TextEditingController(text: car['car_model'].toString()),
          'number': TextEditingController(text: car['car_number'].toString()),
        });
      }
    } else {
      // Default empty row for new customers
      carRows.add({'model': TextEditingController(), 'number': TextEditingController()});
    }

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
                  Text(editCustomer != null ? "Edit Customer" : "Add Customer", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF005A9E))),
                  const SizedBox(height: 15),
                  
                  TextField(controller: nameCtrl, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: "Customer Name", prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 10),
                  TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: "Mobile Number", prefixIcon: Icon(Icons.phone))),
                  const SizedBox(height: 20),
                  
                  const Text("Vehicles", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  
                  // Dynamic list of car fields
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: carRows.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: carRows[index]['model'], 
                                  textInputAction: TextInputAction.next, 
                                  decoration: const InputDecoration(hintText: "Car Model (Swift)")
                                )
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: carRows[index]['number'], 
                                  textInputAction: TextInputAction.next, 
                                  decoration: const InputDecoration(hintText: "Car No. (GJ05...)")
                                )
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                onPressed: () {
                                  setModalState(() {
                                    carRows.removeAt(index);
                                  });
                                },
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  TextButton.icon(
                    icon: const Icon(Icons.add, color: Color(0xFF005A9E)),
                    label: const Text("Add Another Vehicle", style: TextStyle(color: Color(0xFF005A9E))),
                    onPressed: () {
                      setModalState(() {
                        carRows.add({'model': TextEditingController(), 'number': TextEditingController()});
                      });
                    },
                  ),
                  
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10), padding: const EdgeInsets.symmetric(vertical: 15)),
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: Text(editCustomer != null ? "UPDATE CUSTOMER" : "SAVE CUSTOMER", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        // Extract all cars
                        List<Map<String, String>> carsToSave = [];
                        for (var row in carRows) {
                          if (row['number']!.text.isNotEmpty) {
                            carsToSave.add({
                              'car_model': row['model']!.text,
                              'car_number': row['number']!.text,
                            });
                          }
                        }

                        bool success = await Provider.of<CustomerProvider>(context, listen: false).saveCustomer(
                          id: editCustomer?.id,
                          name: nameCtrl.text,
                          mobile: mobileCtrl.text,
                          cars: carsToSave,
                        );
                        
                        if (success && context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer Saved!'), backgroundColor: Colors.green));
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
    final state = Provider.of<CustomerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            tooltip: "Export to PDF",
            onPressed: () => _exportToPDF(context, state),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF005A9E),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Add Customer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showCustomerModal(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search Name, Mobile, or Car...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    state.loadCustomers();
                  },
                ),
              ),
              onChanged: (val) => state.loadCustomers(val),
            ),
          ),
          
          Expanded(
            child: state.isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF005A9E)))
              : state.customers.isEmpty 
                ? const Center(child: Text("No customers found.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: state.customers.length,
                    itemBuilder: (context, index) {
                      final cust = state.customers[index];
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
                                  Text(cust.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2AA2B8))),
                                  Row(
                                    children: [
                                      IconButton(icon: const Icon(Icons.edit, color: Colors.grey), onPressed: () => _showCustomerModal(context, editCustomer: cust)),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text("Confirm Delete"),
                                              content: Text("Delete '${cust.name}' and their car records?"),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                  onPressed: () {
                                                    state.deleteCustomer(cust.id);
                                                    Navigator.pop(ctx);
                                                  },
                                                  child: const Text("Delete", style: TextStyle(color: Colors.white)),
                                                )
                                              ],
                                            )
                                          );
                                        },
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              Text("📞 ${cust.mobile}", style: const TextStyle(fontSize: 15)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: cust.cars.map((car) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: const Color(0xFF005A9E).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: Text("🚗 ${car['car_model']} (${car['car_number']})", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                )).toList(),
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