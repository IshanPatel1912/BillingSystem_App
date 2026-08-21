import 'package:flutter/material.dart';
import 'core/database_helper.dart';
import 'providers/billing_provider.dart';
import 'screens/billing/billing_screen.dart';
import 'package:provider/provider.dart';
import 'providers/inventory_provider.dart';
import 'screens/inventory/inventory_screen.dart';
import 'providers/purchase_provider.dart';
import 'screens/purchases/purchases_screen.dart';
import 'providers/customer_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'providers/purchase_history_provider.dart';
import 'providers/expenditure_provider.dart';
import 'screens/expenditures/expenditure_screen.dart';
import 'screens/more/more_screen.dart';
import 'providers/dashboard_provider.dart';
import 'providers/find_bill_provider.dart';
import 'providers/portfolio_provider.dart';
import 'screens/reminders_screen.dart';
import 'providers/reminder_provider.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize DB on startup to ensure instant UI response later
  await DatabaseHelper.instance.database; 
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BillingProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseHistoryProvider()),
        ChangeNotifierProvider(create: (_) => ExpenditureProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => FindBillProvider()),
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
      ],
      child: const ModernBillingApp(),
    ),
  );
}

class ModernBillingApp extends StatelessWidget {
  const ModernBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billing System',
      debugShowCheckedModeBanner: false,
      // FUTURISTIC DARK MODE
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF2AA2B8), // Teal from your PDF generator
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2AA2B8),
          secondary: Color(0xFF005A9E),
          surface: Color(0xFF1E1E1E),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2AA2B8), width: 2),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // We will build these screens step-by-step
  final List<Widget> _screens = [
    const BillingScreen(),        // Index 0
    const PurchasesScreen(),      // Index 1
    const ExpenditureScreen(),    // Index 2
    const InventoryScreen(),      // Index 3
    const MoreScreen(),           // Index 4
  ];

  @override
  void initState() {
    super.initState();
    // Fetch reminders as soon as the app starts!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReminderProvider>(context, listen: false).loadReminders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Billing System", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          Consumer<ReminderProvider>(
            builder: (context, state, child) {
              return IconButton(
                icon: Badge(
                  // Only show the red dot if there are reminders!
                  isLabelVisible: state.reminderCount > 0, 
                  label: Text('${state.reminderCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  child: const Icon(Icons.notifications, color: Colors.white, size: 28),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RemindersScreen()));
                },
              );
            },
          ),
          const SizedBox(width: 10), // A little padding on the right edge
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: const Color(0xFF2AA2B8).withValues(alpha: 0.3),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale_rounded), label: 'Billing'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_rounded), label: 'Purchases'),
          NavigationDestination(icon: Icon(Icons.money_off_rounded), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.menu_rounded), label: 'More'),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Text(
          "$title is under construction.\nReady for next step.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}