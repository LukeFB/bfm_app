import 'package:bfm_app/models/chat_suggested_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatSuggestedAction', () {
    test('parses complete goal payload', () {
      final action = ChatSuggestedAction.fromJson({
        'type': 'goal',
        'title': 'Sneakers',
        'amount': '180',
        'weekly_contribution': 25,
        'due_date': '2026-02-01',
      });

      expect(action.type, ChatActionType.goal);
      expect(action.title, 'Sneakers');
      expect(action.amount, 180);
      expect(action.weeklyAmount, 25);
      expect(action.dueDate, DateTime.parse('2026-02-01'));
      expect(action.displayLabel, 'Sneakers');
    });

    test('listFromDynamic parses JSON string payload', () {
      const raw =
          '[{"type":"budget","category":"Takeaways","weekly_limit":"80","note":"Cheat night"}]';
      final actions = ChatSuggestedAction.listFromDynamic(raw);

      expect(actions, hasLength(1));
      final budget = actions.first;
      expect(budget.type, ChatActionType.budget);
      expect(budget.categoryName, 'Takeaways');
      expect(budget.weeklyAmount, 80);
      expect(budget.note, 'Cheat night');
    });

    test('listFromDynamic handles single map payload', () {
      final actions = ChatSuggestedAction.listFromDynamic({
        'type': 'alert',
        'title': 'Mechanic bill',
        'amount': 500,
        'due_in_days': '5',
      });
      expect(actions, hasLength(1));
      expect(actions.first.type, ChatActionType.alert);
      expect(actions.first.dueInDays, 5);
    });

    test('listFromDynamic strips code fences before decoding', () {
      const raw = '''
      ```json
      [
        {"type":"goal","name":"Emergency fund","amount": "250"}
      ]
      ```
      ''';
      final actions = ChatSuggestedAction.listFromDynamic(raw);
      expect(actions, hasLength(1));
      expect(actions.first.type, ChatActionType.goal);
      expect(actions.first.amount, 250);
    });

    test('throws on unknown action type', () {
      expect(
        () => ChatSuggestedAction.fromJson({'type': 'something'}),
        throwsArgumentError,
      );
    });
  });
}
