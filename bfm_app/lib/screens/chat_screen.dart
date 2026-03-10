import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bfm_app/theme/buxly_theme.dart';

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
import 'package:bfm_app/services/alert_notification_service.dart';
import 'package:bfm_app/services/chat_storage.dart';
import 'package:bfm_app/services/context_builder.dart';
import 'package:bfm_app/services/manual_budget_store.dart';
import 'package:bfm_app/providers/api_providers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bfm_app/widgets/manual_alert_sheet.dart';
import 'package:bfm_app/services/chat_action_parser.dart' as parser;
import 'package:bfm_app/utils/format_helpers.dart';

/// Example questions that scroll through to show chatbot capabilities.
const List<String> _exampleQuestions = [
  '"What\'s my left to spend?"',
  '"Help me save for a holiday"',
  '"Set a new budget"',
  '"create a reminder"',
  '"How am I tracking this week?"',
  '"Can I afford takeaways tonight?"',
  '"Create a savings goal"',
  '"Can you help me tighten up my budgets?"',
];

/// Top-level chat screen that wraps the Moni messenger UI.
class ChatScreen extends StatefulWidget {
  /// When true, the screen is embedded in MainShell.
  final bool embedded;

  const ChatScreen({super.key, this.embedded = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Handles conversation state, persistence, and network calls via the backend.
class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final List<ChatMessage> _allMessages = [];

  final TextEditingController _controller = TextEditingController();

  final ScrollController _scroll = ScrollController();

  late final ChatStorage _store;

  // UI guards
  bool _sending = false;
  Map<String, String> _referralLinks = {};
  bool _actionLoading = false;
  bool _savingAction = false;
  final List<ChatSuggestedAction> _pendingActions = [];

  // Hint animation state
  int _hintIndex = 0;
  late AnimationController _hintFadeController;
  late Animation<double> _hintFadeAnimation;
  Timer? _hintCycleTimer;

  static const int kContextWindowTurns = 12;
  static const int _kMaxUiMessages = 100;

  @override
  void initState() {
    super.initState();
    _store = ChatStorage();
    _initHintAnimation();
    _bootstrap();
  }

  void _initHintAnimation() {
    _hintFadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _hintFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hintFadeController, curve: Curves.easeInOut),
    );
    // Start with fade in
    _hintFadeController.forward();
    // Start cycling through hints
    _hintCycleTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _cycleHint();
    });
  }

  void _cycleHint() {
    // Fade out
    _hintFadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _hintIndex = (_hintIndex + 1) % _exampleQuestions.length;
      });
      // Fade in
      _hintFadeController.forward();
    });
  }

  /// Disposes controllers to avoid leaks.
  @override
  void dispose() {
    _hintCycleTimer?.cancel();
    _hintFadeController.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final persistedAll = await _store.loadAllMessages();
    if (persistedAll.isNotEmpty) {
      _allMessages.addAll(persistedAll);
      setState(() {
        final start = _allMessages.length > _kMaxUiMessages
            ? _allMessages.length - _kMaxUiMessages
            : 0;
        _messages.addAll(_allMessages.sublist(start));
      });
      _scrollToBottom();
    } else {
      final greeting = ChatMessage.assistant(
        "Kia ora! How can I help with your budget today?",
      );
      _messages.add(greeting);
      _allMessages.add(greeting);
      await _store.saveMessages(_allMessages);
      setState(() {});
      _scrollToBottom();
    }

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
    final start = _allMessages.length > kContextWindowTurns
        ? _allMessages.length - kContextWindowTurns
        : 0;
    return _allMessages
        .sublist(start)
        .map((m) => m.toOpenAiRoleContent())
        .toList();
  }

  /// Sends a message through the Moni backend /messages endpoint.
  Future<String> _sendViaBackend(String text) async {
    final container = ProviderScope.containerOf(context);
    final api = container.read(messagesApiProvider);

    final userContext = await ContextBuilder.build(
      recentTurns: _buildRecentTurns(),
    );

    final response = await api.sendMessage(text, userContext: userContext);
    final extracted = _extractBackendMessage(response);
    return extracted.isNotEmpty
        ? extracted
        : 'Kia ora - I am here. How can I help today?';
  }

  String _extractBackendMessage(Map<String, dynamic> response) =>
      parser.extractBackendMessage(response);

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _pendingActions.clear();
      _actionLoading = false;
    });

    // Append the user message to the UI and persist
    final userMsg = ChatMessage.user(text);
    final lastUserText = userMsg.content;
    _messages.add(userMsg);
    _allMessages.add(userMsg);
    _controller.clear();
    await _store.saveMessages(_allMessages);
    setState(() {});
    _scrollToBottom(); // keep view pinned to newest message.

    try {
      final replyText = await _sendViaBackend(text);
      final replyWithLinks = _injectReferralLinks(replyText);

      // Append assistant response and persist
      final botMsg = ChatMessage.assistant(replyWithLinks);
      _messages.add(botMsg);
      _allMessages.add(botMsg);
      await _store.saveMessages(_allMessages);
      setState(() {});
      _scrollToBottom(); // scroll to bottom when bot replies.
      
      // Only run action detection if user is actually asking to CREATE something
      // Don't suggest actions for simple questions like "what's my left to spend"
      if (_shouldDetectActions(lastUserText, replyWithLinks)) {
        _detectActions(
          lastUserMessage: lastUserText,
          lastAssistantMessage: replyWithLinks,
        );
      }
    } catch (e) {
      // Friendly error bubble (keeps your style)
      _messages.add(ChatMessage.assistant(
        "Sorry, I couldn’t reply just now. ${_prettyErr(e)}",
      ));
      _allMessages.add(_messages.last);
      await _store.saveMessages(_allMessages);
      setState(() {});
      _scrollToBottom(); // maintain scroll position.
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  bool _shouldDetectActions(String userMessage, String assistantReply) =>
      parser.shouldDetectActions(userMessage, assistantReply);
  
  /// Detects actionable items from the assistant's reply using pattern matching.
  void _detectActions({
    String? lastUserMessage,
    String? lastAssistantMessage,
  }) {
    setState(() => _actionLoading = true);

    try {
      final actionContext = _buildActionContextText(
        lastUserMessage: lastUserMessage,
      );

      var actions = lastAssistantMessage != null
          ? parser.extractActionsFromAssistantText(lastAssistantMessage)
          : <ChatSuggestedAction>[];

      actions = parser.enhanceActions(
        actions,
        userText: lastUserMessage,
        assistantText: lastAssistantMessage,
        actionContext: actionContext,
      );

      actions = parser.normalizeActionTitles(actions, lastUserMessage);
      actions = parser.prefillMissingActionData(
        actions,
        userText: actionContext,
        assistantText: lastAssistantMessage,
      );

      if (!mounted) return;
      setState(() {
        _actionLoading = false;
        _pendingActions
          ..clear()
          ..addAll(actions);
      });
    } catch (e) {
      debugPrint('Action detection error: $e');
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  // _enhanceActions, _prefillMissingActionData, and extraction methods
  // moved to services/chat_action_parser.dart

  String _buildActionContextText({String? lastUserMessage}) {
    if (_allMessages.isEmpty) return lastUserMessage ?? '';
    final buffer = StringBuffer();
    var added = 0;
    for (var i = _allMessages.length - 1; i >= 0; i--) {
      final msg = _allMessages[i];
      if (msg.role != ChatRole.user) continue;
      final text = msg.content.trim();
      if (text.isEmpty) continue;
      buffer.write(text);
      buffer.write(' ');
      added++;
      if (added >= 4) break;
    }
    final combined = buffer.toString().trim();
    if (combined.isNotEmpty) return combined;
    return lastUserMessage ?? '';
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
      _allMessages
        ..clear()
        ..add(_messages.first);
      _pendingActions.clear();
      _actionLoading = false;
    });

    // persist the single greeting message
    await _store.saveMessages(_allMessages);
    _scrollToBottom(); // scroll to top/bottom as needed after reset.

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat cleared')),
      );
    }
  }

  String _prettyErr(Object e) {
    final s = e.toString();
    if (s.contains('401') || s.contains('403')) {
      return "\n\nPlease sign in again.";
    }
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

  void _dismissLinkedActions(
    ChatSuggestedAction action, {
    ChatSuggestedAction? linkedAlert,
  }) {
    setState(() {
      _pendingActions.remove(action);
      if (linkedAlert != null) {
        _pendingActions.remove(linkedAlert);
      }
    });
  }

  void _setSavingAction(bool value) {
    if (!mounted) return;
    setState(() => _savingAction = value);
  }

  Future<void> _handleActionTap(
    ChatSuggestedAction action, {
    ChatSuggestedAction? linkedAlert,
  }) async {
    if (_savingAction) return;
    _ActionOutcome? outcome;
    switch (action.type) {
      case ChatActionType.goal:
        outcome = await _showGoalSheet(action, alertSuggestion: linkedAlert);
        break;
      case ChatActionType.budget:
        outcome = await _showBudgetSheet(action);
        break;
      case ChatActionType.alert:
        outcome = await _showAlertSheet(action);
        break;
    }
    if (outcome == null) return;
    _dismissLinkedActions(action, linkedAlert: linkedAlert);
    _showSnack(outcome.snackText);
    await _appendConfirmationMessage(outcome.chatText);
  }

  Future<_ActionOutcome?> _showGoalSheet(
    ChatSuggestedAction action, {
    ChatSuggestedAction? alertSuggestion,
  }) async {
    if (!mounted) return null;
    final candidateName = (action.title ?? action.categoryName)?.trim();
    final hasName = candidateName != null &&
        candidateName.isNotEmpty &&
        !parser.isGenericGoalName(candidateName);
    String? defaultName;
    if (!hasName) {
      try {
        defaultName = await parser.nextGoalName();
      } catch (_) {
        defaultName = 'Goal 1';
      }
    }
    if (!mounted) return null;
    return showDialog<_ActionOutcome>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _GoalSheet(
            action: action,
            onSavingChanged: _setSavingAction,
            alertSuggestion: alertSuggestion,
            initialName: defaultName,
            selectNameOnOpen: !hasName,
          ),
        ),
      ),
    );
  }

  Future<_ActionOutcome?> _showBudgetSheet(ChatSuggestedAction action) async {
    final categoryNames = await _loadCategoryNames();
    if (!mounted) return null;
    final candidateName = (action.categoryName ?? action.title)?.trim();
    final hasName = candidateName != null &&
        candidateName.isNotEmpty &&
        !parser.isGenericBudgetName(candidateName);
    String? defaultName;
    if (!hasName) {
      try {
        defaultName = await parser.nextBudgetName();
      } catch (_) {
        defaultName = 'Budget 1';
      }
    }
    if (!mounted) return null;
    return showDialog<_ActionOutcome>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _BudgetSheet(
            action: action,
            categories: categoryNames,
            onSavingChanged: _setSavingAction,
            initialName: defaultName,
            selectNameOnOpen: !hasName,
          ),
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
    final candidateTitle = action.title?.trim();
    final hasTitle = candidateTitle != null &&
        candidateTitle.isNotEmpty &&
        !parser.isGenericAlertName(candidateTitle);
    String? defaultTitle;
    if (!hasTitle) {
      try {
        defaultTitle = await parser.nextAlertName();
      } catch (_) {
        defaultTitle = 'Alert 1';
      }
    }
    final form = await showManualAlertDialog(
      context: context,
      initialTitle: hasTitle ? action.title : defaultTitle,
      initialAmount: action.amount,
      initialDueDate: initialDue,
      initialNote: action.note,
      headerLabel: 'Create alert',
      selectTitleOnOpen: !hasTitle,
    );
    if (form == null) return null;
    _setSavingAction(true);
    try {
      final alert = AlertModel(
        title: form.title,
        message: form.note?.isNotEmpty == true
            ? form.note
            : 'Due ${friendlyDate(form.dueDate)}'
                '${form.amount != null ? ' for ${formatCurrency(form.amount!)}' : ''}',
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
        // Notify user that notification might not work but alert is saved
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alert saved but notification scheduling failed'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      final chatText = form.amount != null
          ? "I’ll remind you about ${form.title} on ${friendlyDate(form.dueDate)} for ${formatCurrency(form.amount!)}."
          : "I’ll remind you about ${form.title} on ${friendlyDate(form.dueDate)}.";
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
    _allMessages.add(msg);
    await _store.saveMessages(_allMessages);
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

  /// Sends a quick suggestion chip message.
  void _sendQuickMessage(String text) {
    _controller.text = text;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final lastAssistantIndex =
        _messages.lastIndexWhere((msg) => msg.role == ChatRole.assistant);
    final linkedAlert = parser.firstActionOfType(
      ChatActionType.alert,
      _pendingActions,
    );
    final hasGoal = _pendingActions.any((action) => action.type == ChatActionType.goal);
    final inlineActions = (hasGoal && linkedAlert != null)
        ? _pendingActions.where((action) => action.type != ChatActionType.alert).toList()
        : _pendingActions;
    return Scaffold(
      backgroundColor: BuxlyColors.offWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: BuxlyColors.white,
                boxShadow: [
                  BoxShadow(
                    color: BuxlyColors.darkText.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  BuxlyIconContainer(
                    icon: Icons.smart_toy_rounded,
                    color: BuxlyColors.teal,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Buxly AI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: BuxlyColors.darkText,
                            fontFamily: BuxlyTheme.fontFamily,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: BuxlyColors.limeGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Online · Your financial coach',
                              style: TextStyle(
                                fontSize: 12,
                                color: BuxlyColors.midGrey,
                                fontFamily: BuxlyTheme.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear chat',
                    icon: const Icon(Icons.delete_outline,
                        color: BuxlyColors.midGrey),
                    onPressed: _sending ? null : _clearChat,
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg.role == ChatRole.user;
                  final showInlineActions = !isUser &&
                      index == lastAssistantIndex &&
                      (inlineActions.isNotEmpty || _actionLoading);

                  return Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!isUser)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              BuxlyIconContainer(
                                icon: Icons.smart_toy_rounded,
                                color: BuxlyColors.teal,
                                size: 24,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Buxly',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: BuxlyColors.midGrey,
                                  fontFamily: BuxlyTheme.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? BuxlyColors.teal
                                : BuxlyColors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isUser ? 18 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: BuxlyColors.darkText.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: MarkdownBody(
                            data: msg.content,
                            onTapLink: (text, href, title) {
                              if (href == null) return;
                              final uri = Uri.tryParse(href);
                              if (uri != null) {
                                launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            styleSheet: MarkdownStyleSheet.fromTheme(
                                    Theme.of(context))
                                .copyWith(
                              p: TextStyle(
                                fontSize: 14,
                                color: isUser
                                    ? BuxlyColors.white
                                    : BuxlyColors.darkText,
                                fontFamily: BuxlyTheme.fontFamily,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatTime(msg.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: BuxlyColors.midGrey,
                            fontFamily: BuxlyTheme.fontFamily,
                          ),
                        ),
                      ),
                      if (showInlineActions)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _InlineActionStrip(
                            actions: inlineActions,
                            loading: _actionLoading,
                            saving: _savingAction,
                            onCreate: _handleActionTap,
                            onDismiss: _dismissLinkedActions,
                            linkedAlert: linkedAlert,
                          ),
                        ),
                    ],
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
              ),
            ),

            // Suggestion chips
            if (!_sending && _messages.length <= 3)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    'Show my budget',
                    'Spending insights',
                    'Set a goal',
                    'Create a reminder',
                  ]
                      .map((text) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _sendQuickMessage(text),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: BuxlyColors.white,
                                  borderRadius: BorderRadius.circular(
                                      BuxlyRadius.pill),
                                  border: Border.all(
                                      color: BuxlyColors.teal.withOpacity(0.4)),
                                ),
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: BuxlyColors.teal,
                                    fontFamily: BuxlyTheme.fontFamily,
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: BuxlyColors.white,
                boxShadow: [
                  BoxShadow(
                    color: BuxlyColors.darkText.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _hintFadeAnimation,
                      builder: (context, child) {
                        final hintText = _exampleQuestions[_hintIndex]
                            .replaceAll('"', '');
                        return TextField(
                          controller: _controller,
                          onSubmitted: (_) {
                            if (!_sending) _sendMessage();
                          },
                          style: const TextStyle(
                            fontFamily: BuxlyTheme.fontFamily,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Ask Buxly anything...',
                            hintStyle: TextStyle(
                              color: BuxlyColors.midGrey.withOpacity(
                                _hintFadeAnimation.value,
                              ),
                              fontFamily: BuxlyTheme.fontFamily,
                            ),
                            filled: true,
                            fillColor: BuxlyColors.offWhite,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(BuxlyRadius.pill),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(BuxlyRadius.pill),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(BuxlyRadius.pill),
                              borderSide: const BorderSide(
                                color: BuxlyColors.teal,
                                width: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: !_sending
                          ? BuxlyColors.teal
                          : BuxlyColors.disabled,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: BuxlyColors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: BuxlyColors.white,
                              size: 20,
                            ),
                      onPressed: !_sending ? _sendMessage : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final h = timestamp.hour;
    final m = timestamp.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }
}

class _GoalSheet extends StatefulWidget {
  final ChatSuggestedAction action;
  final ValueChanged<bool> onSavingChanged;
  final ChatSuggestedAction? alertSuggestion;
  final String? initialName;
  final bool selectNameOnOpen;

  const _GoalSheet({
    required this.action,
    required this.onSavingChanged,
    this.alertSuggestion,
    this.initialName,
    this.selectNameOnOpen = false,
  });

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _weeklyCtrl;
  DateTime? _alertDueDate;
  String? _error;
  bool _saving = false;
  bool _createAlert = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text:
          widget.initialName ?? widget.action.title ?? widget.action.categoryName ?? '',
    );
    if (widget.selectNameOnOpen && _nameCtrl.text.isNotEmpty) {
      _nameCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _nameCtrl.text.length);
    }
    _amountCtrl = TextEditingController(
      text: parser.prefillAmount(widget.action.amount),
    );
    // Don't fall back to amount for weekly - that's completely wrong!
    // If no weekly amount was extracted, leave empty for user to fill in
    _weeklyCtrl = TextEditingController(
      text: parser.prefillAmount(widget.action.weeklyAmount),
    );
    _createAlert = widget.alertSuggestion != null;
    _alertDueDate = _initialAlertDate(widget.alertSuggestion);
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
    final target = parseCurrency(_amountCtrl.text.trim());
    final weekly = parseCurrency(_weeklyCtrl.text.trim());
    if (name.isEmpty || target <= 0 || weekly <= 0) {
      setState(() {
        _error = 'Enter a name, target amount, and weekly contribution.';
      });
      return;
    }
    if (_createAlert && _alertDueDate == null) {
      setState(() {
        _error = 'Choose a due date for the alert.';
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
      if (_createAlert) {
        final alertScheduled = await _createGoalAlert(
          name,
          targetAmount: target,
          dueDate: _alertDueDate!,
          suggestion: widget.alertSuggestion,
        );
        if (!alertScheduled && mounted) {
          // Alert saved but notification may not fire
          debugPrint('Alert for goal "$name" saved but notification scheduling failed');
        }
      }
      if (!mounted) return;
      final alertSuffix = _createAlert
          ? ' and an alert for ${friendlyDate(_alertDueDate!)}.'
          : '.';
      Navigator.of(context).pop(
        _ActionOutcome(
          snackText: "Saved goal '$name'",
          chatText:
              "Locked in a savings goal called $name for ${formatCurrency(target)} with ${formatCurrency(weekly)} weekly contributions$alertSuffix",
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
            autofocus: widget.selectNameOnOpen,
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
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Create alert'),
            value: _createAlert,
            onChanged: (value) {
              setState(() {
                _createAlert = value;
                if (value && _alertDueDate == null) {
                  _alertDueDate = DateTime.now().add(const Duration(days: 7));
                }
              });
            },
          ),
          if (_createAlert)
            GestureDetector(
              onTap: _pickAlertDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Alert date',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _alertDueDate == null
                      ? 'Tap to select'
                      : friendlyDate(_alertDueDate!),
                ),
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

  DateTime? _initialAlertDate(ChatSuggestedAction? suggestion) {
    if (suggestion == null) return null;
    if (suggestion.dueDate != null) return suggestion.dueDate;
    if (suggestion.dueInDays != null) {
      return DateTime.now()
          .add(Duration(days: suggestion.dueInDays!.clamp(0, 365)));
    }
    // Calculate from goal amount and weekly contribution if available
    final target = widget.action.amount;
    final weekly = widget.action.weeklyAmount;
    if (target != null && weekly != null && weekly > 0) {
      final weeks = (target / weekly).ceil();
      return DateTime.now().add(Duration(days: weeks * 7));
    }
    // Default to 4 weeks if no calculation possible
    return DateTime.now().add(const Duration(days: 28));
  }

  Future<void> _pickAlertDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _alertDueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _alertDueDate = picked);
    }
  }

  Future<bool> _createGoalAlert(
    String goalName, {
    required double targetAmount,
    required DateTime dueDate,
    ChatSuggestedAction? suggestion,
  }) async {
    final amount = suggestion?.amount ?? targetAmount;
    final alert = AlertModel(
      title: goalName,
      message: 'Due ${friendlyDate(dueDate)}'
          '${amount > 0 ? ' for ${formatCurrency(amount)}' : ''}',
      icon: '⏰',
      amount: amount > 0 ? amount : null,
      dueDate: dueDate,
    );
    final id = await AlertRepository.insert(alert);
    try {
      await AlertNotificationService.instance.schedule(alert.copyWith(id: id));
      return true;
    } catch (err) {
      debugPrint('Alert scheduling failed: $err');
      return false;
    }
  }
}

class _BudgetSheet extends StatefulWidget {
  final ChatSuggestedAction action;
  final List<String> categories;
  final ValueChanged<bool> onSavingChanged;
  final String? initialName;
  final bool selectNameOnOpen;

  const _BudgetSheet({
    required this.action,
    required this.categories,
    required this.onSavingChanged,
    this.initialName,
    this.selectNameOnOpen = false,
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
    final initialCategory =
        widget.initialName ?? widget.action.categoryName ?? widget.action.title ?? '';
    _nameCtrl = TextEditingController(text: initialCategory);
    if (widget.selectNameOnOpen && _nameCtrl.text.isNotEmpty) {
      _nameCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _nameCtrl.text.length);
    }
    _amountCtrl = TextEditingController(
      text: parser.prefillAmount(widget.action.weeklyAmount ?? widget.action.amount),
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
    final limit = parseCurrency(_amountCtrl.text.trim());
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
      // Save to ManualBudgetStore (used by budget screen's manual section)
      await ManualBudgetStore.add(ManualBudget(
        name: category,
        weeklyLimit: limit,
        isSelected: true,
      ));
      
      // Also save to database for budget tracking
      final budget = BudgetModel(
        categoryId: null, // Manual budgets don't have a category ID
        label: category,
        weeklyLimit: limit,
        periodStart: currentMondayIso(),
      );
      await BudgetRepository.insert(budget);
      if (!mounted) return;
      Navigator.of(context).pop(
        _ActionOutcome(
          snackText: 'Budget saved for $category',
          chatText:
              'Set a weekly budget for $category at ${formatCurrency(limit)} per week.',
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
            autofocus: widget.selectNameOnOpen,
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

typedef ActionTapHandler = void Function(
  ChatSuggestedAction action, {
  ChatSuggestedAction? linkedAlert,
});

class _InlineActionStrip extends StatelessWidget {
  final List<ChatSuggestedAction> actions;
  final bool loading;
  final bool saving;
  final ActionTapHandler onCreate;
  final void Function(ChatSuggestedAction action,
      {ChatSuggestedAction? linkedAlert}) onDismiss;
  final ChatSuggestedAction? linkedAlert;

  const _InlineActionStrip({
    required this.actions,
    required this.loading,
    required this.saving,
    required this.onCreate,
    required this.onDismiss,
    this.linkedAlert,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty && !loading) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: actions
              .map(
                (action) => _InlineActionBubble(
                  action: action,
                  saving: saving,
                  onCreate: onCreate,
                  onDismiss: onDismiss,
                  linkedAlert: linkedAlert,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _InlineActionBubble extends StatelessWidget {
  final ChatSuggestedAction action;
  final bool saving;
  final ActionTapHandler onCreate;
  final void Function(ChatSuggestedAction action,
      {ChatSuggestedAction? linkedAlert}) onDismiss;
  final ChatSuggestedAction? linkedAlert;

  const _InlineActionBubble({
    required this.action,
    required this.saving,
    required this.onCreate,
    required this.onDismiss,
    this.linkedAlert,
  });

  @override
  Widget build(BuildContext context) {
    final label = parser.inlineActionLabel(action);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(BuxlyRadius.pill),
        onTap: saving
            ? null
            : () => onCreate(
                  action,
                  linkedAlert: _linkedAlertFor(action),
                ),
        onLongPress: saving
            ? null
            : () => onDismiss(
                  action,
                  linkedAlert: _linkedAlertFor(action),
                ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: BuxlyColors.teal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(BuxlyRadius.pill),
            border: Border.all(color: BuxlyColors.teal.withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BuxlyColors.teal,
              fontFamily: BuxlyTheme.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  ChatSuggestedAction? _linkedAlertFor(ChatSuggestedAction action) {
    if (action.type != ChatActionType.goal) return null;
    return linkedAlert;
  }
}

