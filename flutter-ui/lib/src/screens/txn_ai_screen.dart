import 'package:flutter/material.dart';
import '../services/openai_agent_service.dart';
import 'package:provider/provider.dart';
import '../providers/balances_provider.dart';
import '../models/balance.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../models/transaction_type.dart';
import 'dart:convert';
import '../models/transaction_entry.dart';
import '../providers/transaction_entries_provider.dart';

class TxnAiScreen extends StatefulWidget {
  const TxnAiScreen({super.key});

  @override
  State<TxnAiScreen> createState() => _TxnAiScreenState();
}

class _TxnAiScreenState extends State<TxnAiScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isInputNotEmpty = false;
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  final OpenAIAgentService _agentService = OpenAIAgentService();
  List<Category>? _categories;
  bool _categoriesLoading = false;
  String? _categoriesError;
  _DraftExpense? _draftExpense;
  final bool _awaitingExpenseConfirmation = false;
  bool _creatingExpense = false;

  static const _expenseFunction = {
    'name': 'create_expense_transaction',
    'description': 'Create an expense transaction for a user. Supports multiple items.',
    'parameters': {
      'type': 'object',
      'properties': {
        'items': {
          'type': 'array',
          'description': 'List of expense items',
          'items': {
            'type': 'object',
            'properties': {
              'amount': {
                'type': 'number',
                'description': 'Expense amount in euros (not cents), e.g. 10.50'
              },
              'category': {'type': 'string', 'description': 'Expense category'},
              'description': {'type': 'string', 'description': 'Description', 'nullable': true},
            },
            'required': ['amount', 'category']
          }
        },
        'balance': {'type': 'string', 'description': 'Account to withdraw from'},
      },
      'required': ['items', 'balance']
    }
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _isInputNotEmpty = _controller.text.trim().isNotEmpty;
      });
    });
    _loadCategories();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _categoriesLoading = true;
      _categoriesError = null;
    });
    try {
      final resp = await ApiService.getCategories();
      setState(() {
        _categories = resp.categories;
      });
    } catch (e) {
      setState(() {
        _categoriesError = e.toString();
      });
    } finally {
      setState(() {
        _categoriesLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final balancesProvider = Provider.of<BalancesProvider>(context);
    final balances = balancesProvider.balances;
    final isBalancesLoading = balancesProvider.isLoading;
    final balancesError = balancesProvider.error;

    final isDataLoading = isBalancesLoading || _categoriesLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TxnAi'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (isDataLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (balancesError != null || _categoriesError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading data: ${balancesError ?? ''} ${_categoriesError ?? ''}'),
            )
          else ...[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(msg['content'] ?? ''),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Enter message...',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  if (!_isInputNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.mic),
                      onPressed: () {
                        // TODO: обработка голосового ввода
                      },
                    ),
                  if (_isInputNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final balancesProvider = Provider.of<BalancesProvider>(context, listen: false);
    final balances = balancesProvider.balances;
    final categories = _categories ?? [];

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _controller.clear();
    });

    // Формируем системное сообщение
    final systemMsg = _buildSystemMessage(balances, categories);
    final messages = [
      {'role': 'system', 'content': systemMsg},
      ..._messages,
    ];

    try {
      final response = await _agentService.sendMessage(
        messages,
        functions: [_expenseFunction],
      );
      // Если ассистент вернул function_call — вызываем функцию
      if (response.functionCall != null && response.functionCall['name'] == 'create_expense_transaction') {
        final args = response.functionCall['arguments'];
        final parsed = args is String ? jsonDecode(args) : args;
        debugPrint('function_call arguments: $parsed');
        // Новый формат: items (array)
        if (parsed['items'] != null && parsed['items'] is List) {
          final items = List<Map<String, dynamic>>.from(parsed['items']);
          final balanceName = parsed['balance']?.toString() ?? '';
          debugPrint('Parsed items: $items, balance: $balanceName');
          final balances = Provider.of<BalancesProvider>(context, listen: false).balances;
          final categories = _categories ?? [];
          final balance = balances.firstWhere(
            (b) => b.title.toLowerCase() == balanceName.toLowerCase(),
            orElse: () => balances.firstWhere(
              (b) => b.title.toLowerCase().contains(balanceName.toLowerCase()),
              orElse: () => Balance(balanceId: '', groupId: '', userId: '', title: '', currency: '', description: '', rank: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()),
            ),
          );
          if (balance.balanceId.isEmpty) {
            setState(() {
              _messages.add({'role': 'assistant', 'content': 'Could not unambiguously determine the account. Please clarify.'});
            });
            return;
          }
          // Собираем список TransactionEntry
          final entries = <TransactionEntry>[];
          for (final item in items) {
            final amount = item['amount'] is String ? double.tryParse(item['amount']) : item['amount']?.toDouble();
            final categoryName = item['category']?.toString() ?? '';
            final description = item['description']?.toString();
            final category = categories.firstWhere(
              (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
              orElse: () => categories.firstWhere(
                (c) => c.name.toLowerCase().contains(categoryName.toLowerCase()),
                orElse: () => Category(categoryId: '', name: '', description: '', rank: 0, categoryGroupId: '', categoryGroupName: '', categoryGroupRank: 0),
              ),
            );
            if (amount != null && category.id.isNotEmpty) {
              entries.add(TransactionEntry(
                description: description ?? category.name,
                amount: amount,
                categoryId: category.id,
              ));
            }
          }
          if (entries.isEmpty) {
            setState(() {
              _messages.add({'role': 'assistant', 'content': 'Could not parse any valid items. Please clarify.'});
            });
            return;
          }
          await _createExpenseFunction(entries, balance.balanceId);
        } else {
          // Старый формат (одна трата)
          final amount = parsed['amount'] is String ? double.tryParse(parsed['amount']) : parsed['amount']?.toDouble();
          final categoryName = parsed['category']?.toString() ?? '';
          final balanceName = parsed['balance']?.toString() ?? '';
          final description = parsed['description']?.toString();
          debugPrint('amount: $amount, category: $categoryName, balance: $balanceName, description: $description');
          final categories = _categories ?? [];
          final balances = Provider.of<BalancesProvider>(context, listen: false).balances;
          final category = categories.firstWhere(
            (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
            orElse: () => categories.firstWhere(
              (c) => c.name.toLowerCase().contains(categoryName.toLowerCase()),
              orElse: () => Category(categoryId: '', name: '', description: '', rank: 0, categoryGroupId: '', categoryGroupName: '', categoryGroupRank: 0),
            ),
          );
          final balance = balances.firstWhere(
            (b) => b.title.toLowerCase() == balanceName.toLowerCase(),
            orElse: () => balances.firstWhere(
              (b) => b.title.toLowerCase().contains(balanceName.toLowerCase()),
              orElse: () => Balance(balanceId: '', groupId: '', userId: '', title: '', currency: '', description: '', rank: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()),
            ),
          );
          if (amount != null && category.id.isNotEmpty && balance.balanceId.isNotEmpty) {
            await _createExpenseFunction([
              TransactionEntry(description: description ?? category.name, amount: amount, categoryId: category.id)
            ], balance.balanceId);
          } else {
            setState(() {
              _messages.add({'role': 'assistant', 'content': 'Could not unambiguously determine the amount, category, or account. Please clarify.'});
            });
          }
        }
      } else if (response.content != null) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response.content!});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Error: $e'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createExpenseFunction(List<TransactionEntry> entries, String balanceId) async {
    setState(() { _creatingExpense = true; });
    try {
      final provider = Provider.of<TransactionEntriesProvider>(context, listen: false);
      await provider.createTransaction(
        type: TransactionType.expense,
        date: DateTime.now(),
        categoryId: entries.first.categoryId,
        balanceId: balanceId,
        description: entries.first.description,
        transactionEntriesParam: entries,
      );
      setState(() {
        _messages.add({'role': 'assistant', 'content': '✅ Expense created successfully!'});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Error while creating expense: $e'});
      });
    } finally {
      setState(() { _creatingExpense = false; });
    }
  }

  String _buildSystemMessage(List<Balance> balances, List<Category> categories) {
    final balancesStr = balances.isEmpty
        ? 'No balances.'
        : balances.map((b) => '- "${b.title}" (${b.currency})').join('\n');
    final categoriesStr = categories.isEmpty
        ? 'No categories.'
        : categories.map((c) => '- ${c.name}').join('\n');
    return 'User balances:\n$balancesStr\n\nAvailable categories:\n$categoriesStr';
  }

  bool _isExpenseIntent(String text) {
    final lower = text.toLowerCase();
    return lower.contains('расход') || lower.contains('потратил') || lower.contains('потратила') || lower.contains('купил') || lower.contains('запиши трату') || lower.contains('expense');
  }

  _DraftExpense? _updateDraftExpense(_DraftExpense? draft, String text, List<Balance> balances, List<Category> categories) {
    draft ??= _DraftExpense();
    // Парсим сумму
    final amountMatch = RegExp(r'(\d+[\.,]?\d*)').firstMatch(text.replaceAll(',', '.'));
    if (amountMatch != null && draft.amount == null) {
      draft.amount = double.tryParse(amountMatch.group(1)!);
    }
    // Парсим категорию
    for (final c in categories) {
      if (text.toLowerCase().contains(c.name.toLowerCase()) && draft.categoryId == null) {
        draft.categoryId = c.id;
        break;
      }
    }
    // Парсим счет
    for (final b in balances) {
      if (text.toLowerCase().contains(b.title.toLowerCase()) && draft.balanceId == null) {
        draft.balanceId = b.balanceId;
        break;
      }
    }
    // Описание
    if (draft.description == null && text.length > 3 && !text.contains(RegExp(r'\d'))) {
      draft.description = text;
    }
    return draft;
  }
}

class _DraftExpense {
  double? amount;
  String? categoryId;
  String? balanceId;
  String? description;

  bool get isComplete => amount != null && categoryId != null && balanceId != null;

  String summary(List<Balance> balances, List<Category> categories) {
    final category = categories.firstWhere((c) => c.id == categoryId, orElse: () => Category(categoryId: '', name: '—', description: '', rank: 0, categoryGroupId: '', categoryGroupName: '', categoryGroupRank: 0));
    final balance = balances.firstWhere((b) => b.balanceId == balanceId, orElse: () => Balance(balanceId: '', groupId: '', userId: '', title: '—', currency: '', description: '', rank: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
    return 'Сумма: ${amount?.toStringAsFixed(2) ?? '—'}\nКатегория: ${category.name}\nСчет: ${balance.title}\nОписание: ${description ?? '—'}';
  }

  String nextPrompt(List<Balance> balances, List<Category> categories) {
    if (amount == null) return 'Укажите сумму расхода.';
    if (categoryId == null) return 'Укажите категорию расхода. Доступные: ${categories.map((c) => c.name).join(', ')}';
    if (balanceId == null) return 'Укажите счет, с которого списать расход. Доступные: ${balances.map((b) => b.title).join(', ')}';
    return 'Добавьте описание (необязательно) или напишите "готово".';
  }
} 