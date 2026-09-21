enum CurrencyCode { usd, eur, gbp, jpy, aud, uah, byn }

CurrencyCode toCurrencyCode(String input) {
  final code = input.toUpperCase().trim();
  switch (code) {
    case 'USD':
      return CurrencyCode.usd;
    case 'EUR':
      return CurrencyCode.eur;
    case 'GBP':
      return CurrencyCode.gbp;
    case 'JPY':
      return CurrencyCode.jpy;
    case 'AUD':
      return CurrencyCode.aud;
    case 'UAH':
      return CurrencyCode.uah;
    case 'BYN':
      return CurrencyCode.byn;
    default:
      throw ArgumentError('Unknown currency code: $input');
  }
}

String fromCurrencyCode(CurrencyCode code) {
  switch (code) {
    case CurrencyCode.usd:
      return 'USD';
    case CurrencyCode.eur:
      return 'EUR';
    case CurrencyCode.gbp:
      return 'GBP';
    case CurrencyCode.jpy:
      return 'JPY';
    case CurrencyCode.aud:
      return 'AUD';
    case CurrencyCode.uah:
      return 'UAH';
    case CurrencyCode.byn:
      return 'BYN';
  }
}

String getCurrencySymbol(CurrencyCode currency) {
  switch (currency) {
    case CurrencyCode.usd:
      return '\$';
    case CurrencyCode.eur:
      return '€';
    case CurrencyCode.gbp:
      return '£';
    case CurrencyCode.jpy:
      return '¥';
    case CurrencyCode.aud:
      return 'A\$';
    case CurrencyCode.uah:
      return '₴';
    case CurrencyCode.byn:
      return 'Br';
  }
}

String formatAmountInt(int amount, CurrencyCode currency) {
  final symbol = getCurrencySymbol(currency);
  final formattedAmount = (amount / 100).toStringAsFixed(2);
  return '$symbol$formattedAmount';
}

String formatAmountDouble(double amount, CurrencyCode currency) {
  final symbol = getCurrencySymbol(currency);
  return '$symbol${amount.toStringAsFixed(2)}';
}
