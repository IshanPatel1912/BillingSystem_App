import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  String _currentLogoPath = '';

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = Provider.of<SettingsProvider>(context, listen: false);
      await state.loadSettings();
      _nameCtrl.text = state.bizName;
      _addressCtrl.text = state.bizAddress;
      _phoneCtrl.text = state.bizPhone;
      _ownerCtrl.text = state.bizOwner;
      _currentLogoPath = state.logoPath;
      setState(() {});
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _currentLogoPath = image.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // --- SECURITY & BIOMETRICS CARD ---
            const Text("Security", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2AA2B8))),
            const SizedBox(height: 10),
            Card(
              child: SwitchListTile(
                title: const Text("Enable Biometric Login", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Use Fingerprint or Face Unlock to open the app"),
                secondary: const Icon(Icons.fingerprint, color: Color(0xFF2AA2B8), size: 30),
                activeThumbColor: const Color(0xFF2AA2B8),
                value: state.isBiometricEnabled,
                onChanged: (bool value) => state.toggleBiometrics(value),
              ),
            ),
            const SizedBox(height: 20),

            // --- BUSINESS DETAILS CARD ---
            const Text("Business Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF005A9E))),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Logo Picker
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF2A2A2A),
                        backgroundImage: _currentLogoPath.isNotEmpty ? FileImage(File(_currentLogoPath)) : null,
                        child: _currentLogoPath.isEmpty 
                          ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                          : null,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Business Name", prefixIcon: Icon(Icons.business))),
                    const SizedBox(height: 10),
                    TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: "Address", prefixIcon: Icon(Icons.location_on))),
                    const SizedBox(height: 10),
                    TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: "Phone", prefixIcon: Icon(Icons.phone))),
                    const SizedBox(height: 10),
                    TextField(controller: _ownerCtrl, decoration: const InputDecoration(labelText: "Owner Name", prefixIcon: Icon(Icons.person))),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9E), padding: const EdgeInsets.symmetric(vertical: 12)),
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text("SAVE BUSINESS INFO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          bool success = await state.saveBusinessDetails(
                            name: _nameCtrl.text, address: _addressCtrl.text,
                            phone: _phoneCtrl.text, owner: _ownerCtrl.text, logo: _currentLogoPath
                          );
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business Details Updated!'), backgroundColor: Colors.green));
                          }
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- USER MANAGEMENT CARD ---
            const Text("User Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF107C10))),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _userCtrl, decoration: const InputDecoration(hintText: "Username"))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(hintText: "Password"))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10)),
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: const Text("ADD / UPDATE USER", style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          String msg = await state.saveUser(_userCtrl.text.trim(), _passCtrl.text.trim());
                          if (context.mounted) {
                            _userCtrl.clear(); _passCtrl.clear();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                          }
                        },
                      ),
                    ),
                    const Divider(height: 30, color: Colors.grey),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.users.length,
                      itemBuilder: (context, index) {
                        final u = state.users[index];
                        return ListTile(
                          leading: const Icon(Icons.person, color: Colors.grey),
                          title: Text(u.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () async {
                              String msg = await state.deleteUser(u.id, u.username);
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                            },
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}