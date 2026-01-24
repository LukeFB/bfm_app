/// ---------------------------------------------------------------------------
/// File: lib/screens/savings_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `/savings` route from dashboard or bottom nav.
///
/// Purpose:
///   - Displays a comprehensive view of the user's financial position:
///     - Balance sheet with assets, liabilities, and net worth
///     - Profit/loss summary for the current month
///     - List of all connected accounts grouped by bank
///     - Savings goals progress
///
/// Inputs:
///   - Fetches data via `SavingsService` which aggregates from accounts,
///     transactions, and goals.
///
/// Outputs:
///   - UI showing complete financial overview like a bank app.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:bfm_app/models/account_model.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/services/savings_service.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:bfm_app/widgets/dashboard_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _bfmBlue = Color(0xFF005494);
const Color _bfmOrange = Color(0xFFFF6934);
const String _timeFramePrefKey = 'savings_profit_loss_time_frame';

/// Screen displaying comprehensive financial overview with balance sheet.
class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  late Future<SavingsData> _future;
  ProfitLossTimeFrame _selectedTimeFrame = ProfitLossTimeFrame.allTime;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  /// Loads saved time frame preference, then loads data.
  Future<void> _initializeAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTimeFrame = prefs.getString(_timeFramePrefKey);
    _selectedTimeFrame = ProfitLossTimeFrame.fromString(savedTimeFrame);
    _initialized = true;
    _future = _load();
    if (mounted) setState(() {});
  }

  Future<SavingsData> _load() async {
    await TransactionSyncService().syncIfStale();
    return SavingsService.loadSavingsData(timeFrame: _selectedTimeFrame);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _forceSync() async {
    await TransactionSyncService().syncNow(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  /// Called when user selects a new time frame from the dropdown.
  Future<void> _onTimeFrameChanged(ProfitLossTimeFrame? newValue) async {
    if (newValue == null || newValue == _selectedTimeFrame) return;
    
    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timeFramePrefKey, newValue.name);
    
    // Update state and reload data
    setState(() {
      _selectedTimeFrame = newValue;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings & Accounts'),
        backgroundColor: _bfmBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: !_initialized
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<SavingsData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        "Error loading data:\n${snap.error}",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snap.data!;
            return RefreshIndicator(
              onRefresh: _forceSync,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- OVERALL PROFIT/LOSS BALANCE SHEET ----------
                    _buildBalanceSheet(data),

                    const SizedBox(height: 24),

                    // ---------- ACCOUNTS LIST ----------
                    _buildAccountsList(data),

                    const SizedBox(height: 24),

                    // ---------- SAVINGS GOALS ----------
                    if (data.goals.isNotEmpty) ...[
                      _buildGoalsSection(data),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Balance sheet showing profit/loss with time frame dropdown.
  Widget _buildBalanceSheet(SavingsData data) {
    final profitLoss = data.overallProfitLoss;
    final isProfit = profitLoss >= 0;

    return DashboardCard(
      title: 'Profit / Loss',
      trailing: _buildTimeFrameDropdown(),
      child: Column(
        children: [
          // Profit/Loss row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isProfit
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isProfit
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isProfit ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isProfit ? 'Net Profit' : 'Net Loss',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isProfit
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatCurrency(profitLoss.abs()),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isProfit
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Income/Expense breakdown
          Row(
            children: [
              Expanded(
                child: _buildBalanceRow(
                  icon: Icons.arrow_downward_rounded,
                  iconColor: Colors.green,
                  label: 'Income',
                  value: data.totalIncome,
                  valueColor: Colors.green.shade700,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: _buildBalanceRow(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: Colors.red,
                  label: 'Expenses',
                  value: data.totalExpenses,
                  valueColor: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the time frame dropdown selector.
  Widget _buildTimeFrameDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _bfmBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProfitLossTimeFrame>(
          value: _selectedTimeFrame,
          onChanged: _onTimeFrameChanged,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _bfmBlue,
            size: 20,
          ),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _bfmBlue,
          ),
          items: ProfitLossTimeFrame.values.map((timeFrame) {
            return DropdownMenuItem<ProfitLossTimeFrame>(
              value: timeFrame,
              child: Text(timeFrame.label),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBalanceRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                _formatCurrency(value),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// List of all accounts grouped by bank.
  Widget _buildAccountsList(SavingsData data) {
    if (data.accounts.isEmpty) {
      return DashboardCard(
        title: 'Accounts',
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _forceSync,
          tooltip: 'Refresh accounts',
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No accounts connected yet.\nPull down to refresh after connecting your bank.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
    }

    return DashboardCard(
      title: 'Accounts',
      trailing: IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: _forceSync,
        tooltip: 'Refresh accounts',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in data.accountsByBank.entries) ...[
            _buildBankSection(entry.key, entry.value),
            if (entry.key != data.accountsByBank.keys.last)
              const Divider(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildBankSection(String bankName, List<AccountModel> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bank header
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _bfmBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance,
                size: 18,
                color: _bfmBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                bankName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Accounts list
        for (final account in accounts) ...[
          _buildAccountTile(account),
          if (account != accounts.last)
            const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildAccountTile(AccountModel account) {
    final balance = account.balanceCurrent;
    final isNegative = balance < 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Account type icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getAccountTypeColor(account.type).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getAccountTypeIcon(account.type),
              color: _getAccountTypeColor(account.type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Account name and type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getAccountTypeColor(account.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        account.type.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _getAccountTypeColor(account.type),
                        ),
                      ),
                    ),
                    if (account.maskedAccountNumber != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        account.maskedAccountNumber!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Balance
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(balance.abs()),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isNegative ? Colors.red.shade700 : Colors.black87,
                ),
              ),
              if (account.balanceAvailable != null &&
                  account.balanceAvailable != balance)
                Text(
                  'Avail: ${_formatCurrency(account.balanceAvailable!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Savings goals progress section.
  Widget _buildGoalsSection(SavingsData data) {
    return DashboardCard(
      title: 'Savings Goals',
      trailing: IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: () => Navigator.pushNamed(context, '/goals'),
        tooltip: 'View all goals',
      ),
      child: Column(
        children: [
          // Overall progress
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bfmBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Progress',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${_formatCurrency(data.totalGoalsSaved)} / ${_formatCurrency(data.totalGoalsTarget)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _bfmBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Individual goals
          for (final goal in data.goals.take(3)) ...[
            _buildGoalTile(goal),
            if (goal != data.goals.take(3).last)
              const SizedBox(height: 8),
          ],

          if (data.goals.length > 3) ...[
            const SizedBox(height: 12),
            Text(
              '+${data.goals.length - 3} more goals',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalTile(GoalModel goal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                goal.name.isEmpty ? 'Savings Goal' : goal.name,
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              goal.progressLabel(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: goal.progressFraction,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(
            goal.isComplete ? Colors.green : _bfmOrange,
          ),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatCurrency(double amount) {
    final prefix = amount < 0 ? '-\$' : '\$';
    final absAmount = amount.abs();
    if (absAmount >= 1000000) {
      return '$prefix${(absAmount / 1000000).toStringAsFixed(1)}M';
    } else if (absAmount >= 10000) {
      return '$prefix${(absAmount / 1000).toStringAsFixed(1)}K';
    } else {
      return '$prefix${absAmount.toStringAsFixed(2)}';
    }
  }

  IconData _getAccountTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.checking:
        return Icons.account_balance_wallet_outlined;
      case AccountType.savings:
        return Icons.savings_outlined;
      case AccountType.creditCard:
        return Icons.credit_card_outlined;
      case AccountType.kiwiSaver:
        return Icons.elderly_outlined;
      case AccountType.investment:
        return Icons.trending_up_outlined;
      case AccountType.loan:
        return Icons.money_off_outlined;
      case AccountType.other:
        return Icons.account_balance_outlined;
    }
  }

  Color _getAccountTypeColor(AccountType type) {
    switch (type) {
      case AccountType.checking:
        return _bfmBlue;
      case AccountType.savings:
        return Colors.green;
      case AccountType.creditCard:
        return Colors.orange;
      case AccountType.kiwiSaver:
        return Colors.purple;
      case AccountType.investment:
        return Colors.teal;
      case AccountType.loan:
        return Colors.red;
      case AccountType.other:
        return Colors.grey;
    }
  }
}
