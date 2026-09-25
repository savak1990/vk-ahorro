class AppConfig {

  static const String baseUrl = String.fromEnvironment('API_BASE_URL');

  static const String transactionsEndpoint = '/transactions';
  static const String transactionsStatsEndpoint = '/transactions/stats';
  static const String categoriesEndpoint = '/categories';
  static const String balancesEndpoint = '/balances';
  static const String merchantsEndpoint = '/merchants';

  static String get apiUrl => baseUrl;
  static String get transactionsUrl => '$baseUrl$transactionsEndpoint';
  static String get transactionsStatsUrl => '$baseUrl$transactionsStatsEndpoint';
  static String get categoriesUrl => '$baseUrl$categoriesEndpoint';
  static String get balancesUrl => '$baseUrl$balancesEndpoint';
  static String get merchantsUrl => '$baseUrl$merchantsEndpoint';
}
