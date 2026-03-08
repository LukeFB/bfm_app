// ---------------------------------------------------------------------------
// File: lib/services/budget_buffer_refresh.dart
//
// Purpose:
//   Notifies listeners (e.g. BudgetsScreen) when the budget buffer store has
//   been updated (e.g. after weekly overview finishes) so they can reload.
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart';

/// Call [notify] when the budget buffer store has been updated so screens
/// like BudgetsScreen can reload their buffer data.
final ValueNotifier<int> budgetBufferRefreshNotifier = ValueNotifier(0);

void notifyBudgetBufferUpdated() {
  budgetBufferRefreshNotifier.value++;
}
