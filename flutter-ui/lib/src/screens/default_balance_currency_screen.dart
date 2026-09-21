import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/balances_provider.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class DefaultBalanceCurrencyScreen extends StatefulWidget {
  const DefaultBalanceCurrencyScreen({super.key});

  @override
  State<DefaultBalanceCurrencyScreen> createState() =>
      _DefaultBalanceCurrencyScreenState();
}

class _DefaultBalanceCurrencyScreenState
    extends State<DefaultBalanceCurrencyScreen> {
  String? _selectedCurrency;
  bool _isLoading = false;
  String? _error;
  final _currencies = ['EUR', 'USD', 'GBP', 'UAH', 'BYN'];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BalancesProvider>(context, listen: false);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'What is your default currency?',
                style: AppTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                children: _currencies
                    .map(
                      (currency) => ChoiceChip(
                        label: Text(currency),
                        selected: _selectedCurrency == currency,
                        onSelected: (selected) {
                          setState(() => _selectedCurrency = currency);
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed: _selectedCurrency == null || _isLoading
                    ? null
                    : () async {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        try {
                          final userId = await AuthService.getUserId();
                          const groupId = AuthService.groupId;
                          await provider.createBalance(
                            userId: userId,
                            groupId: groupId,
                            currency: _selectedCurrency!,
                            title: 'Default',
                          );
                          if (mounted)
                            Navigator.of(context).pushReplacementNamed('/');
                        } catch (e) {
                          setState(() {
                            _error = e.toString();
                          });
                        } finally {
                          if (mounted)
                            setState(() {
                              _isLoading = false;
                            });
                        }
                      },
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create balance'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
