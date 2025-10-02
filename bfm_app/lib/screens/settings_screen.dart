import 'package:flutter/material.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
// (import others if needed, e.g., for any stored tokens or account info)

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.link_off, color: Colors.red),
            title: const Text('Disconnect Bank'),
            subtitle: const Text('Remove bank account and all transactions data'),
            onTap: () async {
              // Confirm the action (optional):
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Disconnect Bank'),
                  content: const Text('This will delete all imported transactions. Are you sure?'),
                  actions: [
                    TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx, false)),
                    ElevatedButton(child: const Text('Disconnect'), onPressed: () => Navigator.pop(ctx, true)),
                  ],
                ),
              );

              if (confirm != true) return;

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('bank_connected', false);

              // 1. Clear all transaction data from the database
              await TransactionRepository.deleteAll();
              // (If you stored the bank access token or other info, also clear it here)
              // 2. Navigate back to BankConnectScreen (reset navigation stack)
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/bankconnect', (route) => false);
            },
          ),
          // ... you can add more settings options here ...
        ],
      ),
    );
  }
}
