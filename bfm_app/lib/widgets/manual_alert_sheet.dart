import 'package:flutter/material.dart';

/// Structured result returned by the manual alert composer.
class ManualAlertFormData {
  final String title;
  final double? amount;
  final DateTime dueDate;
  final String? note;

  const ManualAlertFormData({
    required this.title,
    required this.dueDate,
    this.amount,
    this.note,
  });
}

/// Opens a bottom sheet that lets the user capture manual alert details.
Future<ManualAlertFormData?> showManualAlertSheet({
  required BuildContext context,
  String? initialTitle,
  double? initialAmount,
  DateTime? initialDueDate,
  String? initialNote,
  String headerLabel = 'Create alert',
}) {
  return showModalBottomSheet<ManualAlertFormData>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: _ManualAlertSheet(
        headerLabel: headerLabel,
        initialTitle: initialTitle,
        initialAmount: initialAmount,
        initialDueDate: initialDueDate,
        initialNote: initialNote,
      ),
    ),
  );
}

class _ManualAlertSheet extends StatefulWidget {
  final String headerLabel;
  final String? initialTitle;
  final double? initialAmount;
  final DateTime? initialDueDate;
  final String? initialNote;

  const _ManualAlertSheet({
    required this.headerLabel,
    this.initialTitle,
    this.initialAmount,
    this.initialDueDate,
    this.initialNote,
  });

  @override
  State<_ManualAlertSheet> createState() => _ManualAlertSheetState();
}

class _ManualAlertSheetState extends State<_ManualAlertSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  DateTime? _dueDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _amountCtrl = TextEditingController(
      text: _prefillAmount(widget.initialAmount),
    );
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
    _dueDate = widget.initialDueDate ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.headerLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Alert title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (optional)',
              prefixText: '\$',
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Due date',
                border: OutlineInputBorder(),
              ),
              child: Text(
                _dueDate == null ? 'Tap to select' : _friendlyDate(_dueDate!),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _submit,
                child: const Text('Save alert'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _dueDate == null) {
      setState(() {
        _error = 'Enter a title and choose a due date.';
      });
      return;
    }
    final amount = _parseCurrency(_amountCtrl.text.trim());
    Navigator.of(context).pop(
      ManualAlertFormData(
        title: title,
        dueDate: _dueDate!,
        amount: amount,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ),
    );
  }
}

double? _parseCurrency(String raw) {
  if (raw.trim().isEmpty) return null;
  final sanitized = raw.replaceAll(RegExp(r'[^0-9\.\-]'), '');
  final value = double.tryParse(sanitized);
  if (value == null || value.isNaN || value.isInfinite) return null;
  return value;
}

String _prefillAmount(double? value) {
  if (value == null || value <= 0) return '';
  final decimals = value >= 100 ? 0 : 2;
  return value.toStringAsFixed(decimals);
}

String _friendlyDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final month = months[date.month - 1];
  final day = date.day.toString().padLeft(2, '0');
  return '$day $month ${date.year}';
}
