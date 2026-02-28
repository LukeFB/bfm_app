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
import 'package:bfm_app/services/income_settings_store.dart';
import 'package:bfm_app/services/weekly_overview_service.dart';
import 'package:bfm_app/widgets/weekly_overview_sheet.dart';
import 'package:flutter/material.dart';

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
  IncomeType _incomeType = IncomeType.regular;
  bool _incomeTypeLoaded = false;

  /// Boots the API key load as soon as the screen mounts.
  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadIncomeType();
  }

  Future<void> _loadIncomeType() async {
    final type = await IncomeSettingsStore.getIncomeType();
    if (mounted) {
      setState(() {
        _incomeType = type;
        _incomeTypeLoaded = true;
      });
    }
  }

  Future<void> _setIncomeType(IncomeType type) async {
    await IncomeSettingsStore.setIncomeType(type);
    // Mark as no longer auto-detected since user manually changed it
    await IncomeSettingsStore.markAutoDetected(false);
    if (mounted) {
      setState(() => _incomeType = type);
    }
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
          'This will re-sync your transactions and walk you through '
          'recurring payments, categories, and budgets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(replayMode: true),
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

          // --- Income Type section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Income Type',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose how your weekly income is calculated for budgeting.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (!_incomeTypeLoaded)
                      const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      Column(
                        children: [
                          RadioListTile<IncomeType>(
                            title: const Text('Regular income'),
                            subtitle: const Text(
                              'Steady paycheck (weekly/fortnightly). Uses last week\'s income.',
                            ),
                            value: IncomeType.regular,
                            groupValue: _incomeType,
                            onChanged: (v) => _setIncomeType(v!),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          RadioListTile<IncomeType>(
                            title: const Text('Non-regular income'),
                            subtitle: const Text(
                              'Variable earnings (gig work, freelance). Uses 4-week average.',
                            ),
                            value: IncomeType.nonRegular,
                            groupValue: _incomeType,
                            onChanged: (v) => _setIncomeType(v!),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

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
                      'This will delete all your data including transactions, budgets, and goals. You will need to start over. Are you sure?'),
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

              // Clear all user data and reset to fresh state
              await BankService.disconnect();

              // Navigate back to onboarding (reset navigation stack)
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/onboarding', (route) => false);
            },
          ),
          const SizedBox(height: 16),
          // --- Revoke Akahu (backend) ---
          // TODO: wire this to the production Akahu flow once backend auth is live
          ListTile(
            leading: const Icon(Icons.cloud_off, color: Colors.orange),
            title: const Text('Revoke Akahu Connection (backend)'),
            subtitle: const Text('Revoke Akahu session via the Moni backend'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Revoke Akahu?'),
                  content: const Text(
                    'This will revoke your Akahu session on the backend. '
                    'You will need to reconnect via the Akahu OAuth flow.',
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                    ElevatedButton(
                      child: const Text('Revoke'),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              );
              if (confirm != true || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Akahu revoke requires backend auth. Use Debug API screen.')),
              );
            },
          ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                ),
                icon: const Icon(Icons.bug_report),
                label: const Text("Debug Data"),
                onPressed: () {
                  Navigator.pushNamed(context, '/debug');
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                icon: const Icon(Icons.api),
                label: const Text("Debug API"),
                onPressed: () {
                  Navigator.pushNamed(context, '/debug-api');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
