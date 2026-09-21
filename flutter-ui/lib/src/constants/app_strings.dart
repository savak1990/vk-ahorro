class AppStrings {
  static const String appTitle = 'Ahorro App';
  static const String loginTitle = 'Login';
  static const String homeTitle = 'Home';
  static const String loginButton = 'Sign In';
  static const String usernameHint = 'Username';
  static const String passwordHint = 'Password';
  static const String logoutButton = 'Logout';
  // Add more strings as needed

  // Balances screen
  static const String balancesTitle = 'Balances';
  static const String balancesSubtitle =
      'places to keep funds: wallets, pockets, bank accounts';
  static const String addBalanceTooltip = 'Add balance';
  static const String noBalances = 'You have no balances yet';
  static const String errorPrefix = 'Error:';

  // Add balance form
  static const String addBalanceTitle = 'Add balance';
  static const String currencyLabel = 'Currency';
  static const String balanceNameLabel = 'Balance name';
  static const String descriptionLabel = 'Description (optional)';
  static const String titleRequired = 'Title is required';
  static const String createButton = 'Create';

  // Home page
  static const String financialOverviewTitle = 'Financial Overview';
  static const String expenseTitle = 'Expense';
  static const String incomeTitle = 'Income';
  static const String monthYearDatePattern = 'MMMM, yyyy';
  static String helloUser(String name) => 'Hello, $name!';

  // Account page
  static const String accountTitle = 'Account';
  static const String generalTitle = 'General';

  // Transactions page
  static const String transactionsTitle = 'Transactions';
  static const String groupToday = 'Today';
  static const String groupYesterday = 'Yesterday';
  static const String groupPrevious7Days = 'Previous 7 Days';
  static const String groupEarlier = 'Earlier';

  // Transaction details page
  static const String transactionDetailsInformationTitle = 'Information';
  static const String transactionDetailsPeriodTitle = 'Period';
  static const String transactionDetailsEntriesTitle = 'Entries';
  static const String transactionDetailsWalletTitle = 'Wallet';
  static const String transactionDetailsWalletUnknown = 'unknown';
  static const String transactionDetailsWalletChangeNotAllowed =
      'Changing wallet is available only for income and expense';
  static const String transactionDetailsWalletCreateMoreInfo =
      'Only one wallet is available. Create another one to change';
  static const String transactionDetailsSelectWalletTitle = 'Select wallet';
  static const String transactionDetailsConfirm = 'Confirm';
  static const String transactionDetailsCancel = 'Cancel';
  static const String transactionDetailsUpdated = 'Wallet updated';
  static const String transactionDetailsUpdateFailedPrefix = 'Update failed:';
  static const String transactionDetailsEdit = 'Edit';
  static const String transactionDetailsDelete = 'Delete';
  static const String transactionDetailsDeleteConfirmTitle = 'Delete Entry';
  static const String transactionDetailsDeleteConfirmMessage =
      'Are you sure you want to delete this entry?';
  static const String transactionDetailsDeleteConfirmButton = 'Delete';
  static const String transactionDetailsEntryDeleted =
      'Entry deleted successfully';
  static const String transactionDetailsCannotDeleteLastEntry =
      'Cannot delete the last remaining entry';

  // Transaction deletion
  static const String transactionDeleteButton = 'Delete';
  static const String transactionDeleteConfirmTitle = 'Delete Transaction';
  static const String transactionDeleteConfirmMessage =
      'Are you sure you want to delete this transaction? This action cannot be undone.';
  static const String transactionDeleteConfirmButton = 'Delete';
  static const String transactionDeleted = 'Transaction deleted successfully';
}
