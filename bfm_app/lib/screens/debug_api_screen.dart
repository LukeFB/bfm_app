import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bfm_app/controllers/auth_controller.dart';
import 'package:bfm_app/controllers/akahu_controller.dart';
import 'package:bfm_app/providers/api_providers.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/repositories/account_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';

/// Developer screen to exercise every backend API endpoint.
class DebugApiScreen extends ConsumerStatefulWidget {
  const DebugApiScreen({super.key});

  @override
  ConsumerState<DebugApiScreen> createState() => _DebugApiScreenState();
}

class _DebugApiScreenState extends ConsumerState<DebugApiScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController(text: 'Test');
  final _messageCtrl = TextEditingController();
  final _output = StringBuffer();
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _log(String label, dynamic data) {
    final pretty = data is Map || data is List
        ? const JsonEncoder.withIndent('  ').convert(data)
        : data.toString();
    setState(() {
      _output.writeln('--- $label ---');
      _output.writeln(pretty);
      _output.writeln('');
    });
  }

  void _logError(String label, Object e) {
    setState(() {
      _output.writeln('--- $label ERROR ---');
      _output.writeln(e.toString());
      if (e is DioException) {
        _output.writeln('Status: ${e.response?.statusCode}');
        _output.writeln('Body: ${e.response?.data}');
        _output.writeln('Headers sent: ${e.requestOptions.headers}');
      }
      _output.writeln('');
    });
  }

  Future<void> _run(String label, Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      _logError(label, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug API'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear log',
            onPressed: () => setState(() => _output.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _output.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Password',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _firstNameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'First name',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageCtrl,
                  decoration: const InputDecoration(
                    hintText: 'AI message',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Row(
              children: [
                _Btn('Register', () => _run('Register', () async {
                  final ok = await ref.read(authControllerProvider.notifier).register(
                    email: _emailCtrl.text.trim(),
                    password: _passwordCtrl.text.trim(),
                    passwordConfirmation: _passwordCtrl.text.trim(),
                    firstName: _firstNameCtrl.text.trim(),
                  );
                  _log('Register', ok ? 'Success' : ref.read(authControllerProvider).error ?? 'Failed');
                })),
                _Btn('Login', () => _run('Login', () async {
                  final ok = await ref.read(authControllerProvider.notifier).login(
                    email: _emailCtrl.text.trim(),
                    password: _passwordCtrl.text.trim(),
                  );
                  _log('Login', ok ? 'Success' : ref.read(authControllerProvider).error ?? 'Failed');
                })),
                _Btn('Raw Login', () => _run('Raw Login', () async {
                  final email = _emailCtrl.text.trim();
                  final pass = _passwordCtrl.text.trim();
                  _log('Sending', 'email="$email" pass_length=${pass.length}');
                  final dio = Dio(BaseOptions(
                    baseUrl: 'https://moni.luminateone.dev/api/v1',
                    headers: {'Accept': 'application/json'},
                  ));
                  try {
                    final resp = await dio.post(
                      '/auth/login',
                      data: FormData.fromMap({'email': email, 'password': pass}),
                    );
                    _log('Raw Login OK', resp.data);
                  } on DioException catch (e) {
                    _log('Raw Login FAILED', {
                      'status': e.response?.statusCode,
                      'body': e.response?.data,
                      'type': e.type.toString(),
                    });
                  }
                })),
                _Btn('Me', () => _run('Me', () async {
                  await ref.read(authControllerProvider.notifier).loadMe();
                  final s = ref.read(authControllerProvider);
                  if (s.user != null) {
                    _log('Me', s.user);
                  } else {
                    _log('Me', s.error ?? 'No user');
                  }
                })),
                _Btn('Akahu Connect', () => _run('Akahu Connect', () async {
                  await ref.read(akahuControllerProvider.notifier).startConnect();
                  final s = ref.read(akahuControllerProvider);
                  _log('Akahu Connect', s.error ?? 'Opened browser');
                })),
                _Btn('Verify', () => _run('Verify Connected', () async {
                  final ok = await ref.read(akahuControllerProvider.notifier).verifyConnected();
                  _log('Verify Connected', ok ? 'Connected!' : 'Not connected');
                })),
                _Btn('Accounts', () => _run('Accounts', () async {
                  await ref.read(akahuControllerProvider.notifier).fetchAccounts();
                  final s = ref.read(akahuControllerProvider);
                  _log('Accounts', s.accounts);
                })),
                _Btn('Txns', () => _run('Transactions', () async {
                  final api = ref.read(akahuApiProvider);
                  final raw = await api.transactions();
                  _log('Backend returned', '${raw.length} transactions (after pagination)');
                  if (raw.isNotEmpty) {
                    final first = raw.first;
                    _log('Keys', first.keys.toList());
                    final hasCategory = first.containsKey('category') || first.containsKey('category_name');
                    final hasMerchant = first.containsKey('merchant') || first.containsKey('merchant_name');
                    _log('Has category data', hasCategory);
                    _log('Has merchant data', hasMerchant);
                    if (hasCategory) {
                      _log('category field', first['category'] ?? first['category_name']);
                    } else {
                      _log('NO CATEGORIES', 'Backend does not return category data. This is a backend issue.');
                    }
                    _log('Sample txn', first);
                  }
                })),
                _Btn('Raw Page1', () => _run('Raw Page 1', () async {
                  final client = ref.read(apiClientProvider);
                  final resp = await client.dio.get('/akahu/transactions', queryParameters: {'page': 1, 'per_page': 5});
                  final data = resp.data;
                  if (data is Map<String, dynamic>) {
                    _log('Response keys', data.keys.toList());
                    _log('current_page', data['current_page']);
                    _log('last_page', data['last_page']);
                    _log('total', data['total'] ?? data['per_page']);
                  }
                  _log('Raw response', data);
                })),
                _Btn('AI Msg', () => _run('AI Message', () async {
                  final msg = _messageCtrl.text.trim();
                  if (msg.isEmpty) {
                    _log('AI Message', 'Enter a message first');
                    return;
                  }
                  final api = ref.read(messagesApiProvider);
                  final res = await api.sendMessage(msg);
                  _log('AI Message', res);
                })),
                _Btn('Tips', () => _run('Tips', () async {
                  final api = ref.read(contentApiProvider);
                  final res = await api.tips();
                  _log('Tips', res);
                })),
                _Btn('Events', () => _run('Events', () async {
                  final api = ref.read(contentApiProvider);
                  final res = await api.events();
                  _log('Events', res);
                })),
                _Btn('Full Sync', () => _run('Full Sync', () async {
                  await TransactionSyncService().syncNow(forceRefresh: true);
                  final accounts = await AccountRepository.getAll();
                  final txns = await TransactionRepository.getRecent(10);
                  _log('Full Sync', 'Done – ${accounts.length} accounts, '
                      '${txns.length}+ transactions in local DB');
                })),
                _Btn('Cat Trace', () => _run('Category Trace', () async {
                  final api = ref.read(akahuApiProvider);
                  final raw = await api.transactions();
                  if (raw.isEmpty) {
                    _log('Cat Trace', 'No transactions from backend');
                    return;
                  }
                  final sample = raw.first;
                  _log('RAW JSON keys', sample.keys.toList());
                  _log('raw["category"]', '${sample['category']} (${sample['category'].runtimeType})');
                  _log('raw["category_name"]', '${sample['category_name']} (${sample['category_name'].runtimeType})');
                  _log('raw["category_id"]', '${sample['category_id']}');

                  final txn = TransactionModel.fromAkahu(sample);
                  _log('fromAkahu categoryName', '${txn.categoryName}');

                  final map = txn.toDbMap();
                  _log('toDbMap category_id', '${map['category_id']}');
                  _log('toDbMap category_name', '${map['category_name']}');

                  final catId = await CategoryRepository.ensureByName(
                    txn.categoryName ?? 'Uncategorized',
                  );
                  _log('ensureByName returned ID', catId);

                  final allCats = await CategoryRepository.getAll();
                  _log('All categories in DB', allCats.map((c) => '${c['id']}: ${c['name']} (usage: ${c['usage_count']})').toList());
                })),
                _Btn('DB Stats', () => _run('DB Stats', () async {
                  final accounts = await AccountRepository.getAll();
                  final txns = await TransactionRepository.getAll();
                  final categorised = txns.where((t) =>
                      t.categoryName != null &&
                      t.categoryName != 'Uncategorized').length;
                  _log('DB Stats', {
                    'accounts': accounts.length,
                    'transactions': txns.length,
                    'categorised': categorised,
                    'uncategorised': txns.length - categorised,
                  });
                })),
                _Btn('Revoke', () => _run('Revoke Akahu', () async {
                  await ref.read(akahuControllerProvider.notifier).revokeConnection();
                  _log('Revoke Akahu', 'Done');
                })),
                _Btn('Logout', () => _run('Logout', () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  _log('Logout', 'Token cleared');
                })),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(fontSize: 12),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label),
      ),
    );
  }
}
