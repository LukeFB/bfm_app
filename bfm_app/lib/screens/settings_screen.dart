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

import 'package:bfm_app/auth/credential_store.dart';
import 'package:bfm_app/controllers/auth_controller.dart';
import 'package:bfm_app/providers/api_providers.dart';
import 'package:bfm_app/screens/onboarding_screen.dart';
import 'package:bfm_app/services/api_key_store.dart';
import 'package:bfm_app/services/bank_service.dart';
import 'package:bfm_app/services/debug_log.dart';
import 'package:bfm_app/services/dev_config.dart';
import 'package:bfm_app/services/income_settings_store.dart';
import 'package:bfm_app/services/onboarding_store.dart';
import 'package:bfm_app/services/pin_store.dart';
import 'package:bfm_app/services/weekly_overview_service.dart';
import 'package:bfm_app/widgets/weekly_overview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings surface for keys, disconnect, and debug entry points.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// Holds controller state for the settings form.
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _referralCodeCtrl = TextEditingController();
  String _apiKeyStatus = '';
  bool _openingWeeklyOverview = false;
  IncomeType _incomeType = IncomeType.regular;
  bool _incomeTypeLoaded = false;

  List<Map<String, dynamic>> _organisations = [];
  bool _orgsLoading = false;
  bool _joiningOrg = false;
  String? _orgError;
  String? _orgSuccess;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadIncomeType();
    _loadOrganisations();
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

  // ---------------------------------------------------------------------------
  // Organisation / Referral Code
  // ---------------------------------------------------------------------------

  Future<void> _loadOrganisations() async {
    setState(() {
      _orgsLoading = true;
      _orgError = null;
    });
    try {
      final profileApi = ref.read(profileApiProvider);
      final orgs = await profileApi.organisations();
      if (!mounted) return;
      setState(() {
        _organisations = orgs;
        _orgsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orgsLoading = false;
        _orgError = 'Could not load organisations.';
      });
    }
  }

  Future<void> _joinOrganisation() async {
    final code = _referralCodeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _orgError = 'Please enter a referral code.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _joiningOrg = true;
      _orgError = null;
      _orgSuccess = null;
    });

    try {
      final profileApi = ref.read(profileApiProvider);
      await profileApi.joinOrganisation(code);
      _referralCodeCtrl.clear();
      if (!mounted) return;
      setState(() {
        _joiningOrg = false;
        _orgSuccess = 'Joined successfully!';
      });
      _loadOrganisations();
    } catch (e) {
      if (!mounted) return;
      String msg = 'Failed to join. Check the code and try again.';
      if (e.toString().contains('422')) {
        msg = 'Invalid or expired referral code.';
      } else if (e.toString().contains('409') || e.toString().contains('already')) {
        msg = 'You are already a member of this organisation.';
      }
      setState(() {
        _joiningOrg = false;
        _orgError = msg;
      });
    }
  }

  Future<void> _leaveOrganisation(int orgId, String orgName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave organisation?'),
        content: Text('Remove yourself from "$orgName"? You can rejoin later with a new referral code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() {
      _orgError = null;
      _orgSuccess = null;
    });

    try {
      final profileApi = ref.read(profileApiProvider);
      await profileApi.leaveOrganisation(orgId);
      if (!mounted) return;
      setState(() => _orgSuccess = 'Left "$orgName".');
      _loadOrganisations();
    } catch (e) {
      if (!mounted) return;
      setState(() => _orgError = 'Could not leave organisation.');
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

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _referralCodeCtrl.dispose();
    super.dispose();
  }

  /// Signs the user out of their account (clears session + credentials) but
  /// keeps local data intact. Sends them to the login screen.
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will be signed out and taken to the login screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await ref.read(authControllerProvider.notifier).logout();
    await CredentialStore().clear();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  /// Revokes the Akahu connection, deletes ALL local data (transactions,
  /// budgets, goals, chat, etc.), clears the PIN, and resets onboarding.
  /// This is a full factory reset of the app.
  Future<void> _confirmResetApp(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset app?'),
        content: const Text(
          'This will revoke your bank connection and delete ALL data '
          'including transactions, budgets, goals, and chat history. '
          'Your PIN will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset everything'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // Revoke Akahu session on the backend (best-effort)
    try {
      final akahuApi = ref.read(akahuApiProvider);
      await akahuApi.revoke();
    } catch (e) {
      debugPrint('Akahu revoke failed (continuing reset): $e');
    }

    // Wipe all local data
    await BankService.disconnect();
    await ref.read(authControllerProvider.notifier).logout();
    await CredentialStore().clear();
    await PinStore().clearPin();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
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
          // --- API Key section (dev only) ---
          if (kDevMode)
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

          // --- Organisation / Referral Code section ---
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
                      'Organisation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Join an organisation with a referral code from your advisor or provider.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    if (_orgsLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_organisations.isNotEmpty) ...[
                      ..._organisations.map((org) {
                        final name = org['name'] as String? ?? 'Organisation';
                        final id = org['id'] as int? ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.06),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.business_outlined,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Leave organisation',
                                  onPressed: () => _leaveOrganisation(id, name),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _referralCodeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'e.g. YEQX9A',
                              labelText: 'Referral code',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _joiningOrg ? null : _joinOrganisation,
                          child: _joiningOrg
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Join'),
                        ),
                      ],
                    ),

                    if (_orgError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _orgError!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                    if (_orgSuccess != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _orgSuccess!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
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

          const Divider(height: 32),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Reset app'),
            subtitle: const Text(
              'Revoke bank access and delete all data. Completely resets the app.',
            ),
            onTap: () => _confirmResetApp(context),
          ),

          if (kDevMode) ...[
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
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                  ),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text("API Log"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const _ApiLogScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Live viewer for API request timings captured by [DebugLog].
class _ApiLogScreen extends StatefulWidget {
  const _ApiLogScreen();

  @override
  State<_ApiLogScreen> createState() => _ApiLogScreenState();
}

class _ApiLogScreenState extends State<_ApiLogScreen> {
  @override
  Widget build(BuildContext context) {
    final entries = DebugLog.instance.entries.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: () {
              DebugLog.instance.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                'No API calls logged yet.\nUse the app and come back.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: entries.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final e = entries[index];
                final isError = e.message.contains('429') ||
                    e.message.contains('401') ||
                    e.message.contains('timeout');
                final isSlow = _extractMs(e.message) > 3000;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    e.formatted,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isError
                          ? Colors.red
                          : isSlow
                              ? Colors.orange.shade800
                              : Colors.black87,
                    ),
                  ),
                );
              },
            ),
    );
  }

  int _extractMs(String msg) {
    final match = RegExp(r'\((\d+)ms\)').firstMatch(msg);
    if (match == null) return 0;
    return int.tryParse(match.group(1)!) ?? 0;
  }
}
