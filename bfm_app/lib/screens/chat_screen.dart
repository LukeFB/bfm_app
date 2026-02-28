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
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:bfm_app/services/alert_notification_service.dart';
import 'package:bfm_app/services/chat_constants.dart';
import 'package:bfm_app/services/chat_storage.dart';
import 'package:bfm_app/services/manual_budget_store.dart';
import 'package:bfm_app/providers/api_providers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:bfm_app/widgets/manual_alert_sheet.dart';

/// Whether the chat uses the local OpenAI path or the Moni backend.
enum ChatMode { local, backend }

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

/// Handles conversation state, persistence, and network calls.
///
/// Supports two modes:
/// - **local**: Direct OpenAI calls via [AiClient] (existing, needs API key).
/// - **backend**: Proxied via Moni backend [MessagesApi] (needs backend auth).
class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  ChatMode _chatMode = ChatMode.local;
  // Replaced _Message with ChatMessage to integrate with storage + AI.
  final List<ChatMessage> _messages = [];
  final List<ChatMessage> _allMessages = [];

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

  // Hint animation state
  int _hintIndex = 0;
  late AnimationController _hintFadeController;
  late Animation<double> _hintFadeAnimation;
  Timer? _hintCycleTimer;

  // How many most-recent turns to send with each request
  static const int kContextWindowTurns = kChatContextWindowTurns;
  static const int _kMaxUiMessages = 100;

  /// Sets up the AI + storage services and loads history.
  @override
  void initState() {
    super.initState();
    _ai = AiClient(); // pulls API key internally from ApiKeyStore
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

  /// Loads persisted messages, seeds the greeting when empty, and checks if an
  /// API key exists so the UI can hint accordingly.
  Future<void> _bootstrap() async {
    // Load persisted messages (if any)
    final persistedAll = await _store.loadAllMessages();
    if (persistedAll.isNotEmpty) {
      _allMessages.addAll(persistedAll);
      setState(() {
        final start = _allMessages.length > _kMaxUiMessages
            ? _allMessages.length - _kMaxUiMessages
            : 0;
        _messages.addAll(_allMessages.sublist(start));
      });
      // ensure the list is scrolled to bottom after loading history.
      _scrollToBottom();
    } else {
      // Seed welcome greeting
      final greeting = ChatMessage.assistant(
        "Kia ora! How can I help with your budget today?",
      );
      _messages.add(greeting);
      _allMessages.add(greeting);
      await _store.saveMessages(_allMessages);
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
    // Access ProviderScope via context; ChatScreen is inside ProviderScope.
    final container = ProviderScope.containerOf(context);
    final api = container.read(messagesApiProvider);
    final response = await api.sendMessage(text);
    final content = response['message'] ??
        response['content'] ??
        response['response'] ??
        response['data'] ??
        response['raw'] ??
        '';
    return content.toString().trim().isNotEmpty
        ? content.toString().trim()
        : 'Kia ora - I am here. How can I help today?';
  }

  /// Pushes the user message, sends it through AiClient, handles retries, and
  /// appends the assistant response (or an error bubble) while persisting both.
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
      late final String replyText;
      if (_chatMode == ChatMode.backend) {
        replyText = await _sendViaBackend(text);
      } else {
        final recent = _buildRecentTurns();
        replyText = await _ai.complete(recent);
      }
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
        unawaited(_detectActions(
          _buildRecentTurns(),
          lastUserMessage: lastUserText,
          lastAssistantMessage: replyWithLinks,
        ));
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

  /// Only run action detection when the AI actually suggests creating something.
  /// The AI outputs structured details like "Name:", "Target:", "Limit:" when it
  /// wants to create an action - we just look for those patterns.
  bool _shouldDetectActions(String userMessage, String assistantReply) {
    // Strip markdown bold markers and lowercase for matching
    final cleaned = assistantReply.replaceAll('**', '').toLowerCase();
    
    // AI outputs structured details when suggesting actions:
    // Goals: Name + Target + Weekly
    // Budgets: Name + Limit
    // Alerts: Name/Title + Due/Amount
    return cleaned.contains('name:') ||
        cleaned.contains('target:') ||
        cleaned.contains('weekly:') ||
        cleaned.contains('limit:') ||
        cleaned.contains('amount:') ||
        cleaned.contains('due:');
  }
  
  /// Detects actionable items from the conversation.
  /// 
  /// Simplified pipeline to avoid duplicate processing bugs:
  /// 1. Extract actions from AI
  /// 2. Apply single-pass enhancements
  /// 3. Filter and normalize
  Future<void> _detectActions(
    List<Map<String, String>> turns, {
    String? lastUserMessage,
    String? lastAssistantMessage,
  }) async {
    if (!_hasApiKey) return;
    setState(() => _actionLoading = true);
    
    try {
      final actionContext = _buildActionContextText(
        lastUserMessage: lastUserMessage,
      );
      
      // Step 1: Get base actions from AI
      var actions = await _actionExtractor.identifyActions(
        turns,
        assistantReply: lastAssistantMessage,
      );
      
      // Step 2: Fallback extraction if AI extractor returned nothing but assistant suggested an action
      if (actions.isEmpty && lastAssistantMessage != null) {
        final fallbackActions = _extractActionsFromAssistantText(lastAssistantMessage);
        if (fallbackActions.isNotEmpty) {
          debugPrint('Action extractor returned empty, using fallback extraction');
          actions = fallbackActions;
        }
      }
      
      // Step 3: Single-pass enhancement (removed duplicate calls)
      actions = _enhanceActions(
        actions,
        userText: lastUserMessage,
        assistantText: lastAssistantMessage,
        actionContext: actionContext,
      );
      
      // Step 4: Normalize and prefill - prioritize assistant text for extraction
      actions = _normalizeActionTitles(actions, lastUserMessage);
      actions = _prefillMissingActionData(
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

  /// Minimal enhancement - just adds timeline-based alerts if needed.
  /// We trust the action extractor's output since _shouldDetectActions already
  /// verified the AI suggested creating something.
  List<ChatSuggestedAction> _enhanceActions(
    List<ChatSuggestedAction> actions, {
    String? userText,
    String? assistantText,
    String? actionContext,
  }) {
    // Trust the action extractor - don't filter out what it returns
    // The AI already decided to suggest these actions
    if (actions.isEmpty) return actions;
    
    var result = List<ChatSuggestedAction>.from(actions);
    
    // Enhancement: if there's a goal but no alert, check if we should add one
    final hasGoal = result.any((a) => a.type == ChatActionType.goal);
    final hasAlert = result.any((a) => a.type == ChatActionType.alert);
    
    if (hasGoal && !hasAlert) {
      // Check for explicit timeline in user text
      final extractedDueInDays = userText != null ? _extractDueInDaysFromText(userText) : null;
      final extractedDueDate = userText != null ? _extractDueDateFromText(userText) : null;
      final hasTimeline = extractedDueInDays != null || extractedDueDate != null;
      
      // Also check assistant text for timeline or alert mentions
      final assistantDueInDays = assistantText != null ? _extractDueInDaysFromText(assistantText) : null;
      final assistantDueDate = assistantText != null ? _extractDueDateFromText(assistantText) : null;
      final assistantHasTimeline = assistantDueInDays != null || assistantDueDate != null;
      
      // Check if user or assistant mentioned alert/reminder
      final mentionsAlert = (userText?.toLowerCase().contains('alert') ?? false) ||
          (userText?.toLowerCase().contains('reminder') ?? false) ||
          (assistantText?.toLowerCase().contains('alert') ?? false) ||
          (assistantText?.toLowerCase().contains('reminder') ?? false);
      
      if (hasTimeline || assistantHasTimeline || mentionsAlert) {
        final goal = result.firstWhere((a) => a.type == ChatActionType.goal);
        final dueDate = extractedDueDate ?? assistantDueDate;
        var dueInDays = extractedDueInDays ?? assistantDueInDays;
        
        // Calculate from goal if no explicit timeline
        if (dueDate == null && dueInDays == null) {
          final target = goal.amount;
          final weekly = goal.weeklyAmount;
          if (target != null && weekly != null && weekly > 0) {
            final weeks = (target / weekly).ceil();
            dueInDays = weeks * 7;
          } else {
            dueInDays = 28; // Default 4 weeks
          }
        }
        
        result.add(ChatSuggestedAction(
          type: ChatActionType.alert,
          title: goal.title ?? 'Reminder',
          description: userText ?? '',
          amount: goal.amount,
          dueDate: dueDate,
          dueInDays: dueInDays,
        ));
      }
    }
    
    return result;
  }

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

  // Removed duplicate helper methods - now using _enhanceActions for single-pass processing

  /// Fills in missing action data by extracting from text.
  /// PRIORITIZES assistant text over user text to get clean values.
  List<ChatSuggestedAction> _prefillMissingActionData(
    List<ChatSuggestedAction> actions, {
    String? userText,
    String? assistantText,
  }) {
    if (actions.isEmpty) return actions;
    
    // Extract from assistant text first (higher priority - cleaner values)
    final assistantAmount = assistantText != null 
        ? (_extractTargetFromAssistant(assistantText) ?? _extractAmountFromText(assistantText))
        : null;
    final assistantWeekly = assistantText != null ? _extractWeeklyFromAssistant(assistantText) : null;
    final assistantName = assistantText != null ? _extractNameFromAssistant(assistantText) : null;
    final assistantDueInDays = assistantText != null ? _extractDueInDaysFromText(assistantText) : null;
    final assistantDueDate = assistantText != null ? _extractDueDateFromText(assistantText) : null;
    
    // Extract from user text as fallback
    final userAmount = userText != null ? _extractAmountFromText(userText) : null;
    final userName = userText != null ? _extractGoalNameFromText(userText) : null;
    final userDueInDays = userText != null ? _extractDueInDaysFromText(userText) : null;
    final userDueDate = userText != null ? _extractDueDateFromText(userText) : null;
    
    return actions.map((action) {
      var updated = action;
      
      // Fill amount - prefer assistant value
      if (updated.amount == null) {
        final amount = assistantAmount ?? userAmount;
        if (amount != null) {
          updated = updated.copyWith(amount: amount);
        }
      }
      
      // Fill weekly amount - ONLY from assistant or calculation, never from user raw text
      if (updated.type == ChatActionType.goal && updated.weeklyAmount == null) {
        if (assistantWeekly != null && assistantWeekly > 0) {
          updated = updated.copyWith(weeklyAmount: assistantWeekly);
        } else if (updated.amount != null) {
          // Calculate from amount + timeline
          final dueIn = updated.dueInDays ?? assistantDueInDays ?? userDueInDays;
          final dueDate = updated.dueDate ?? assistantDueDate ?? userDueDate;
          final weekly = _calculateWeeklyContribution(
            updated.amount!,
            dueDate: dueDate,
            dueInDays: dueIn,
          );
          if (weekly != null && weekly > 0) {
            updated = updated.copyWith(weeklyAmount: weekly);
          }
        }
      }
      
      // Fill title - prefer assistant's clean name
      if (updated.type == ChatActionType.goal &&
          (updated.title == null || _isGenericGoalName(updated.title!))) {
        final name = assistantName ?? userName;
        if (name != null) {
          updated = updated.copyWith(title: name);
        }
      }
      
      // Fill due date
      if (updated.dueDate == null) {
        final date = assistantDueDate ?? userDueDate;
        if (date != null) {
          updated = updated.copyWith(dueDate: date);
        }
      }
      
      // Fill due in days
      if (updated.dueInDays == null) {
        final days = assistantDueInDays ?? userDueInDays;
        if (days != null) {
          updated = updated.copyWith(dueInDays: days);
        }
      }
      
      return updated;
    }).toList();
  }
  
  /// Extracts weekly limit from assistant's response for budgets.
  /// Handles markdown: **Limit**: **$50/week**
  double? _extractLimitFromAssistant(String text) {
    final cleaned = text.replaceAll('**', '');
    
    final patterns = [
      // "Limit: $50/week" or "Limit: $50 per week" or "Limit: $50"
      RegExp(r'limit[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)(?:\s*/?\s*week)?', caseSensitive: false),
      // "cap at $50"
      RegExp(r'cap\s+(?:at|of)[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      // "$50/week limit"
      RegExp(r'\$([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:/|per\s+)?week\s+limit', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null) {
        final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (value != null && value > 0 && !(value >= 2000 && value <= 2099)) {
          return value;
        }
      }
    }
    return null;
  }
  
  /// Extracts target/goal amount from assistant's response.
  /// Handles markdown: **Target**: **$2,000** or Target: $2000
  double? _extractTargetFromAssistant(String text) {
    // Strip markdown bold markers
    final cleaned = text.replaceAll('**', '');
    
    final patterns = [
      // "Target: $2,000" or "Target: 2000"
      RegExp(r'target[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      // "Amount: $2,000"
      RegExp(r'amount[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      // "Goal: $2,000"
      RegExp(r'goal[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      // "save $2,000" or "saving $2,000"
      RegExp(r'sav(?:e|ing)[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null) {
        final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
        // Skip years (2000-2099)
        if (value != null && value > 0 && !(value >= 2000 && value <= 2099 && value == value.truncate())) {
          return value;
        }
      }
    }
    return null;
  }
  
  /// Extracts weekly contribution from assistant's response.
  /// Handles markdown: **Weekly**: **$50** or Weekly: $50
  double? _extractWeeklyFromAssistant(String text) {
    // Strip markdown bold markers
    final cleaned = text.replaceAll('**', '');
    
    final patterns = [
      // "Weekly: $50" or "Weekly: 50"
      RegExp(r'weekly[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      // "weekly contribution: $50"
      RegExp(r'weekly contribution[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      // "contribute $50 per week"
      RegExp(r'contribute[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:per\s+)?week', caseSensitive: false),
      // "$50/week" or "$50 per week"
      RegExp(r'\$([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:/|per\s+)?week', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null) {
        final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (value != null && value > 0) return value;
      }
    }
    return null;
  }
  
  /// Extracts goal/alert name from assistant's response.
  /// Handles markdown bold format: **Name**: Bike or Name: Bike
  String? _extractNameFromAssistant(String text) {
    // Strip markdown bold markers for easier matching
    final cleaned = text.replaceAll('**', '');
    
    final patterns = [
      // "Name: Bike" or "Name: Bike," or "Name: Bike\n"
      RegExp(r'name[:\s]+([A-Za-z][A-Za-z0-9\s\-]+?)(?:\s*[-,\n]|\s*$|\s+target|\s+amount)', caseSensitive: false),
      // "called Bike"
      RegExp(r'called\s+([A-Za-z][A-Za-z0-9\s\-]+?)(?:\s*[-,\n]|\s*$|\s+for)', caseSensitive: false),
      // "goal: Bike" at start of line
      RegExp(r'goal[:\s]+([A-Za-z][A-Za-z0-9\s\-]+?)(?:\s*[-,\n]|\s*$|\s+target)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null) {
        var name = match.group(1)?.trim();
        if (name != null && name.isNotEmpty && name.length < 30) {
          // Clean up any trailing punctuation
          name = name.replaceAll(RegExp(r'[,.\-]+$'), '').trim();
          // Don't return generic words
          final lower = name.toLowerCase();
          if (lower != 'goal' && lower != 'savings' && lower != 'alert' && lower != 'budget' && lower != 'set') {
            return name;
          }
        }
      }
    }
    return null;
  }
  
  /// Fallback extraction: Creates actions directly from assistant text patterns.
  /// Used when the AI action extractor fails to return anything.
  List<ChatSuggestedAction> _extractActionsFromAssistantText(String text) {
    final actions = <ChatSuggestedAction>[];
    final cleaned = text.replaceAll('**', '').toLowerCase();
    
    // Check if this looks like a goal suggestion
    final hasGoalPattern = cleaned.contains('name:') && 
        (cleaned.contains('target:') || cleaned.contains('weekly:'));
    
    if (hasGoalPattern) {
      final name = _extractNameFromAssistant(text);
      final amount = _extractTargetFromAssistant(text) ?? _extractAmountFromText(text);
      final weekly = _extractWeeklyFromAssistant(text);
      final dueDate = _extractDueDateFromText(text);
      final dueInDays = _extractDueInDaysFromText(text);
      
      // Only create action if we have at least name or amount
      if (name != null || amount != null) {
        actions.add(ChatSuggestedAction(
          type: ChatActionType.goal,
          title: name,
          amount: amount,
          weeklyAmount: weekly,
        ));
        
        // Also create alert if there's a timeline or alert mention
        final mentionsAlert = cleaned.contains('alert') || cleaned.contains('reminder');
        if (dueDate != null || dueInDays != null || mentionsAlert) {
          // Calculate due days from goal if not specified
          var alertDueInDays = dueInDays;
          if (dueDate == null && alertDueInDays == null) {
            if (amount != null && weekly != null && weekly > 0) {
              final weeks = (amount / weekly).ceil();
              alertDueInDays = weeks * 7;
            } else {
              alertDueInDays = 28; // Default 4 weeks
            }
          }
          
          actions.add(ChatSuggestedAction(
            type: ChatActionType.alert,
            title: name ?? 'Reminder',
            amount: amount,
            dueDate: dueDate,
            dueInDays: alertDueInDays,
          ));
        }
      }
    }
    
    // Check if this looks like a budget suggestion (has Limit: but no Target:)
    final hasBudgetPattern = cleaned.contains('limit:') && !cleaned.contains('target:');
    
    if (hasBudgetPattern && actions.isEmpty) {
      final name = _extractNameFromAssistant(text);
      final limit = _extractLimitFromAssistant(text) ?? _extractAmountFromText(text);
      
      if (name != null || limit != null) {
        actions.add(ChatSuggestedAction(
          type: ChatActionType.budget,
          title: name,
          categoryName: name,
          weeklyAmount: limit,
        ));
      }
    }
    
    // Check if this looks like an alert suggestion
    final hasAlertPattern = (cleaned.contains('alert') || cleaned.contains('reminder')) &&
        cleaned.contains('due');
    
    if (hasAlertPattern && actions.isEmpty) {
      final name = _extractNameFromAssistant(text);
      final amount = _extractAmountFromText(text);
      final dueDate = _extractDueDateFromText(text);
      final dueInDays = _extractDueInDaysFromText(text);
      
      if (name != null || dueDate != null || dueInDays != null) {
        actions.add(ChatSuggestedAction(
          type: ChatActionType.alert,
          title: name,
          amount: amount,
          dueDate: dueDate,
          dueInDays: dueInDays,
        ));
      }
    }
    
    return actions;
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
        !_isGenericGoalName(candidateName);
    String? defaultName;
    if (!hasName) {
      try {
        defaultName = await _nextGoalName();
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
        !_isGenericBudgetName(candidateName);
    String? defaultName;
    if (!hasName) {
      try {
        defaultName = await _nextBudgetName();
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
        !_isGenericAlertName(candidateTitle);
    String? defaultTitle;
    if (!hasTitle) {
      try {
        defaultTitle = await _nextAlertName();
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
            : 'Due ${_friendlyDate(form.dueDate)}'
                '${form.amount != null ? ' for ${_formatCurrency(form.amount!)}' : ''}',
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

  /// Renders chat history, the message composer, and clear/send controls.
  @override
  Widget build(BuildContext context) {
    final lastAssistantIndex =
        _messages.lastIndexWhere((msg) => msg.role == ChatRole.assistant);
    final linkedAlert = _firstActionOfType(
      ChatActionType.alert,
      _pendingActions,
    );
    final hasGoal = _pendingActions.any((action) => action.type == ChatActionType.goal);
    final inlineActions = (hasGoal && linkedAlert != null)
        ? _pendingActions.where((action) => action.type != ChatActionType.alert).toList()
        : _pendingActions;
    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scroll, // Added: keep a handle for auto-scroll.
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.role == ChatRole.user;
                final showInlineActions = !isUser &&
                    index == lastAssistantIndex &&
                    (inlineActions.isNotEmpty || _actionLoading);
                return Column(
                  crossAxisAlignment:
                      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Align(
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
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 4), // spacing between bubbles
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Clear chat',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: _sending ? null : _clearChat,
                ),
                GestureDetector(
                  onTap: _sending
                      ? null
                      : () => setState(() {
                            _chatMode = _chatMode == ChatMode.local
                                ? ChatMode.backend
                                : ChatMode.local;
                          }),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      _chatMode == ChatMode.local ? 'Local' : 'Backend',
                      style: const TextStyle(fontSize: 10),
                    ),
                    avatar: Icon(
                      _chatMode == ChatMode.local ? Icons.computer : Icons.cloud,
                      size: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _hintFadeAnimation,
                    builder: (context, child) {
                      final hintText = _hasApiKey
                          ? _exampleQuestions[_hintIndex].replaceAll('"', '')
                          : "Type a message... (Add API key in Settings)";
                      return TextField(
                        controller: _controller,
                        // allow Enter to send. TODO: not working
                        onSubmitted: (_) {
                          if (_hasApiKey && !_sending) _sendMessage();
                        },
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500.withOpacity(
                              _hasApiKey ? _hintFadeAnimation.value : 1.0,
                            ),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      );
                    },
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
                  onPressed: (_hasApiKey && !_sending) ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
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
      text: _prefillAmount(widget.action.amount),
    );
    // Don't fall back to amount for weekly - that's completely wrong!
    // If no weekly amount was extracted, leave empty for user to fill in
    _weeklyCtrl = TextEditingController(
      text: _prefillAmount(widget.action.weeklyAmount),
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
    final target = _parseCurrency(_amountCtrl.text.trim());
    final weekly = _parseCurrency(_weeklyCtrl.text.trim());
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
          ? ' and an alert for ${_friendlyDate(_alertDueDate!)}.'
          : '.';
      Navigator.of(context).pop(
        _ActionOutcome(
          snackText: "Saved goal '$name'",
          chatText:
              "Locked in a savings goal called $name for ${_formatCurrency(target)} with ${_formatCurrency(weekly)} weekly contributions$alertSuffix",
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
                      : _friendlyDate(_alertDueDate!),
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
      message: 'Due ${_friendlyDate(dueDate)}'
          '${amount > 0 ? ' for ${_formatCurrency(amount)}' : ''}',
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
    final label = _inlineActionLabel(action);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
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

String _formatCurrency(double value) {
  final decimals = value.abs() >= 100 ? 0 : 2;
  return '\$${value.toStringAsFixed(decimals)}';
}

String _inlineActionLabel(ChatSuggestedAction action) {
  final amount = action.amount ?? action.weeklyAmount;
  final amountLabel =
      amount != null && amount > 0 ? '${_formatCurrency(amount)} ' : '';
  switch (action.type) {
    case ChatActionType.goal:
      return 'Create ${amountLabel}goal';
    case ChatActionType.budget:
      return 'Create ${amountLabel}budget';
    case ChatActionType.alert:
      return 'Create ${amountLabel}alert';
  }
}

ChatSuggestedAction? _firstActionOfType(
  ChatActionType type,
  List<ChatSuggestedAction> actions,
) {
  for (final action in actions) {
    if (action.type == type) return action;
  }
  return null;
}

Future<String> _nextGoalName() async {
  final goals = await GoalRepository.getAll();
  return _nextIndexedName('Goal', goals.map((g) => g.name));
}

Future<String> _nextAlertName() async {
  final alerts = await AlertRepository.getAll();
  return _nextIndexedName('Alert', alerts.map((a) => a.title));
}

Future<String> _nextBudgetName() async {
  final budgets = await BudgetRepository.getAll();
  final labels = budgets
      .where((b) => b.goalId == null)
      .map((b) => b.label ?? '');
  return _nextIndexedName('Budget', labels);
}

String _nextIndexedName(String base, Iterable<String?> names) {
  final pattern = RegExp('^${RegExp.escape(base)}\\s*(\\d+)\$',
      caseSensitive: false);
  var maxIndex = 0;
  for (final name in names) {
    if (name == null) continue;
    final match = pattern.firstMatch(name.trim());
    if (match == null) continue;
    final value = int.tryParse(match.group(1)!);
    if (value != null && value > maxIndex) {
      maxIndex = value;
    }
  }
  return '$base ${maxIndex + 1}';
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
      RegExp(r'\b(bill(?:s)?|invoice|repair|mechanic|dentist|fine|payment|rent|warrant|wof|rego)\b');
  return pattern.hasMatch(text);
}

bool _mentionsAlert(String text) {
  final pattern =
      RegExp(r'\b(alert|remind|reminder|notify|notification|remember)\b');
  return pattern.hasMatch(text);
}

bool _mentionsGoal(String text) {
  final pattern = RegExp(
    r'\b(goal|saving|save up|savings|save for|set aside|put aside|contribute|target)\b',
  );
  return pattern.hasMatch(text);
}

bool _mentionsBudget(String text) {
  final pattern = RegExp(r'\b(budget|weekly limit|spend limit)\b');
  return pattern.hasMatch(text);
}

bool _wantsAlertOnly(String text) {
  return _mentionsAlert(text) && !_mentionsGoal(text);
}

bool _goalNeedsAlert(String normalizedText, List<ChatSuggestedAction> actions) {
  if (!_mentionsGoal(normalizedText)) return false;
  final hasTimeline = _extractDueInDaysFromText(normalizedText) != null ||
      _extractDueDateFromText(normalizedText) != null;
  if (hasTimeline) return true;
  for (final action in actions) {
    if (action.type == ChatActionType.goal && action.hasDueDate) return true;
  }
  return false;
}

bool _assistantPromptedAction(String text, ChatActionType type) {
  if (text.isEmpty) return false;
  switch (type) {
    case ChatActionType.goal:
      return RegExp(
        r'\b(create goal|goal name|call this goal|name this goal|goal)\b',
      ).hasMatch(text);
    case ChatActionType.budget:
      return RegExp(r'\b(create budget|budget name|weekly limit|budget)\b')
          .hasMatch(text);
    case ChatActionType.alert:
      return RegExp(r'\b(create alert|remind|reminder|alert)\b')
          .hasMatch(text);
  }
}

bool _looksLikeName(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  final lower = trimmed.toLowerCase();
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(lower)) return false;
  if (RegExp(r'\b(in\s+)?\d+\s*(day|days|week|weeks|month|months)\b')
      .hasMatch(lower)) {
    return false;
  }
  if (lower.contains('today') ||
      lower.contains('tomorrow') ||
      lower.contains('next week') ||
      lower.contains('next month')) {
    return false;
  }
  if (trimmed.split(RegExp(r'\s+')).length > 6) return false;
  return RegExp(r'[a-zA-Z]').hasMatch(trimmed);
}

String? _extractGoalNameFromText(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) return null;
  final lower = normalized.toLowerCase();
  final namedMatch = RegExp(
    r'\b(?:called|named|name it|call it)\s+([a-z0-9][a-z0-9\s\-&]+)\b',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (namedMatch != null) {
    final raw = normalized.substring(namedMatch.start, namedMatch.end);
    final cleaned = raw
        .replaceFirst(
          RegExp(
            r'\b(?:called|named|name it|call it)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final title = _cleanGoalTitle(cleaned);
    return title.isEmpty ? null : title;
  }
  final forMatch = RegExp(
    r'\b(?:for|to buy|to get|to save for|to pay for)\s+([a-z0-9][a-z0-9\s\-&]+)',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (forMatch != null) {
    final raw = normalized.substring(forMatch.start, forMatch.end);
    final cleaned = raw
        .replaceFirst(
          RegExp(
            r'\b(?:for|to buy|to get|to save for|to pay for)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final title = _cleanGoalTitle(cleaned);
    return title.isEmpty ? null : title;
  }
  if (_looksLikeName(normalized)) {
    return _cleanGoalTitle(normalized);
  }
  return null;
}

String _cleanGoalTitle(String text) {
  var cleaned = text.trim();
  cleaned = cleaned.replaceAll(RegExp(r'[\.\!\?]+$'), '').trim();
  cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
  return cleaned;
}

ChatSuggestedAction _normalizeActionTitle(ChatSuggestedAction action) {
  final rawTitle = action.title?.trim();
  if (rawTitle == null || rawTitle.isEmpty) return action;
  switch (action.type) {
    case ChatActionType.goal:
      if (_isGenericGoalName(rawTitle)) {
        return action.copyWith(title: 'goal');
      }
      break;
    case ChatActionType.alert:
      if (_isGenericAlertName(rawTitle)) {
        return action.copyWith(title: 'alert');
      }
      break;
    case ChatActionType.budget:
      if (_isGenericBudgetName(rawTitle)) {
        return action.copyWith(title: 'budget');
      }
      break;
  }
  return action;
}


List<ChatSuggestedAction> _normalizeActionTitles(
  List<ChatSuggestedAction> actions,
  String? userText,
) {
  if (actions.isEmpty) return actions;
  return actions
      .map(
        (action) => _normalizeTitleForAction(
          action,
          userText,
        ),
      )
      .toList();
}

ChatSuggestedAction _normalizeTitleForAction(
  ChatSuggestedAction action,
  String? userText,
) {
  final rawTitle = action.title?.trim();
  final typeWord = action.type.name;
  if (rawTitle == null || rawTitle.isEmpty) {
    return action.copyWith(title: typeWord);
  }
  final lowerTitle = rawTitle.toLowerCase();
  if (_isGenericTypeLabel(lowerTitle, typeWord)) {
    return action.copyWith(title: typeWord);
  }
  final hasTypeWord =
      RegExp(r'\b' + RegExp.escape(typeWord) + r'\b').hasMatch(lowerTitle);
  final userNamed = _userProvidedExplicitName(userText, action.type);
  if (hasTypeWord && !userNamed) {
    return action.copyWith(title: typeWord);
  }
  return action;
}

bool _isGenericGoalName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return _isGenericTypeLabel(normalized, 'goal') ||
      normalized == 'savings goal' ||
      normalized == 'upcoming bill';
}

bool _isGenericAlertName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return _isGenericTypeLabel(normalized, 'alert') || normalized == 'reminder';
}

bool _isGenericBudgetName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return _isGenericTypeLabel(normalized, 'budget');
}

bool _isGenericTypeLabel(String normalized, String typeWord) {
  return normalized == typeWord;
}

bool _userProvidedExplicitName(String? text, ChatActionType type) {
  if (text == null || text.trim().isEmpty) return false;
  final normalized = text.toLowerCase();
  final namePhrases = [
    r'\bcall it\b',
    r'\bname it\b',
    r'\blabel it\b',
    r'\btitle it\b',
    r'\bcalled\b',
    r'\bnamed\b',
  ];
  for (final phrase in namePhrases) {
    if (RegExp(phrase).hasMatch(normalized)) {
      return true;
    }
  }
  final typeWord = type.name;
  if (RegExp(r'\b' + RegExp.escape(typeWord) + r'\b').hasMatch(normalized) &&
      (normalized.contains('called') || normalized.contains('named'))) {
    return true;
  }
  if (type == ChatActionType.alert) {
    if (RegExp(r'\breminder\b').hasMatch(normalized) &&
        (normalized.contains('called') || normalized.contains('named'))) {
      return true;
    }
  }
  return false;
}

double? _extractAmountFromText(String text) {
  final cleaned = text.replaceAll(',', '');
  final matches = RegExp(r'(\$)?\s*([0-9]+(?:\.[0-9]{1,2})?)\s*([kK])?')
      .allMatches(cleaned);
  for (final match in matches) {
    final value = double.tryParse(match.group(2) ?? '');
    if (value == null || value <= 0) continue;
    final suffix = match.group(3);
    final hasCurrency = match.group(1) != null;
    
    // Skip years (4-digit numbers 2000-2099 without $ prefix)
    if (!hasCurrency && value >= 2000 && value <= 2099 && value == value.truncate()) {
      continue;
    }
    
    final tail = cleaned.substring(match.end).toLowerCase();
    final hasTimeUnit = RegExp(r'^\s*(day|days|week|weeks|month|months|year|years)\b')
        .hasMatch(tail);
    if (hasTimeUnit && !hasCurrency) {
      continue;
    }
    
    // Skip if this looks like part of a date (followed by - or / and more digits)
    if (RegExp(r'^\s*[-/]\s*\d').hasMatch(tail)) {
      continue;
    }
    
    // Skip if preceded by date-like patterns (month names, day numbers with /)
    final beforeMatch = match.start > 0 ? cleaned.substring(0, match.start).toLowerCase() : '';
    if (RegExp(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|\d{1,2}[-/])\s*$').hasMatch(beforeMatch)) {
      continue;
    }
    
    final amount = suffix == null ? value : value * 1000;
    return amount;
  }
  return null;
}

int? _extractDueInDaysFromText(String text) {
  final normalized = text.toLowerCase();
  final dayMatch =
      RegExp(r'\b(?:in\s+)?(\d{1,3})\s*(day|days)\b').firstMatch(normalized);
  if (dayMatch != null) {
    final days = int.tryParse(dayMatch.group(1)!);
    if (days != null && days >= 0) return days;
  }
  final weekMatch =
      RegExp(r'\b(?:in\s+)?(\d{1,3})\s*(week|weeks)\b').firstMatch(normalized);
  if (weekMatch != null) {
    final weeks = int.tryParse(weekMatch.group(1)!);
    if (weeks != null && weeks >= 0) return weeks * 7;
  }
  final monthMatch =
      RegExp(r'\b(?:in\s+)?(\d{1,3})\s*(month|months)\b').firstMatch(normalized);
  if (monthMatch != null) {
    final months = int.tryParse(monthMatch.group(1)!);
    if (months != null && months >= 0) return months * 30;
  }
  final yearMatch =
      RegExp(r'\b(?:in\s+)?(\d{1,3})\s*(year|years)\b').firstMatch(normalized);
  if (yearMatch != null) {
    final years = int.tryParse(yearMatch.group(1)!);
    if (years != null && years >= 0) return years * 365;
  }
  if (normalized.contains('tomorrow')) return 1;
  if (normalized.contains('today')) return 0;
  if (normalized.contains('next week')) return 7;
  if (normalized.contains('next month')) return 30;
  return null;
}

DateTime? _extractDueDateFromText(String text) {
  final normalized = text.toLowerCase();
  final isoMatch =
      RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').firstMatch(normalized);
  if (isoMatch != null) {
    try {
      return DateTime.parse(isoMatch.group(0)!);
    } catch (_) {
      // fall through
    }
  }
  final monthMatch = RegExp(
    r'\b(\d{1,2})\s+'
    r'(jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|september|oct|october|nov|november|dec|december)'
    r'(?:\s+(\d{4}))?\b',
  ).firstMatch(normalized);
  if (monthMatch != null) {
    final day = int.tryParse(monthMatch.group(1)!);
    final year = int.tryParse(monthMatch.group(3) ?? '');
    final monthText = monthMatch.group(2)!;
    final month = _monthNumber(monthText);
    if (day != null && month != null) {
      final now = DateTime.now();
      final targetYear = year ?? now.year;
      var candidate = DateTime(targetYear, month, day);
      if (candidate.isBefore(now) && year == null) {
        candidate = DateTime(targetYear + 1, month, day);
      }
      return candidate;
    }
  }
  return null;
}

int? _monthNumber(String text) {
  switch (text.substring(0, 3)) {
    case 'jan':
      return 1;
    case 'feb':
      return 2;
    case 'mar':
      return 3;
    case 'apr':
      return 4;
    case 'may':
      return 5;
    case 'jun':
      return 6;
    case 'jul':
      return 7;
    case 'aug':
      return 8;
    case 'sep':
      return 9;
    case 'oct':
      return 10;
    case 'nov':
      return 11;
    case 'dec':
      return 12;
  }
  return null;
}

double? _calculateWeeklyContribution(
  double amount, {
  DateTime? dueDate,
  int? dueInDays,
}) {
  int? days = dueInDays;
  if (days == null && dueDate != null) {
    days = dueDate.difference(DateTime.now()).inDays;
  }
  if (days == null || days <= 0) return null;
  final weeks = (days / 7).clamp(1, double.infinity);
  final weekly = amount / weeks;
  return (weekly * 100).roundToDouble() / 100;
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
