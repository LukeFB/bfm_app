/// ---------------------------------------------------------------------------
/// File: lib/screens/settings_screen.dart
/// Author: Luke Fraser-Brown
///
/// High-level description:
///   Settings page extended with an API key section, without removing your
///   existing "Disconnect Bank" tile and "View Debug Data" button.
///
/// Design notes:
///   - Converted to StatefulWidget to manage API key text & status.
///   - Keeps your existing ListTile/ElevatedButton untouched.
///   - Adds a small card to Save/Clear the OpenAI API key (stored securely).
/// ---------------------------------------------------------------------------

import 'package:bfm_app/services/bank_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Added
import 'package:bfm_app/services/api_key_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  String _apiKeyStatus = '';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final k = await ApiKeyStore.get();
    setState(() {
      _apiKeyCtrl.text = k ?? '';
      _apiKeyStatus = k == null || k.isEmpty ? 'No key saved' : 'Key saved ✓';
    });
  }

  Future<void> _saveApiKey() async {
    final k = _apiKeyCtrl.text.trim();
    if (k.isEmpty) {
      setState(() => _apiKeyStatus = 'Please paste a valid key (sk-...)');
      return;
    }
    await ApiKeyStore.set(k);
    setState(() => _apiKeyStatus = 'Key saved ✓');
  }

  Future<void> _clearApiKey() async {
    await ApiKeyStore.clear();
    setState(() {
      _apiKeyCtrl.clear();
      _apiKeyStatus = 'Key cleared';
    });
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // --- NEW: API Key section (keeps your existing tiles/buttons intact)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OpenAI API Key',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'sk-...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: _saveApiKey,
                          child: const Text('Save'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _clearApiKey,
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        Text(
                          _apiKeyStatus,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- YOUR EXISTING ITEMS (unchanged) ---
          ListTile(
            leading: const Icon(Icons.link_off, color: Colors.red),
            title: const Text('Disconnect Bank'),
            subtitle:
                const Text('Remove bank account and all transactions data'),
            onTap: () async {
              // Confirm the action (optional):
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Disconnect Bank'),
                  content: const Text(
                      'This will delete all imported transactions. Are you sure?'),
                  actions: [
                    TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.pop(ctx, false)),
                    ElevatedButton(
                        child: const Text('Disconnect'),
                        onPressed: () => Navigator.pop(ctx, true)),
                  ],
                ),
              );

              if (confirm != true) return;

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('bank_connected', false);

              // Clear all transaction and recurring transaction data from the database
              await BankService.disconnect();

              // (If you stored the bank access token or other info, also clear it here)
              // Navigate back to BankConnectScreen (reset navigation stack)
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/bankconnect', (route) => false);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
            ),
            icon: const Icon(Icons.bug_report),
            label: const Text("View Debug Data"),
            onPressed: () {
              Navigator.pushNamed(context, '/debug');
            },
          ),

          // ... add more settings options here ...
        ],
      ),
    );
  }
}
