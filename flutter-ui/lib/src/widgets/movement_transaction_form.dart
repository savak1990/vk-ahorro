import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/balance.dart';
import '../providers/balances_provider.dart';
import '../widgets/add_balance_form.dart';
import '../widgets/balance_chips.dart';
import 'package:formz/formz.dart';

class MovementTransactionFormData {
  final String fromBalanceId;
  final String toBalanceId;
  final double amount;
  final double? convertedAmount;
  final DateTime date;

  MovementTransactionFormData({
    required this.fromBalanceId,
    required this.toBalanceId,
    required this.amount,
    this.convertedAmount,
    required this.date,
  });
}

class MovementTransactionForm extends StatefulWidget {
  final ValueNotifier<FormzSubmissionStatus> formStatus;
  final Function(MovementTransactionFormData) onSubmit;
  final bool isLoading;

  const MovementTransactionForm({
    super.key,
    required this.formStatus,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  MovementTransactionFormState createState() => MovementTransactionFormState();
}

class MovementTransactionFormState extends State<MovementTransactionForm> {
  String? _selectedFromBalanceId;
  String? _selectedToBalanceId;
  final _amountController = TextEditingController();
  final _convertedAmountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _showConvertedAmount = false;

  @override
  void initState() {
    super.initState();
    _loadBalances();
    
    // Добавляем слушатели для обновления статуса формы
    _amountController.addListener(_updateFormStatus);
    _convertedAmountController.addListener(_updateFormStatus);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateFormStatus);
    _convertedAmountController.removeListener(_updateFormStatus);
    _amountController.dispose();
    _convertedAmountController.dispose();
    super.dispose();
  }

  void _loadBalances() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<BalancesProvider>(context, listen: false);
      final balances = provider.balances;
      
      if (balances.isNotEmpty) {
        setState(() {
          _selectedFromBalanceId = balances.first.id;
        });
        _updateFormStatus();
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showAddBalanceForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: AddBalanceForm(),
      ),
    ).then((_) {
      // Refresh balances after adding new one
    Provider.of<BalancesProvider>(context, listen: false).loadBalances(forceRefresh: true);
    });
  }

  void _onFromBalanceChanged(String? balanceId) {
    setState(() {
      _selectedFromBalanceId = balanceId;
      _updateConvertedAmountVisibility();
    });
    _updateFormStatus();
  }

  void _onToBalanceChanged(String? balanceId) {
    setState(() {
      _selectedToBalanceId = balanceId;
      _updateConvertedAmountVisibility();
    });
    _updateFormStatus();
  }

  void _updateConvertedAmountVisibility() {
    if (_selectedFromBalanceId != null && _selectedToBalanceId != null) {
      final fromBalance = _getBalanceById(_selectedFromBalanceId!);
      final toBalance = _getBalanceById(_selectedToBalanceId!);
      
      setState(() {
        _showConvertedAmount = fromBalance?.currency != toBalance?.currency;
      });
    } else {
      setState(() {
        _showConvertedAmount = false;
      });
    }
    _updateFormStatus();
  }

  void _updateFormStatus() {
    // Проверяем, что выбраны оба баланса
    final balancesSelected = _selectedFromBalanceId != null && _selectedToBalanceId != null;
    
    // Проверяем, что заполнена сумма
    final amountValid = _amountController.text.isNotEmpty && 
                       double.tryParse(_amountController.text) != null &&
                       double.tryParse(_amountController.text)! > 0;
    
    // Проверяем converted amount если нужно
    bool convertedAmountValid = true;
    if (_showConvertedAmount) {
      convertedAmountValid = _convertedAmountController.text.isNotEmpty && 
                           double.tryParse(_convertedAmountController.text) != null &&
                           double.tryParse(_convertedAmountController.text)! > 0;
    }
    
    final isValid = balancesSelected && amountValid && convertedAmountValid;
    widget.formStatus.value = isValid ? FormzSubmissionStatus.success : FormzSubmissionStatus.initial;
  }

  Balance? _getBalanceById(String id) {
    final provider = Provider.of<BalancesProvider>(context, listen: false);
    try {
      return provider.balances.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  void submit() {
    if (_selectedFromBalanceId == null || _selectedToBalanceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both balances')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    double? convertedAmount;
    if (_showConvertedAmount) {
      convertedAmount = double.tryParse(_convertedAmountController.text);
      if (convertedAmount == null || convertedAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid converted amount')),
        );
        return;
      }
    }

    final data = MovementTransactionFormData(
      fromBalanceId: _selectedFromBalanceId!,
      toBalanceId: _selectedToBalanceId!,
      amount: amount,
      convertedAmount: convertedAmount,
      date: _selectedDate,
    );

    widget.onSubmit(data);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BalancesProvider>(
      builder: (context, provider, _) {
        final balances = provider.balances;

        if (balances.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (balances.length < 2) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
                  return Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: scheme.onSurfaceVariant,
                  );
                }),
                const SizedBox(height: 16),
                Text(
                  'Minimum 2 balances required',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You need at least 2 active balances to make transfers between them.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                    child: Builder(builder: (context) {
                      final scheme = Theme.of(context).colorScheme;
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _showAddBalanceForm,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Balance'),
                      );
                    }),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // From Balance Selection
              BalanceChips(
                selectedBalanceId: _selectedFromBalanceId,
                onBalanceSelected: _onFromBalanceChanged,
                title: 'From Balance',
                allowDeselect: false,
              ),
              const SizedBox(height: 24),

              // To Balance Selection
              BalanceChips(
                selectedBalanceId: _selectedToBalanceId,
                onBalanceSelected: _onToBalanceChanged,
                title: 'To Balance',
                allowDeselect: false,
                showAddButton: false, // Не показываем кнопку добавления для второго баланса
                excludeBalanceIds: _selectedFromBalanceId != null ? [_selectedFromBalanceId!] : null,
              ),
              const SizedBox(height: 24),

              // Amount Field
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixText: _selectedFromBalanceId != null 
                    ? '${_getBalanceById(_selectedFromBalanceId!)?.currency} '
                    : '',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),

              // Converted Amount Field (if different currencies)
              if (_showConvertedAmount) ...[
                TextFormField(
                  controller: _convertedAmountController,
                  decoration: InputDecoration(
                    labelText: 'Converted Amount',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixText: _selectedToBalanceId != null 
                      ? '${_getBalanceById(_selectedToBalanceId!)?.currency} '
                      : '',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
              ],

              // Date Field
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text('${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 