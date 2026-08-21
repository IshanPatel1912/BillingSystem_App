import 'package:flutter/material.dart';
import '../customers/customer_screen.dart';
import '../settings/settings_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../bills/find_bill_screen.dart';
import '../portfolio/portfolio_screen.dart';

// Temporary Placeholders for our next steps
 

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More Options', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildMenuTile(
            context, 
            title: "Find Invoice", 
            subtitle: "Search, edit, and restore old bills", 
            icon: Icons.search_rounded, 
            color: Colors.orangeAccent, 
            targetScreen: const FindBillScreen(), 
          ),
          _buildMenuTile(
            context, 
            title: "Dashboard", 
            subtitle: "Daily stats and itemized views", 
            icon: Icons.dashboard_rounded, 
            color: const Color(0xFF2AA2B8), 
            targetScreen: const DashboardScreen(), // We will replace this next!
          ),
          _buildMenuTile(
            context, 
            title: "Portfolio Analytics", 
            subtitle: "Profit, Loss & Custom Date Reports", 
            icon: Icons.pie_chart_rounded, 
            color: const Color(0xFF9C27B0), 
            targetScreen: const PortfolioScreen(), // We will replace this next!
          ),
          _buildMenuTile(
            context, 
            title: "Customer Directory", 
            subtitle: "Manage relationships and vehicle memories", 
            icon: Icons.people_alt_rounded, 
            color: const Color(0xFF005A9E), 
            targetScreen: const CustomerScreen(),
          ),
          const Divider(height: 40, color: Colors.grey),
          _buildMenuTile(
            context, 
            title: "Settings & Security", 
            subtitle: "Business profile, users, and biometrics", 
            icon: Icons.settings_rounded, 
            color: Colors.grey, 
            targetScreen: const SettingsScreen(),
          ),
        ],
      ),
    );
  }

  // Helper widget to keep the code clean and UI futuristic
  Widget _buildMenuTile(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required Widget targetScreen}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
          );
        },
      ),
    );
  }
}