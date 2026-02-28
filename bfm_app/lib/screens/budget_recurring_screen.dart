import 'package:flutter/material.dart';
import 'package:bfm_app/models/alert_model.dart';
import 'package:bfm_app/models/recurring_transaction_model.dart';
import 'package:bfm_app/repositories/alert_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/services/budget_analysis_service.dart';
import 'package:bfm_app/services/alert_notification_service.dart';
import 'package:bfm_app/utils/category_emoji_helper.dart';
import 'package:bfm_app/widgets/manual_alert_sheet.dart';

/// Review recurring expenses after finishing the budget setup flow.
class BudgetRecurringScreen extends StatefulWidget {
  const BudgetRecurringScreen({super.key});

  @override
  State<BudgetRecurringScreen> createState() => _BudgetRecurringScreenState();
}

class _BudgetRecurringScreenState extends State<BudgetRecurringScreen> {
  bool _loading = true;
  // ignore: unused_field
  bool _saving = false;
  List<RecurringTransactionModel> _recurring = [];
  final Map<int, bool> _selected = {};
  final Map<int, RecurringTransactionModel> _recurringById = {};
  final Map<int, TextEditingController> _nameCtrls = {};
  final Map<int, String> _categoryNames = {};
  List<AlertModel> _manualAlerts = [];
  List<AlertModel> _cancelAlerts = [];
  CategoryEmojiHelper? _emojiHelper;

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
    final cancelAlerts = await AlertRepository.getActiveCancelAlerts();
    final manualAlerts = (await AlertRepository.getAll())
        .where((alert) =>
            alert.recurringTransactionId == null &&
            alert.isActive &&
            alert.type != AlertType.cancelSubscription)
        .toList()
      ..sort(_compareAlertsByDueDate);
    final alertsById = <int, AlertModel>{};
    for (final alert in alerts) {
      final rid = alert.recurringTransactionId;
      if (rid != null) alertsById[rid] = alert;
    }

    final combined = [...weekly, ...monthly]..sort(_compareByDueDate);
    final selection = <int, bool>{};
    final map = <int, RecurringTransactionModel>{};
    final controllers = <int, TextEditingController>{};
    final categoryIds = combined.map((r) => r.categoryId).toSet();
    final categoryNames = await CategoryRepository.getNamesByIds(categoryIds);
    final emojiHelper = await CategoryEmojiHelper.ensureLoaded();

    for (final r in combined) {
      final id = r.id;
      if (id == null) continue;
      map[id] = r;
      final alert = alertsById[id];
      selection[id] = alert != null;
      final fallback = _displayName(r, categoryNames);
      final initial = (alert?.title ?? fallback).trim();
      controllers[id] = TextEditingController(
        text: initial.isEmpty ? fallback : initial,
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
      _recurring = combined;
      _selected
        ..clear()
        ..addAll(selection);
      _recurringById
        ..clear()
        ..addAll(map);
      _nameCtrls
        ..clear()
        ..addAll(controllers);
      _categoryNames
        ..clear()
        ..addAll(categoryNames);
      _manualAlerts = manualAlerts;
      _cancelAlerts = cancelAlerts;
      _emojiHelper = emojiHelper;
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

  bool get _isOnboarding =>
      (ModalRoute.of(context)?.settings.arguments as bool?) ?? false;

  @override
  Widget build(BuildContext context) {
    final onboarding = _isOnboarding;
    return WillPopScope(
      onWillPop: () async {
        await _saveAlerts(showToast: false);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !onboarding,
          title: const Text('Alerts'),
          actions: onboarding
              ? [
                  TextButton(
                    onPressed: _saving ? null : _finishOnboarding,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Finish'),
                  ),
                ]
              : null,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Text(
                    'Manage your alerts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toggle recurring payment reminders and review '
                    'subscriptions flagged for cancellation.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  _buildAlertsSection(),
                  const SizedBox(height: 32),
                ],
              ),
      ),
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
        final fallback = _displayNameForItem(recurring);
        final title = customTitle.isNotEmpty ? customTitle : fallback;
        final emojiSource = customTitle.isNotEmpty ? customTitle : fallback;
        final icon = _emojiHelper?.emojiForName(emojiSource) ??
            CategoryEmojiHelper.defaultEmoji;
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

  Future<void> _finishOnboarding() async {
    await _saveAlerts();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/dashboard',
      (route) => false,
    );
  }

  Widget _buildAlertsSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  const Text(
                    'Alerts',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _createManualAlert,
                    icon: const Icon(Icons.add),
                    label: const Text('Add alert'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_manualAlerts.isEmpty && _recurring.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No alerts yet. Tap “Add alert” to create one.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            if (_manualAlerts.isNotEmpty)
              ..._manualAlerts.map(
                (alert) => Column(
                  children: [
                    ListTile(
                      leading: Text(
                        _manualAlertEmoji(alert),
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(alert.title),
                      subtitle: Text(_manualAlertSubtitle(alert)),
                      onLongPress: () => _editManualAlert(alert),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete alert',
                        onPressed: alert.id == null
                            ? null
                            : () => _deleteManualAlert(alert),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            if (_cancelAlerts.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Divider(height: 1, thickness: 1, indent: 16, endIndent: 8)),
                    Text(
                      'Cancel these subscriptions',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE53935)),
                    ),
                    Expanded(child: Divider(height: 1, thickness: 1, indent: 8, endIndent: 16)),
                  ],
                ),
              ),
              ..._cancelAlerts.map(
                (alert) => Column(
                  children: [
                    ListTile(
                      leading: Text(
                        alert.icon ?? '🚫',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        alert.title,
                        style: TextStyle(
                          decoration: alert.isCompleted ? TextDecoration.lineThrough : null,
                          color: alert.isCompleted ? Colors.black38 : null,
                        ),
                      ),
                      subtitle: Text(
                        alert.isCompleted
                            ? 'Done'
                            : alert.amount != null
                                ? 'Save \$${alert.amount!.toStringAsFixed(2)} by cancelling'
                                : 'Consider cancelling to save money',
                      ),
                      trailing: alert.isCompleted
                          ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50))
                          : IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50)),
                              tooltip: 'Mark as done',
                              onPressed: () => _markCancelAlertDone(alert),
                            ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ],
            if (_recurring.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 8,
                      ),
                    ),
                    Text(
                      'Recurring payment alerts',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        indent: 8,
                        endIndent: 16,
                      ),
                    ),
                  ],
                ),
              ),
              ..._recurring.map(
                (item) => Column(
                  children: [
                    _buildRecurringTile(item),
                    if (item != _recurring.last) const Divider(height: 1),
                  ],
                ),
              ),
            ],
            if (_manualAlerts.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Hold an alert to edit it.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createManualAlert() async {
    final form = await showManualAlertSheet(
      context: context,
      headerLabel: 'New alert',
      initialDueDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (form == null) return;

    final alert = AlertModel(
      title: form.title,
      message: form.note,
      icon: '⏰',
      amount: form.amount,
      dueDate: form.dueDate,
    );
    final id = await AlertRepository.insert(alert);
    try {
      await AlertNotificationService.instance
          .schedule(alert.copyWith(id: id));
    } catch (err) {
      debugPrint('Alert scheduling failed: $err');
    }
    if (!mounted) return;
    setState(() {
      _manualAlerts
        ..add(alert.copyWith(id: id))
        ..sort(_compareAlertsByDueDate);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Alert '${form.title}' saved.")),
    );
  }

  Future<void> _editManualAlert(AlertModel alert) async {
    final form = await showManualAlertSheet(
      context: context,
      headerLabel: 'Edit alert',
      initialTitle: alert.title,
      initialAmount: alert.amount,
      initialDueDate: alert.dueDate,
      initialNote: alert.message,
    );
    if (form == null) return;

    final updated = alert.copyWith(
      title: form.title,
      amount: form.amount,
      dueDate: form.dueDate,
      message: form.note ?? alert.message,
    );
    await AlertRepository.update(updated);
    try {
      await AlertNotificationService.instance.schedule(updated);
    } catch (err) {
      debugPrint('Alert reschedule failed: $err');
    }
    if (!mounted) return;
    setState(() {
      final idx = _manualAlerts.indexWhere((a) => a.id == alert.id);
      if (idx != -1) {
        _manualAlerts[idx] = updated;
        _manualAlerts.sort(_compareAlertsByDueDate);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Alert '${form.title}' updated.")),
    );
  }

  Future<void> _deleteManualAlert(AlertModel alert) async {
    if (alert.id == null) return;
    await AlertRepository.delete(alert.id!);
    try {
      await AlertNotificationService.instance.cancel(alert.id!);
    } catch (err) {
      debugPrint('Alert cancel failed: $err');
    }
    if (!mounted) return;
    setState(() {
      _manualAlerts.removeWhere((a) => a.id == alert.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Alert '${alert.title}' deleted.")),
    );
  }

  Future<void> _markCancelAlertDone(AlertModel alert) async {
    if (alert.id == null) return;
    await AlertRepository.markCompleted(alert.id!);
    if (!mounted) return;
    setState(() {
      _cancelAlerts.removeWhere((a) => a.id == alert.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("'${alert.title}' marked as done.")),
    );
  }

  String _displayNameForItem(RecurringTransactionModel item) =>
      _displayName(item, _categoryNames);

  static String _displayName(
    RecurringTransactionModel item,
    Map<int, String> names,
  ) {
    final descFirstWord = _firstWord(item.description);
    if (descFirstWord.isNotEmpty) return descFirstWord;

    final categoryLabel = names[item.categoryId];
    final categoryFirstWord = _firstWord(categoryLabel);
    if (categoryFirstWord.isNotEmpty &&
        categoryFirstWord.toLowerCase() != 'uncategorized') {
      return categoryFirstWord;
    }

    return 'Subscription';
  }

  static String _firstWord(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'\S+').stringMatch(trimmed);
    return match ?? '';
  }

  Widget _buildRecurringTile(RecurringTransactionModel item) {
    final id = item.id;
    if (id == null) return const SizedBox.shrink();
    final fallback = _displayNameForItem(item);
    _nameCtrls.putIfAbsent(id, () => TextEditingController(text: fallback));
    final dueLabel = _dueLabel(item);
    final selected = _selected[id] ?? false;
    final categoryLabel = _categoryNames[item.categoryId] ?? '';
    final emojiSource = categoryLabel.trim().isNotEmpty
        ? categoryLabel
        : (item.description ?? fallback);
    final emoji = _emojiHelper?.emojiForName(emojiSource) ??
        CategoryEmojiHelper.defaultEmoji;

    return CheckboxListTile(
      value: selected,
      onChanged: (value) => _toggleSelection(id, value ?? false),
      title: Text(fallback),
      subtitle: Text(
        '$dueLabel · \$${item.amount.toStringAsFixed(2)} / ${item.frequency}',
      ),
      secondary: Text(
        emoji,
        style: const TextStyle(fontSize: 24),
      ),
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
        return 'Overdue';
      } else if (delta == 0) {
        return 'Due today';
      } else if (delta == 1) {
        return 'Due tomorrow';
      }
      return 'Due in $delta days';
    } catch (_) {
      return 'Next due: ${item.nextDueDate}';
    }
  }

  int _compareAlertsByDueDate(AlertModel a, AlertModel b) {
    final ad = a.dueDate ?? DateTime.tryParse(a.createdAt ?? '') ?? DateTime.now();
    final bd = b.dueDate ?? DateTime.tryParse(b.createdAt ?? '') ?? DateTime.now();
    return ad.compareTo(bd);
  }

  String _manualAlertSubtitle(AlertModel alert) {
    final due = alert.dueDate;
    final dueLabel =
        due != null ? _manualDueLabel(due) : (alert.message ?? 'Reminder saved');
    final amountLabel =
        alert.amount != null ? ' • ${_formatCurrency(alert.amount!)}' : '';
    return '$dueLabel$amountLabel';
  }

  String _manualAlertEmoji(AlertModel alert) {
    final source =
        alert.title.trim().isNotEmpty ? alert.title : (alert.message ?? '');
    return _emojiHelper?.emojiForName(source) ??
        alert.icon ??
        CategoryEmojiHelper.defaultEmoji;
  }

  String _manualDueLabel(DateTime due) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDue = DateTime(due.year, due.month, due.day);
    final delta = normalizedDue.difference(normalizedToday).inDays;
    if (delta < 0) {
      return 'Overdue';
    } else if (delta == 0) {
      return 'Due today';
    } else if (delta == 1) {
      return 'Due tomorrow';
    }
    return 'Due in $delta days';
  }

  String _formatCurrency(double value) {
    final decimals = value.abs() >= 100 ? 0 : 2;
    return '\$${value.toStringAsFixed(decimals)}';
  }
}

