import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/database_helper.dart';
import '../../providers/find_bill_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/billing_provider.dart';
import '../billing/billing_screen.dart';

class FindBillScreen extends StatefulWidget {
  const FindBillScreen({super.key});

  @override
  State<FindBillScreen> createState() => _FindBillScreenState();
}

class _FindBillScreenState extends State<FindBillScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FindBillProvider>(context, listen: false).searchBills();
    });
  }

  void _pickDate(BuildContext context, FindBillProvider state) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: state.dateFilter ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) state.updateFilters(date: picked);
  }

  // --- NEW: NATIVE PDF EXPORT ENGINE ---
  Future<void> _exportBillPDF(BuildContext context, String billId) async {
    final db = await DatabaseHelper.instance.database;
    final saleData = await db.query('sales', where: 'bill_id = ?', whereArgs: [billId]);
    final itemsData = await db.query('sale_items', where: 'sale_bill_id = ?', whereArgs: [billId]);
    final bizData = await db.query('business_details');

    if (saleData.isEmpty) return;
    final sale = saleData.first;
    final biz = bizData.isNotEmpty ? bizData.first : {'name': 'Billing System', 'address': '', 'phone': '', 'owner_name': ''};
    
    final tealColor = PdfColor.fromInt(0xFF2AA2B8); // Your Brand Teal

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER SECTION
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
                      pw.Text("Invoice #: ${sale['bill_id']}"),
                      pw.Text("Date: ${sale['date_time'].toString().split(' ')[0]}"),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: tealColor),
              pw.SizedBox(height: 15),

              // BILL TO SECTION
              pw.Text("BILL TO:", style: pw.TextStyle(color: tealColor, fontWeight: pw.FontWeight.bold)),
              pw.Text(sale['customer_name'].toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text("Phone: ${sale['mobile_number']}"),
              pw.Text("Vehicle: ${sale['car_model']} (${sale['car_number']})"),
              pw.Text("KM Reading: ${sale['car_km']}"),
              pw.SizedBox(height: 20),

              // ITEMS TABLE
              pw.TableHelper.fromTextArray(
                headers: ["Sr.", "Item Description", "Qty", "Rate", "Amount"],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: tealColor),
                cellAlignment: pw.Alignment.centerRight,
                cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft},
                data: itemsData.map((item) => [
                  item['sr_no'].toString(),
                  item['item_name'],
                  item['quantity'].toString(),
                  item['rate'].toString(),
                  item['amount'].toString()
                ]).toList(),
              ),

              // TOTALS SECTION
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Sub Total: Rs. ${sale['subtotal']}"),
                    pw.Text("Discount (${sale['discount_percent']}%): - Rs. ${(double.parse(sale['subtotal'].toString()) - double.parse(sale['net_total'].toString())).toStringAsFixed(2)}"),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      color: PdfColors.grey100,
                      child: pw.Text("Grand Total: Rs. ${sale['net_total']}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: tealColor)),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // FOOTER & TERMS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Terms & Conditions:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text("1. Goods once sold will not be taken back.", style: const pw.TextStyle(fontSize: 9)),
                      pw.Text("2. Warranty as per manufacturer terms.", style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 30),
                      pw.Text("_______________________"),
                      pw.Text("Authorized Signature", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<FindBillProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Find Invoice', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // --- SEARCH & FILTER BAR ---
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: const TextStyle(color: Colors.white),
                            value: state.searchCategory,
                            isExpanded: true,
                            items: ["Bill ID", "Customer Name", "Car Number", "Mobile Number"].map((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text(value));
                            }).toList(),
                            onChanged: (val) => state.updateFilters(category: val),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search...",
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: Color(0xFF2AA2B8)),
                            onPressed: () => state.updateFilters(term: _searchCtrl.text),
                          ),
                        ),
                        onSubmitted: (val) => state.updateFilters(term: val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Secondary Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      DropdownButton<String>(
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white),
                        value: state.statusFilter,
                        items: ["All", "Paid", "Unpaid"].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (val) => state.updateFilters(status: val),
                      ),
                      const SizedBox(width: 15),
                      ActionChip(
                        backgroundColor: state.dateFilter != null ? const Color(0xFF2AA2B8).withValues(alpha: 0.3) : const Color(0xFF2A2A2A),
                        label: Text(state.dateFilter != null ? DateFormat('dd-MM-yyyy').format(state.dateFilter!) : "Any Date", style: const TextStyle(color: Colors.white)),
                        avatar: const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                        onPressed: () => _pickDate(context, state),
                      ),
                      if (state.dateFilter != null)
                        IconButton(icon: const Icon(Icons.clear, color: Colors.redAccent, size: 20), onPressed: () => state.clearDateFilter()),
                      const SizedBox(width: 10),
                      FilterChip(
                        backgroundColor: const Color(0xFF2A2A2A),
                        selectedColor: Colors.redAccent.withValues(alpha: 0.3),
                        label: const Text("Recycle Bin", style: TextStyle(color: Colors.white)),
                        avatar: Icon(Icons.delete_outline, color: state.showRecycleBin ? Colors.redAccent : Colors.grey, size: 16),
                        selected: state.showRecycleBin,
                        onSelected: (val) => state.updateFilters(recycle: val),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          
          // --- BILL LIST ---
          Expanded(
            child: state.isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2AA2B8)))
              : state.bills.isEmpty 
                ? const Center(child: Text("No bills found.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.bills.length,
                    itemBuilder: (context, index) {
                      final bill = state.bills[index];
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(bill.billId, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2AA2B8))),
                              Text(DateFormat('dd-MMM-yyyy').format(bill.date), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 5),
                              Text("${bill.customerName} • ${bill.carNumber}", style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Text("₹${bill.netTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: bill.isPaid ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                    child: Text(bill.isPaid ? "PAID" : "UNPAID", style: TextStyle(color: bill.isPaid ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              )
                            ],
                          ),
                          
                          // --- UPDATED ACTION MENU ---
                          trailing: PopupMenuButton<String>(
                            color: const Color(0xFF2A2A2A),
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            onSelected: (value) async {
                              
                              if (value == 'edit') {
                                final billingState = Provider.of<BillingProvider>(context, listen: false);
                                await billingState.loadBillForEdit(bill.billId);
                                if (context.mounted) {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingScreen()));
                                }
                              } 
                              else if (value == 'pdf') {
                                _exportBillPDF(context, bill.billId);
                              } 
                              else if (value == 'restore') {
                                await state.restoreBill(bill.billId);
                                if (context.mounted) Provider.of<InventoryProvider>(context, listen: false).loadInventory();
                              }
                              else if (value == 'delete') {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    title: Text(state.showRecycleBin ? "Permanent Delete" : "Move to Recycle Bin", style: const TextStyle(color: Colors.white)),
                                    content: Text(state.showRecycleBin ? "This cannot be undone." : "Inventory will be restored to the shelf.", style: const TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                        onPressed: () async {
                                          Navigator.pop(ctx); // FIX: Close dialog immediately before processing!
                                          await state.deleteBill(bill.billId, state.showRecycleBin);
                                          if (context.mounted) {
                                            Provider.of<InventoryProvider>(context, listen: false).loadInventory();
                                          }
                                        },
                                        child: const Text("Delete", style: TextStyle(color: Colors.white)),
                                      )
                                    ],
                                  )
                                );
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              if (!state.showRecycleBin) const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.white), SizedBox(width: 8), Text("Edit Bill", style: TextStyle(color: Colors.white))])),
                              if (!state.showRecycleBin) const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 18, color: Colors.white), SizedBox(width: 8), Text("Export PDF", style: TextStyle(color: Colors.white))])),
                              if (state.showRecycleBin) const PopupMenuItem(value: 'restore', child: Row(children: [Icon(Icons.restore, size: 18, color: Colors.greenAccent), SizedBox(width: 8), Text("Restore Bill", style: TextStyle(color: Colors.greenAccent))])),
                              PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, size: 18, color: Colors.redAccent), const SizedBox(width: 8), Text(state.showRecycleBin ? "Permanent Delete" : "Delete to Bin", style: const TextStyle(color: Colors.redAccent))])),
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