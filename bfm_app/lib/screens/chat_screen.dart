// ---------------------------------------------------------------------------
// File: lib/screens/chat_screen.dart
// Author: Luke Fraser-Brown
//
// Called by:
//   - `/chat` route via the bottom navigation.
//
// Purpose:
//   - Chat UI that talks to Moni AI directly (no backend) while preserving
//     context between sessions.
//
// Inputs:
//   - User-entered text, stored chat history, optional API key.
//
// Outputs:
//   - Renders AI responses, persists conversation history, and surfaces helpful
//     errors if no key is configured.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';
import 'package:bfm_app/screens/dashboard_screen.dart';

import 'package:bfm_app/models/alert_model.dart';
import 'package:bfm_app/models/budget_model.dart';
import 'package:bfm_app/models/chat_message.dart';
import 'package:bfm_app/models/chat_suggested_action.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/repositories/alert_repository.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/referral_repository.dart';
import 'package:bfm_app/services/ai_client.dart';
import 'package:bfm_app/services/api_key_store.dart';
import 'package:bfm_app/services/chat_action_extractor.dart';
import 'package:bfm_app/services/chat_constants.dart';
import 'package:bfm_app/services/chat_storage.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:bfm_app/widgets/manual_alert_sheet.dart';

/// Top-level chat screen that wraps the Moni messenger UI.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Handles conversation state, persistence, and network calls.
class _ChatScreenState extends State<ChatScreen> {
  // Replaced _Message with ChatMessage to integrate with storage + AI.
  final List<ChatMessage> _messages = [];

  final TextEditingController _controller = TextEditingController();

  // scroll controller to keep view pinned to the latest messages.
  final ScrollController _scroll = ScrollController();

  // Services
  late final AiClient _ai;
  late final ChatStorage _store;
  final ChatActionExtractor _actionExtractor = ChatActionExtractor();

  // UI guards
  bool _sending = false;
  bool _hasApiKey = false;
  Map<String, String> _referralLinks = {};
  bool _actionLoading = false;
  bool _savingAction = false;
  final List<ChatSuggestedAction> _pendingActions = [];

  // How many most-recent turns to send with each request
  static const int kContextWindowTurns = kChatContextWindowTurns;

  /// Sets up the AI + storage services and loads history.
  @override
  void initState() {
    super.initState();
    _ai = AiClient(); // pulls API key internally from ApiKeyStore
    _store = ChatStorage();
    _bootstrap();
  }

  /// Disposes controllers to avoid leaks.
  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Loads persisted messages, seeds the greeting when empty, and checks if an
  /// API key exists so the UI can hint accordingly.
  Future<void> _bootstrap() async {
    // Load persisted messages (if any)
    final persisted = await _store.loadMessages();
    if (persisted.isNotEmpty) {
      setState(() {
        _messages.addAll(persisted);
      });
      // ensure the list is scrolled to bottom after loading history.
      _scrollToBottom();
    } else {
      // Seed welcome greeting
      _messages.add(ChatMessage.assistant(
        "Kia ora! How can I help with your budget today?",
      ));
      await _store.saveMessages(_messages);
      setState(() {});
      // scroll to the bottom after first paint.
      _scrollToBottom();
    }

    // Check if an API key is present (so we can optionally disable send)
    final key = await ApiKeyStore.get();
    setState(() {
      _hasApiKey = (key != null && key.isNotEmpty);
    });

    await _loadReferralLinks();
  }

  Future<void> _loadReferralLinks() async {
    try {
      final referrals = await ReferralRepository.getActive(limit: 100);
      final linkMap = <String, String>{};
      for (final ref in referrals) {
        final name = ref.organisationName?.trim();
        final website = ref.website?.trim();
        if (name?.isNotEmpty == true && website?.isNotEmpty == true) {
          linkMap[name!] = website!;
        }
      }
      if (!mounted) return;
      setState(() => _referralLinks = linkMap);
    } catch (_) {
      // Swallow errors; chat can still function without link expansion.
    }
  }

  /// Helper to jump the ListView to the bottom after the next frame.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  List<Map<String, String>> _buildRecentTurns() {
    final start = _messages.length > kContextWindowTurns
        ? _messages.length - kContextWindowTurns
        : 0;
    return _messages
        .sublist(start)
        .map((m) => m.toOpenAiRoleContent())
        .toList();
  }

  /// Pushes the user message, sends it through AiClient, handles retries, and
  /// appends the assistant response (or an error bubble) while persisting both.
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    // Append the user message to the UI and persist
    final userMsg = ChatMessage.user(text);
    final lastUserText = userMsg.content;
    _messages.add(userMsg);
    _controller.clear();
    await _store.saveMessages(_messages);
    setState(() {});
    _scrollToBottom(); // keep view pinned to newest message.

    try {
      // Build a rolling window of the last N turns for the model
      final recent = _buildRecentTurns();
      final replyText = await _ai.complete(recent);
      final replyWithLinks = _injectReferralLinks(replyText);

      // Append assistant response and persist
      final botMsg = ChatMessage.assistant(replyWithLinks);
      _messages.add(botMsg);
      await _store.saveMessages(_messages);
      setState(() {});
      _scrollToBottom(); // scroll to bottom when bot replies.
      unawaited(_detectActions(
        _buildRecentTurns(),
        lastUserMessage: lastUserText,
      ));
    } catch (e) {
      // Friendly error bubble (keeps your style)
      _messages.add(ChatMessage.assistant(
        "Sorry, I couldn’t reply just now. ${_prettyErr(e)}",
      ));
      await _store.saveMessages(_messages);
      setState(() {});
      _scrollToBottom(); // maintain scroll position.
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  Future<void> _detectActions(
    List<Map<String, String>> turns, {
    String? lastUserMessage,
  }) async {
    if (!_hasApiKey) return;
    setState(() => _actionLoading = true);
    var actions = await _actionExtractor.identifyActions(turns);
    actions = _ensureBillCoverage(actions, lastUserMessage);
    actions = _filterActionsForUtterance(actions, lastUserMessage);
    actions = _ensureBillCoverage(actions, lastUserMessage);
    if (!mounted) return;
    setState(() {
      _actionLoading = false;
      _pendingActions
        ..clear()
        ..addAll(actions);
    });
  }

  List<ChatSuggestedAction> _ensureBillCoverage(
    List<ChatSuggestedAction> actions,
    String? userText,
  ) {
    if (userText == null) return actions;
    final normalized = userText.toLowerCase();
    if (!_mentionsBill(normalized)) return actions;

    final result = List<ChatSuggestedAction>.from(actions);
    final hasGoal = result.any((a) => a.type == ChatActionType.goal);
    final hasAlert = result.any((a) => a.type == ChatActionType.alert);
    final extractedAmount = _extractAmountFromText(userText);
    final existingAmount = _firstAmount(result);
    final existingDueDate = _firstDueDate(result);
    final existingDueInDays = _firstDueInDays(result);

    if (!hasGoal) {
      result.add(
        ChatSuggestedAction(
          type: ChatActionType.goal,
          title: 'Upcoming bill',
          description: userText,
          amount: extractedAmount ?? existingAmount,
        ),
      );
    }

    if (!hasAlert) {
      result.add(
        ChatSuggestedAction(
          type: ChatActionType.alert,
          title: 'Upcoming bill',
          description: userText,
          amount: extractedAmount ?? existingAmount,
          dueDate: existingDueDate,
          dueInDays: existingDueInDays,
        ),
      );
    }

    return result;
  }

  List<ChatSuggestedAction> _filterActionsForUtterance(
    List<ChatSuggestedAction> actions,
    String? userText,
  ) {
    if (actions.isEmpty) return actions;
    final normalized = userText?.toLowerCase() ?? '';
    final wantsAlert = _mentionsAlert(normalized) || _mentionsBill(normalized);
    final wantsGoal = _mentionsGoal(normalized) || _mentionsBill(normalized);
    return actions.where((action) {
      if (action.type == ChatActionType.alert && !wantsAlert) return false;
      if (action.type == ChatActionType.goal && !wantsGoal) return false;
      return true;
    }).toList();
  }
  /// Clears history after a confirmation dialog and reseeds the greeting.
  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This will remove all messages for this chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirm != true) return;

    // wipe persisted history
    await _store.clear();

    // reset UI to the default greeting
    _controller.clear();
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage.assistant('Kia ora! How can I help with your budget today?'));
      _pendingActions.clear();
      _actionLoading = false;
    });

    // persist the single greeting message
    await _store.saveMessages(_messages);
    _scrollToBottom(); // scroll to top/bottom as needed after reset.

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat cleared')),
      );
    }
  }

  /// Converts raw exceptions into user-friendly hints (e.g., missing API key).
  String _prettyErr(Object e) {
    final s = e.toString();
    if (s.contains('No API key') || s.contains('401')) {
      return "\n\nTip: Add your API key in Settings.";
    }
    // Surface the underlying error (trimmed) so users know what to fix.
    final trimmed = s.length > 180 ? '${s.substring(0, 177)}…' : s;
    return '\n\nError: $trimmed';
  }

  String _injectReferralLinks(String text) {
    if (_referralLinks.isEmpty) return text;
    var output = text;
    _referralLinks.forEach((name, url) {
      final pattern =
          RegExp(r'\b' + RegExp.escape(name) + r'\b', caseSensitive: false);
      output = output.replaceFirstMapped(pattern, (match) {
        final start = match.start;
        if (start > 0 && match.input[start - 1] == '[') {
          return match.group(0)!; // already linked via markdown
        }
        final display = match.group(0)!;
        return '[$display]($url)';
      });
    });
    return output;
  }

  void _dismissAction(ChatSuggestedAction action) {
    setState(() {
      _pendingActions.remove(action);
    });
  }

  void _setSavingAction(bool value) {
    if (!mounted) return;
    setState(() => _savingAction = value);
  }

  Future<void> _handleActionTap(ChatSuggestedAction action) async {
    if (_savingAction) return;
    _ActionOutcome? outcome;
    switch (action.type) {
      case ChatActionType.goal:
        outcome = await _showGoalSheet(action);
        break;
      case ChatActionType.budget:
        outcome = await _showBudgetSheet(action);
        break;
      case ChatActionType.alert:
        outcome = await _showAlertSheet(action);
        break;
    }
    if (outcome == null) return;
    _dismissAction(action);
    _showSnack(outcome.snackText);
    await _appendConfirmationMessage(outcome.chatText);
  }

  Future<_ActionOutcome?> _showGoalSheet(ChatSuggestedAction action) async {
    if (!mounted) return null;
    return showModalBottomSheet<_ActionOutcome>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: _GoalSheet(
          action: action,
          onSavingChanged: _setSavingAction,
        ),
      ),
    );
  }

  Future<_ActionOutcome?> _showBudgetSheet(ChatSuggestedAction action) async {
    final categoryNames = await _loadCategoryNames();
    if (!mounted) return null;
    return showModalBottomSheet<_ActionOutcome>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: _BudgetSheet(
          action: action,
          categories: categoryNames,
          onSavingChanged: _setSavingAction,
        ),
      ),
    );
  }

  Future<_ActionOutcome?> _showAlertSheet(ChatSuggestedAction action) async {
    if (!mounted) return null;
    final initialDue = action.dueDate ??
        (action.dueInDays != null
            ? DateTime.now().add(Duration(days: action.dueInDays!.clamp(0, 365)))
            : null);
    final form = await showManualAlertSheet(
      context: context,
      initialTitle: action.title ?? action.description ?? '',
      initialAmount: action.amount,
      initialDueDate: initialDue,
      initialNote: action.note,
      headerLabel: 'Create alert',
    );
    if (form == null) return null;
    _setSavingAction(true);
    try {
      final alert = AlertModel(
        title: form.title,
        message: form.note?.isNotEmpty == true
            ? form.note
            : 'Due ${_friendlyDate(form.dueDate)}'
                '${form.amount != null ? ' for ${_formatCurrency(form.amount!)}' : ''}',
        icon: '⏰',
        amount: form.amount,
        dueDate: form.dueDate,
      );
      await AlertRepository.insert(alert);
      final chatText = form.amount != null
          ? "I’ll remind you about ${form.title} on ${_friendlyDate(form.dueDate)} for ${_formatCurrency(form.amount!)}."
          : "I’ll remind you about ${form.title} on ${_friendlyDate(form.dueDate)}.";
      return _ActionOutcome(
        snackText: "Alert saved for ${form.title}",
        chatText: chatText,
      );
    } catch (_) {
      if (!mounted) return null;
      _showSnack('Couldn’t save alert. Please try again.');
      return null;
    } finally {
      _setSavingAction(false);
    }
  }

  Future<void> _appendConfirmationMessage(String text) async {
    final msg = ChatMessage.assistant(text);
    _messages.add(msg);
    await _store.saveMessages(_messages);
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<List<String>> _loadCategoryNames() async {
    final rows = await CategoryRepository.getAllOrderedByUsage(limit: 40);
    return rows
        .map((row) => (row['name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Renders chat history, the message composer, and clear/send controls.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // keep your background color
      appBar: AppBar(
        title: const Text("Moni AI"),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_outline),
            onPressed: _sending ? null : _clearChat, // disabled while sending
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scroll, // Added: keep a handle for auto-scroll.
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.role == ChatRole.user;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Bubble(
                    margin: const BubbleEdges.only(top: 10),
                    nip: isUser
                        ? BubbleNip.rightBottom
                        : BubbleNip.leftBottom, // tail position
                    color: isUser ? Colors.blue[200]! : bfmBeige,
                    child: MarkdownBody(
                      data: msg.content,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 4), // spacing between bubbles
            ),
          ),
          if (_pendingActions.isNotEmpty || _actionLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _ActionSuggestionStrip(
                actions: _pendingActions,
                loading: _actionLoading,
                saving: _savingAction,
                onCreate: _handleActionTap,
                onDismiss: _dismissAction,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    // allow Enter to send. TODO: not working
                    onSubmitted: (_) {
                      if (_hasApiKey && !_sending) _sendMessage();
                    },
                    // Hint shows a gentle nudge if no key is present
                    decoration: InputDecoration(
                      hintText: _hasApiKey
                          ? "Type a message..."
                          : "Type a message... (Add API key in Settings)",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: (_hasApiKey && !_sending) ? _sendMessage : null, // Added: guard on API key.
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSheet extends StatefulWidget {
  final ChatSuggestedAction action;
  final ValueChanged<bool> onSavingChanged;

  const _GoalSheet({
    required this.action,
    required this.onSavingChanged,
  });

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _weeklyCtrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.action.title ?? widget.action.categoryName ?? '',
    );
    _amountCtrl = TextEditingController(
      text: _prefillAmount(widget.action.amount),
    );
    _weeklyCtrl = TextEditingController(
      text: _prefillAmount(widget.action.weeklyAmount ?? widget.action.amount),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _weeklyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    final target = _parseCurrency(_amountCtrl.text.trim());
    final weekly = _parseCurrency(_weeklyCtrl.text.trim());
    if (name.isEmpty || target <= 0 || weekly <= 0) {
      setState(() {
        _error = 'Enter a name, target amount, and weekly contribution.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    widget.onSavingChanged(true);
    try {
      await GoalRepository.insert(
        GoalModel(
          name: name,
          amount: target,
          weeklyContribution: weekly,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        _ActionOutcome(
          snackText: "Saved goal '$name'",
          chatText:
              "Locked in a savings goal called $name for ${_formatCurrency(target)} with ${_formatCurrency(weekly)} weekly contributions.",
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn’t save goal. Please try again.';
        });
      }
    } finally {
      widget.onSavingChanged(false);
    }
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
            'Create savings goal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Goal name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target amount',
              prefixText: '\$',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weeklyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weekly contribution',
              prefixText: '\$',
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
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save goal'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetSheet extends StatefulWidget {
  final ChatSuggestedAction action;
  final List<String> categories;
  final ValueChanged<bool> onSavingChanged;

  const _BudgetSheet({
    required this.action,
    required this.categories,
    required this.onSavingChanged,
  });

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initialCategory = widget.action.categoryName ?? widget.action.title ?? '';
    _nameCtrl = TextEditingController(text: initialCategory);
    _amountCtrl = TextEditingController(
      text: _prefillAmount(widget.action.weeklyAmount ?? widget.action.amount),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final category = _nameCtrl.text.trim();
    final limit = _parseCurrency(_amountCtrl.text.trim());
    if (category.isEmpty || limit <= 0) {
      setState(() {
        _error = 'Enter a name and weekly limit.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    widget.onSavingChanged(true);
    try {
      final categoryId = await CategoryRepository.ensureByName(category);
      final budget = BudgetModel(
        categoryId: categoryId,
        label: category,
        weeklyLimit: limit,
        periodStart: _currentMondayIso(),
      );
      await BudgetRepository.insert(budget);
      if (!mounted) return;
      Navigator.of(context).pop(
        _ActionOutcome(
          snackText: 'Budget saved for $category',
          chatText:
              'Set a weekly budget for $category at ${_formatCurrency(limit)} per week.',
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn’t save budget. Please try again.';
        });
      }
    } finally {
      widget.onSavingChanged(false);
    }
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
            'Create weekly budget',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Budget name',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weekly limit',
              prefixText: '\$',
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
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save budget'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionOutcome {
  final String snackText;
  final String chatText;

  const _ActionOutcome({required this.snackText, required this.chatText});
}

class _ActionSuggestionStrip extends StatelessWidget {
  final List<ChatSuggestedAction> actions;
  final bool loading;
  final bool saving;
  final ValueChanged<ChatSuggestedAction> onCreate;
  final ValueChanged<ChatSuggestedAction> onDismiss;

  const _ActionSuggestionStrip({
    required this.actions,
    required this.loading,
    required this.saving,
    required this.onCreate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty && !loading) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        ...actions.map(
          (action) => _ActionCard(
            action: action,
            saving: saving,
            onCreate: onCreate,
            onDismiss: onDismiss,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final ChatSuggestedAction action;
  final bool saving;
  final ValueChanged<ChatSuggestedAction> onCreate;
  final ValueChanged<ChatSuggestedAction> onDismiss;

  const _ActionCard({
    required this.action,
    required this.saving,
    required this.onCreate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = _buildChips(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    action.displayLabel,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close),
                  onPressed: () => onDismiss(action),
                ),
              ],
            ),
            if (action.description != null &&
                action.description!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  action.description!.trim(),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            if (chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: chips,
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: saving ? null : () => onCreate(action),
                child: Text(_ctaLabel(action.type, saving)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChips(BuildContext context) {
    final entries = <String>[];
    if (action.type == ChatActionType.budget &&
        action.categoryName?.isNotEmpty == true) {
      entries.add(action.categoryName!.trim());
    }
    if (action.amount != null &&
        action.amount! > 0 &&
        action.type != ChatActionType.budget) {
      entries.add('Amount ${_formatCurrency(action.amount!)}');
    }
    if (action.weeklyAmount != null && action.weeklyAmount! > 0) {
      entries.add('Weekly ${_formatCurrency(action.weeklyAmount!)}');
    }
    final due = _dueLabelForAction(action);
    if (due != null) entries.add(due);

    return entries
        .map(
          (text) => Chip(
            label: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        )
        .toList();
  }

  String _ctaLabel(ChatActionType type, bool saving) {
    if (saving) return 'Saving...';
    switch (type) {
      case ChatActionType.goal:
        return 'Create goal';
      case ChatActionType.budget:
        return 'Create budget';
      case ChatActionType.alert:
        return 'Create alert';
    }
  }
}

String _formatCurrency(double value) {
  final decimals = value.abs() >= 100 ? 0 : 2;
  return '\$${value.toStringAsFixed(decimals)}';
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

String? _dueLabelForAction(ChatSuggestedAction action) {
  if (action.dueDate != null) {
    return 'Due ${_friendlyDate(action.dueDate!)}';
  }
  final days = action.dueInDays;
  if (days == null) return null;
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days < 0) return null;
  return 'Due in $days days';
}

double _parseCurrency(String raw) {
  if (raw.trim().isEmpty) return 0;
  final sanitized = raw.replaceAll(RegExp(r'[^0-9\.\-]'), '');
  final value = double.tryParse(sanitized);
  if (value == null || value.isNaN || value.isInfinite) return 0;
  return value;
}

String _prefillAmount(double? value) {
  if (value == null || value <= 0) return '';
  final decimals = value >= 100 ? 0 : 2;
  return value.toStringAsFixed(decimals);
}

String _currentMondayIso() {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final month = monday.month.toString().padLeft(2, '0');
  final day = monday.day.toString().padLeft(2, '0');
  return '${monday.year}-$month-$day';
}

bool _mentionsBill(String text) {
  final pattern =
      RegExp(r'\b(bill|invoice|repair|mechanic|dentist|fine|payment|rent|warrant|wof|rego)\b');
  return pattern.hasMatch(text);
}

bool _mentionsAlert(String text) {
  final pattern =
      RegExp(r'\b(alert|remind|reminder|notify|notification|remember)\b');
  return pattern.hasMatch(text);
}

bool _mentionsGoal(String text) {
  final pattern =
      RegExp(r'\b(goal|saving|save up|savings)\b');
  return pattern.hasMatch(text);
}

double? _extractAmountFromText(String text) {
  final cleaned = text.replaceAll(',', '');
  final match = RegExp(r'\$?\s*([0-9]+(?:\.[0-9]{1,2})?)').firstMatch(cleaned);
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null || value <= 0) return null;
  return value;
}

double? _firstAmount(List<ChatSuggestedAction> actions) {
  for (final action in actions) {
    if (action.amount != null && action.amount! > 0) {
      return action.amount;
    }
  }
  return null;
}

DateTime? _firstDueDate(List<ChatSuggestedAction> actions) {
  for (final action in actions) {
    if (action.dueDate != null) {
      return action.dueDate;
    }
  }
  return null;
}

int? _firstDueInDays(List<ChatSuggestedAction> actions) {
  for (final action in actions) {
    if (action.dueInDays != null) {
      return action.dueInDays;
    }
  }
  return null;
}
