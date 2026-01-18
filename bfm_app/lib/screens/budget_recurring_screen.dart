import 'package:flutter/material.dart';
import 'package:bfm_app/models/alert_model.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';
import 'package:bfm_app/repositories/alert_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/services/budget_analysis_service.dart';

/// Review recurring expenses after finishing the budget setup flow.
class BudgetRecurringScreen extends StatefulWidget {
  const BudgetRecurringScreen({super.key});

  @override
  State<BudgetRecurringScreen> createState() => _BudgetRecurringScreenState();
}

class _BudgetRecurringScreenState extends State<BudgetRecurringScreen> {
  bool _loading = true;
  bool _saving = false;
  List<RecurringTransactionModel> _weekly = [];
  List<RecurringTransactionModel> _monthly = [];
  final Map<int, bool> _selected = {};
  final Map<int, RecurringTransactionModel> _recurringById = {};
  final Map<int, TextEditingController> _nameCtrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in _nameCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    await BudgetAnalysisService.identifyRecurringTransactions();
    final all = await RecurringRepository.getAll();
    final expenses =
        all.where((r) => r.transactionType.toLowerCase() == 'expense');

    final weekly = expenses
        .where((r) => r.frequency.toLowerCase() == 'weekly')
        .toList()
      ..sort(_compareByDueDate);
    final monthly = expenses
        .where((r) => r.frequency.toLowerCase() == 'monthly')
        .toList()
      ..sort(_compareByDueDate);

    final alerts = await AlertRepository.getActiveRecurring();
    final alertsById = <int, AlertModel>{};
    for (final alert in alerts) {
      final rid = alert.recurringTransactionId;
      if (rid != null) alertsById[rid] = alert;
    }

    final combined = [...weekly, ...monthly];
    final selection = <int, bool>{};
    final map = <int, RecurringTransactionModel>{};
    final controllers = <int, TextEditingController>{};

    for (final r in combined) {
      final id = r.id;
      if (id == null) continue;
      map[id] = r;
      final alert = alertsById[id];
      selection[id] = alert != null;
      final fallback = (r.description ?? 'Recurring expense').trim();
      final initial = (alert?.title ?? fallback).trim();
      controllers[id] = TextEditingController(
        text: initial.isEmpty ? 'Recurring expense' : initial,
      );
    }

    for (final ctrl in _nameCtrls.values) {
      ctrl.dispose();
    }

    if (!mounted) {
      for (final ctrl in controllers.values) {
        ctrl.dispose();
      }
      return;
    }

    setState(() {
      _weekly = weekly;
      _monthly = monthly;
      _selected
        ..clear()
        ..addAll(selection);
      _recurringById
        ..clear()
        ..addAll(map);
      _nameCtrls
        ..clear()
        ..addAll(controllers);
      _loading = false;
    });
  }

  int _compareByDueDate(RecurringTransactionModel a, RecurringTransactionModel b) {
    DateTime? parse(String value) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }

    final ad = parse(a.nextDueDate);
    final bd = parse(b.nextDueDate);
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  @override
  Widget build(BuildContext context) {
    final hasRecurring = _weekly.isNotEmpty || _monthly.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-run detection',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [
                      Text(
                        'Select the payments you want alerts for',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We’ll remind you a few days before they’re due.',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      if (!hasRecurring)
                        const Text(
                          'No recurring expenses detected yet. Refresh after more transactions sync.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      if (_weekly.isNotEmpty) _buildSection('Weekly', _weekly),
                      if (_monthly.isNotEmpty)
                        _buildSection('Monthly', _monthly),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: FilledButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      onPressed: _saving ? null : _finishAndSave,
                      label: Text(_saving ? 'Saving...' : 'Finish'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _finishAndSave() async {
    await _saveAlerts(showToast: false);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/dashboard',
      (route) => false,
    );
  }

  Future<void> _saveAlerts({bool showToast = true}) async {
    setState(() => _saving = true);
    final selectedIds = _selected.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();

    for (final entry in _recurringById.entries) {
      final id = entry.key;
      final recurring = entry.value;
      if (selectedIds.contains(id)) {
        final controller = _nameCtrls[id];
        final customTitle = controller?.text.trim() ?? '';
        final fallback = (recurring.description ?? 'Recurring expense').trim();
        final title =
            customTitle.isNotEmpty ? customTitle : (fallback.isEmpty ? 'Recurring expense' : fallback);
        final icon =
            recurring.frequency.toLowerCase() == 'monthly' ? '📅' : '🔁';
        final message = 'Due soon for \$${recurring.amount.toStringAsFixed(2)}';
        await AlertRepository.upsertRecurringAlert(
          recurringId: id,
          title: title,
          message: message,
          icon: icon,
          leadTimeDays: 3,
        );
      } else {
        await AlertRepository.deleteByRecurringId(id);
      }
    }
    await AlertRepository.deleteAllNotIn(selectedIds);

    if (!mounted) return;
    setState(() => _saving = false);
    if (showToast) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedIds.isEmpty
                ? 'Recurring alerts cleared.'
                : '${selectedIds.length} alert${selectedIds.length == 1 ? '' : 's'} saved.',
          ),
        ),
      );
    }
  }

  Widget _buildSection(
      String label, List<RecurringTransactionModel> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                '$label recurring',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            for (var i = 0; i < items.length; i++) ...[
              _buildRecurringTile(items[i]),
              if (i != items.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringTile(RecurringTransactionModel item) {
    final id = item.id;
    if (id == null) return const SizedBox.shrink();
    final desc = (item.description ?? 'Recurring expense').trim();
    final fallback = desc.isEmpty ? 'Recurring expense' : desc;
    final controller = _nameCtrls.putIfAbsent(
      id,
      () => TextEditingController(text: fallback),
    );
    final dueLabel = _dueLabel(item);
    final selected = _selected[id] ?? false;

    final displayName =
        controller.text.trim().isEmpty ? fallback : controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: selected,
          onChanged: (value) => _toggleSelection(id, value ?? false),
          title: Text(displayName),
          subtitle: Text(
            '$dueLabel • \$${item.amount.toStringAsFixed(2)} / ${item.frequency}',
          ),
          secondary: Icon(
            selected ? Icons.notifications_active : Icons.notifications_none,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Alert name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  void _toggleSelection(int recurringId, bool value) {
    setState(() => _selected[recurringId] = value);
  }

  String _dueLabel(RecurringTransactionModel item) {
    try {
      final due = DateTime.parse(item.nextDueDate);
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);
      final normalizedDue = DateTime(due.year, due.month, due.day);
      final delta = normalizedDue.difference(normalizedToday).inDays;
      if (delta < 0) {
        return 'Overdue • ${_formatDate(normalizedDue)}';
      } else if (delta == 0) {
        return 'Due today';
      } else if (delta == 1) {
        return 'Due tomorrow';
      }
      return 'Due in $delta days • ${_formatDate(normalizedDue)}';
    } catch (_) {
      return 'Next due: ${item.nextDueDate}';
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}

