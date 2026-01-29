/// ---------------------------------------------------------------------------
/// File: lib/screens/transactions_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `/transaction` route (from dashboard card).
///
/// Purpose:
///   - List view showing all stored transactions with search, filters, and
///     quick add/delete functionality.
///
/// Inputs:
///   - Reads via `TransactionRepository`, writes back on add/delete.
///
/// Outputs:
///   - UI list plus manual insert/delete functionality.
/// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/models/category_model.dart';

/// List of all stored transactions with search, filters, and add/delete affordances.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

/// Handles fetching transactions, filtering, and reacting to add/delete events.
class _TransactionsScreenState extends State<TransactionsScreen> {
  late Future<List<TransactionModel>> _transactionsFuture;
  Map<int, String> _categoryNames = {};
  List<CategoryModel> _categories = [];

  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedType; // null = all, 'expense', 'income', 'transfer'
  int? _selectedCategoryId; // null = all categories
  DateTimeRange? _dateRange;

  // Track if filters panel is expanded
  bool _filtersExpanded = false;

  /// Loads the first batch of transactions.
  @override
  void initState() {
    super.initState();
    _refreshTransactions();
    _loadCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  /// Loads categories for the filter dropdown.
  Future<void> _loadCategories() async {
    final categoryMaps = await CategoryRepository.getAllOrderedByUsage();
    setState(() {
      _categories = categoryMaps.map((m) => CategoryModel.fromMap(m)).toList();
    });
  }

  /// Reloads all transactions so the FutureBuilder updates.
  void _refreshTransactions() {
    setState(() {
      _transactionsFuture = _loadTransactionsWithCategories();
    });
  }

  /// Loads transactions and fetches category names for display.
  Future<List<TransactionModel>> _loadTransactionsWithCategories() async {
    final txns = await TransactionRepository.getAll();
    // Collect all category IDs that need name lookup
    final categoryIds = txns
        .where((t) => t.categoryId != null && t.categoryName == null)
        .map((t) => t.categoryId!)
        .toSet();
    if (categoryIds.isNotEmpty) {
      _categoryNames = await CategoryRepository.getNamesByIds(categoryIds);
    }
    return txns;
  }

  /// Returns the display name for a transaction's category.
  String _getCategoryDisplay(TransactionModel t) {
    if (t.categoryName != null && t.categoryName!.isNotEmpty) {
      return t.categoryName!;
    }
    if (t.categoryId != null && _categoryNames.containsKey(t.categoryId)) {
      return _categoryNames[t.categoryId]!;
    }
    return 'Uncategorized';
  }

  /// Filters the transaction list based on search query and filters.
  List<TransactionModel> _filterTransactions(List<TransactionModel> txns) {
    return txns.where((t) {
      // Search filter - matches description or merchant name
      if (_searchQuery.isNotEmpty) {
        final matchesDescription =
            t.description.toLowerCase().contains(_searchQuery);
        final matchesMerchant =
            t.merchantName?.toLowerCase().contains(_searchQuery) ?? false;
        final matchesCategory =
            _getCategoryDisplay(t).toLowerCase().contains(_searchQuery);
        if (!matchesDescription && !matchesMerchant && !matchesCategory) {
          return false;
        }
      }

      // Type filter
      if (_selectedType != null && t.type != _selectedType) {
        return false;
      }

      // Category filter
      if (_selectedCategoryId != null && t.categoryId != _selectedCategoryId) {
        return false;
      }

      // Date range filter
      if (_dateRange != null) {
        try {
          final txnDate = DateTime.parse(t.date);
          if (txnDate.isBefore(_dateRange!.start) ||
              txnDate.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
            return false;
          }
        } catch (_) {
          // If date parsing fails, include the transaction
        }
      }

      return true;
    }).toList();
  }

  /// Clears all active filters.
  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedType = null;
      _selectedCategoryId = null;
      _dateRange = null;
    });
  }

  /// Returns true if any filter is active.
  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedType != null ||
      _selectedCategoryId != null ||
      _dateRange != null;

  /// Shows the date range picker.
  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialRange = _dateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  /// Formats a date range for display.
  String _formatDateRange(DateTimeRange range) {
    final startStr =
        '${range.start.day}/${range.start.month}/${range.start.year}';
    final endStr = '${range.end.day}/${range.end.month}/${range.end.year}';
    return '$startStr - $endStr';
  }

  // --- UI ---
  /// Renders the transaction list, loading states, and add FAB.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Transactions"),
        actions: [
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all, size: 20),
              label: const Text('Clear'),
            ),
        ],
      ),
      body: FutureBuilder<List<TransactionModel>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allTxns = snapshot.data!;
          if (allTxns.isEmpty) {
            return const Center(child: Text("No transactions yet."));
          }

          final filteredTxns = _filterTransactions(allTxns);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                  ),
                ),
              ),

              // Filters section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter toggle button
                    InkWell(
                      onTap: () {
                        setState(() {
                          _filtersExpanded = !_filtersExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              _filtersExpanded
                                  ? Icons.filter_list_off
                                  : Icons.filter_list,
                              size: 20,
                              color: _hasActiveFilters
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Filters',
                              style: TextStyle(
                                fontWeight: _hasActiveFilters
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _hasActiveFilters
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                            if (_hasActiveFilters) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _countActiveFilters().toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Icon(
                              _filtersExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable filters
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _buildFiltersPanel(theme),
                      crossFadeState: _filtersExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),

              // Active filter chips (shown when collapsed)
              if (!_filtersExpanded && _hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _buildActiveFilterChips(theme),
                  ),
                ),

              // Results count
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  _hasActiveFilters
                      ? '${filteredTxns.length} of ${allTxns.length} transactions'
                      : '${allTxns.length} transactions • Hold to edit',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),

              // Transaction list
              Expanded(
                child: filteredTxns.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            const Text('No matching transactions'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredTxns.length,
                        itemBuilder: (context, index) {
                          final t = filteredTxns[index];
                          return _buildTransactionCard(t);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Counts the number of active filters.
  int _countActiveFilters() {
    int count = 0;
    if (_selectedType != null) count++;
    if (_selectedCategoryId != null) count++;
    if (_dateRange != null) count++;
    return count;
  }

  /// Builds the expandable filters panel.
  Widget _buildFiltersPanel(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Type filter
          Text(
            'Type',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              _buildTypeChip(null, 'All', theme),
              _buildTypeChip('expense', 'Expenses', theme),
              _buildTypeChip('income', 'Income', theme),
              _buildTypeChip('transfer', 'Transfers', theme),
            ],
          ),

          const SizedBox(height: 12),

          // Category filter
          Text(
            'Category',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<int?>(
            value: _selectedCategoryId,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            hint: const Text('All categories'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All categories'),
              ),
              ..._categories.map((cat) {
                return DropdownMenuItem<int?>(
                  value: cat.id,
                  child: Text(
                    cat.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategoryId = value;
              });
            },
          ),

          const SizedBox(height: 12),

          // Date range filter
          Text(
            'Date Range',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _dateRange != null
                        ? _formatDateRange(_dateRange!)
                        : 'Select dates',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              if (_dateRange != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _dateRange = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'Clear date filter',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a type filter chip.
  Widget _buildTypeChip(String? type, String label, ThemeData theme) {
    final isSelected = _selectedType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedType = selected ? type : null;
        });
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
    );
  }

  /// Builds the list of active filter chips.
  List<Widget> _buildActiveFilterChips(ThemeData theme) {
    final chips = <Widget>[];

    if (_selectedType != null) {
      chips.add(
        Chip(
          label: Text(_selectedType == 'expense'
              ? 'Expenses'
              : _selectedType == 'income'
                  ? 'Income'
                  : 'Transfers'),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() {
              _selectedType = null;
            });
          },
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (_selectedCategoryId != null) {
      final category = _categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => const CategoryModel(name: 'Unknown'),
      );
      chips.add(
        Chip(
          label: Text(category.name),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() {
              _selectedCategoryId = null;
            });
          },
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (_dateRange != null) {
      chips.add(
        Chip(
          label: Text(_formatDateRange(_dateRange!)),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() {
              _dateRange = null;
            });
          },
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return chips;
  }

  /// Builds a transaction card.
  Widget _buildTransactionCard(TransactionModel t) {
    final icon = t.type == 'expense'
        ? Icons.remove_circle
        : t.type == 'transfer'
            ? Icons.swap_horiz
            : Icons.add_circle;
    final color = t.type == 'expense'
        ? Colors.red
        : t.type == 'transfer'
            ? Colors.blue
            : Colors.green;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          t.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text("${t.date} • ${_getCategoryDisplay(t)}"),
        trailing: Text(
          (t.type == "expense" ? "-" : t.type == "transfer" ? "" : "+") +
              "\$${t.amount.abs().toStringAsFixed(2)}",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        onLongPress: () => _showEditOptions(t),
      ),
    );
  }

  // --- Add Transaction Dialog ---
  /// Quick dialog for inserting a manual transaction (debug/testing use).
  void _showAddTransactionDialog() async {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String type = "expense"; // default
    final dateController = TextEditingController(
        text: DateTime.now().toIso8601String().substring(0, 10));
    CategoryModel? selectedCategory;

    // Load categories for the dropdown, ordered by usage (most used first)
    final categoryMaps = await CategoryRepository.getAllOrderedByUsage();
    final categories = categoryMaps.map((m) => CategoryModel.fromMap(m)).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Transaction"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: "Description"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Amount"),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: "expense", child: Text("Expense")),
                        DropdownMenuItem(value: "income", child: Text("Income")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => type = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: "Type"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: "Date (YYYY-MM-DD)",
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CategoryModel>(
                      value: selectedCategory,
                      isExpanded: true,
                      hint: const Text("Select Category"),
                      items: categories.map((cat) {
                        return DropdownMenuItem<CategoryModel>(
                          value: cat,
                          child: Text(
                            cat.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCategory = value);
                      },
                      decoration: const InputDecoration(labelText: "Category"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || descController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please fill in description and amount")),
                      );
                      return;
                    }

                    final txn = TransactionModel(
                      description: descController.text,
                      amount: amount,
                      type: type,
                      date: dateController.text,
                      categoryId: selectedCategory?.id,
                      categoryName: selectedCategory?.name,
                    );

                    await TransactionRepository.insertManual(txn);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    _refreshTransactions();
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Edit Options Bottom Sheet ---
  /// Shows a bottom sheet with options to edit, change category, or delete.
  void _showEditOptions(TransactionModel txn) {
    final id = txn.id;
    if (id == null) return;

    final formattedAmount = txn.type == 'expense'
        ? "-\$${txn.amount.abs().toStringAsFixed(2)}"
        : "\$${txn.amount.abs().toStringAsFixed(2)}";
    final amountColor = txn.type == 'expense' ? Colors.red : Colors.green;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  txn.description.isEmpty ? "Transaction" : txn.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text("${txn.date} • ${_getCategoryDisplay(txn)}"),
                trailing: Text(
                  formattedAmount,
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Transaction'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditTransactionDialog(txn);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Transaction', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(txn);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // --- Edit Transaction Dialog ---
  /// Shows a dialog to edit all fields of a transaction.
  void _showEditTransactionDialog(TransactionModel txn) async {
    final id = txn.id;
    if (id == null) return;

    final descController = TextEditingController(text: txn.description);
    final amountController = TextEditingController(text: txn.amount.abs().toString());
    String type = txn.type;
    final dateController = TextEditingController(text: txn.date);

    // Load categories ordered by usage
    final categoryMaps = await CategoryRepository.getAllOrderedByUsage();
    final categories = categoryMaps.map((m) => CategoryModel.fromMap(m)).toList();

    // Find current category
    CategoryModel? selectedCategory;
    if (txn.categoryId != null) {
      try {
        selectedCategory = categories.firstWhere((c) => c.id == txn.categoryId);
      } catch (_) {
        // Category not found, leave as null
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Transaction"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: "Description"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Amount"),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: "expense", child: Text("Expense")),
                        DropdownMenuItem(value: "income", child: Text("Income")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => type = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: "Type"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: "Date (YYYY-MM-DD)",
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CategoryModel>(
                      value: selectedCategory,
                      isExpanded: true,
                      hint: const Text("Select Category"),
                      items: categories.map((cat) {
                        return DropdownMenuItem<CategoryModel>(
                          value: cat,
                          child: Text(
                            cat.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCategory = value);
                      },
                      decoration: const InputDecoration(labelText: "Category"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || descController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please fill in description and amount")),
                      );
                      return;
                    }

                    final updatedTxn = TransactionModel(
                      id: id,
                      description: descController.text,
                      amount: amount,
                      type: type,
                      date: dateController.text,
                      categoryId: selectedCategory?.id,
                      categoryName: selectedCategory?.name,
                      akahuId: txn.akahuId,
                      akahuHash: txn.akahuHash,
                      accountId: txn.accountId,
                      connectionId: txn.connectionId,
                      excluded: txn.excluded,
                    );

                    await TransactionRepository.insertManual(updatedTxn);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    _refreshTransactions();
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Confirm Delete ---
  /// Shows a confirmation dialog before deleting a transaction.
  void _confirmDelete(TransactionModel txn) {
    final id = txn.id;
    if (id == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Transaction"),
          content: Text(
            'Are you sure you want to delete "${txn.description.isEmpty ? "this transaction" : txn.description}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await TransactionRepository.delete(id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                _refreshTransactions();
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}
