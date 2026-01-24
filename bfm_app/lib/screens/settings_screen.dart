/// ---------------------------------------------------------------------------
/// File: lib/screens/settings_screen.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Settings surface for managing OpenAI keys, disconnecting the bank link,
///   and accessing debug tools.
///
/// Called by:
///   `app.dart` when the user taps the Settings tab.
///
/// Inputs / Outputs:
///   Reads/writes API keys via `ApiKeyStore`, toggles SharedPreferences flags,
///   and routes to other screens as needed.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/screens/onboarding_screen.dart';
import 'package:bfm_app/services/api_key_store.dart';
import 'package:bfm_app/services/bank_service.dart';
import 'package:bfm_app/services/weekly_overview_service.dart';
import 'package:bfm_app/widgets/weekly_overview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings surface for keys, disconnect, and debug entry points.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// Holds controller state for the settings form.
class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  String _apiKeyStatus = '';
  bool _openingWeeklyOverview = false;

  /// Boots the API key load as soon as the screen mounts.
  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _openWeeklyOverviewFromSettings() async {
    if (_openingWeeklyOverview) return;
    setState(() => _openingWeeklyOverview = true);
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final payload = await WeeklyOverviewService.buildPayloadForLastWeek();
      if (!mounted) return;
      if (payload == null) {
        scaffold.showSnackBar(
          const SnackBar(
            content: Text(
              "Last week's overview isn't ready yet. Try again after transactions sync.",
            ),
          ),
        );
        return;
      }
      final navigator = Navigator.of(context);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WeeklyOverviewSheet(
            payload: payload,
            onFinish: () async {
              await WeeklyOverviewService.markOverviewHandled(payload.weekStart);
              navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
            },
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text('Unable to load weekly overview: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _openingWeeklyOverview = false);
      }
    }
  }

  /// Loads the stored API key, pre-fills the text field, and updates the inline
  /// status message.
  Future<void> _loadApiKey() async {
    final k = await ApiKeyStore.get();
    setState(() {
      _apiKeyCtrl.text = k ?? '';
      _apiKeyStatus = k == null || k.isEmpty ? 'No key saved' : 'Key saved ✓';
    });
  }

  /// Persists the key if it looks valid; otherwise surfaces inline help text.
  Future<void> _saveApiKey() async {
    final k = _apiKeyCtrl.text.trim();
    if (k.isEmpty) {
      setState(() => _apiKeyStatus = 'Please paste a valid key (sk-...)');
      return;
    }
    await ApiKeyStore.set(k);
    setState(() => _apiKeyStatus = 'Key saved ✓');
  }

  /// Removes the stored key and clears the text field/state.
  Future<void> _clearApiKey() async {
    await ApiKeyStore.clear();
    setState(() {
      _apiKeyCtrl.clear();
      _apiKeyStatus = 'Key cleared';
    });
  }

  /// Cleans up controllers.
  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _replayOnboarding(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replay onboarding?'),
        content: const Text(
          'You can walk through the intro questions and tour again without reconnecting your bank.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start tour'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(),
      ),
    );
  }

  @override
  /// Builds the full settings list:
  /// - API key card
  /// - Disconnect bank tile
  /// - Debug button
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // --- API Key section ---
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

          ListTile(
            leading: const Icon(Icons.auto_stories_outlined),
            title: const Text('Replay onboarding tour'),
            subtitle: const Text('Restart the welcome questions and tips without touching your bank link.'),
            onTap: () => _replayOnboarding(context),
          ),

          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text("Weekly overview (last week)"),
            subtitle: const Text('Review budgets, spend, and goal top-ups for the previous week.'),
            trailing: _openingWeeklyOverview
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _openingWeeklyOverview ? null : _openWeeklyOverviewFromSettings,
          ),

          // --- Disconnect Bank ---
          ListTile(
            leading: const Icon(Icons.link_off, color: Colors.red),
            title: const Text('Disconnect Bank'),
            subtitle:
                const Text('Remove bank account and all transactions data'),
            onTap: () async {
              // Confirm the action:
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
