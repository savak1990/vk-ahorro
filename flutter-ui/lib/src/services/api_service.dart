import 'dart:convert';
import 'package:ahorro_ui/src/models/currencies.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'operation_id_service.dart';
import '../services/auth_service.dart';
import '../services/api_logger.dart';

import '../config/app_config.dart';
import '../models/transaction_type.dart';
import '../models/balance.dart';
import '../models/transaction_entry.dart';
import '../models/transactions_response.dart';
import '../models/transaction_entry_data.dart';
import '../models/categories_response.dart';
import '../models/transaction_update_payload.dart';
import '../models/transaction_stats.dart';

class ApiService {
  // Centralized auth headers builder
  static Future<Map<String, String>> _buildAuthHeaders({
    bool includeJson = false,
    String? requestId,
  }) async {
    final session = await Amplify.Auth.fetchAuthSession();
    if (!session.isSignedIn) {
      throw Exception('User is not signed in');
    }
    final token =
        (session as CognitoAuthSession).userPoolTokensResult.value.idToken.raw;
    return {
      if (includeJson) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (requestId != null) 'X-Request-Id': requestId,
    };
  }

  static Future<void> postTransaction({
    required TransactionType type,
    double? amount,
    required DateTime date,
    required String categoryId,
    required String balanceId,
    String? description,
    String? merchant,
    List<TransactionEntry>? transactionEntriesParam,
  }) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'postTransaction';

    try {
      ApiLogger.logOperationStart(operation, {
        'type': type.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'categoryId': categoryId,
        'balanceId': balanceId,
        'description': description,
        'merchant': merchant,
        'entriesCount': transactionEntriesParam?.length ?? 1,
      });

      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        throw Exception('User is not signed in');
      }

      final userId = await AuthService.getUserId();
      final url = Uri.parse(AppConfig.transactionsUrl);
      final operationId = generateOperationId();
      final headers = await _buildAuthHeaders(
        includeJson: true,
        requestId: operationId,
      );

      // Form transactionEntries from passed data or create single element
      final entries =
          transactionEntriesParam ??
          [
            TransactionEntry(
              description: description ?? '',
              amount: ((amount ?? 0.0) * 100).round(),
              categoryId: categoryId,
            ),
          ];

      final bodyMap = <String, dynamic>{
        'userId': userId,
        'groupId': '',
        'type': type.name,
        'operationId': operationId,
        'approvedAt': date.toUtc().toIso8601String(),
        'transactedAt': date.toUtc().toIso8601String(),
      };
      if (balanceId.isNotEmpty) {
        bodyMap['balanceId'] = balanceId;
      }
      if (merchant != null && merchant.isNotEmpty) {
        bodyMap['merchant'] = merchant;
      }
      if (entries.isNotEmpty) {
        bodyMap['transactionEntries'] = entries.map((e) => e.toJson()).toList();
      }

      final body = json.encode(bodyMap);

      ApiLogger.logRequest(
        method: 'POST',
        url: url.toString(),
        headers: headers,
        body: bodyMap,
        operation: operation,
      );

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 25));

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'POST',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to post transaction. Status code: ${response.statusCode}',
        );
      }

      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
      return json.decode(response.body);
    } catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'POST',
        url: AppConfig.transactionsUrl,
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error posting transaction: $e');
      rethrow;
    }
  }

  static Future<void> postMovementTransaction({
    required String fromBalanceId,
    required String toBalanceId,
    required double amount,
    double? convertedAmount,
    required DateTime date,
    String? description,
  }) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'postMovementTransaction';

    try {
      ApiLogger.logOperationStart(operation, {
        'fromBalanceId': fromBalanceId,
        'toBalanceId': toBalanceId,
        'amount': amount,
        'convertedAmount': convertedAmount,
        'date': date.toIso8601String(),
        'description': description,
      });

      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        throw Exception('User is not signed in');
      }

      final userId = await AuthService.getUserId();
      final url = Uri.parse(AppConfig.transactionsUrl);
      final requestId = generateOperationId();
      final headers = await _buildAuthHeaders(
        includeJson: true,
        requestId: requestId,
      );

      // Create two transactions: move_out and move_in
      final moveOutTransaction = {
        'userId': userId,
        'balanceId': fromBalanceId,
        'type': 'move_out',
        'transactedAt': date.toUtc().toIso8601String(),
        'transactionEntries': [
          {
            'description': description ?? 'Transfer to another account',
            'amount': (amount * 100).round(), // Convert to cents
          },
        ],
      };

      final moveInTransaction = {
        'userId': userId,
        'balanceId': toBalanceId,
        'type': 'move_in',
        'transactedAt': date.toUtc().toIso8601String(),
        'transactionEntries': [
          {
            'description': description ?? 'Transfer from another account',
            'amount':
                (convertedAmount != null ? convertedAmount * 100 : amount * 100)
                    .round(), // Use converted amount if available
          },
        ],
      };

      final bodyMap = {
        'transactions': [moveOutTransaction, moveInTransaction],
      };

      final body = json.encode(bodyMap);

      ApiLogger.logRequest(
        method: 'POST',
        url: url.toString(),
        headers: headers,
        body: bodyMap,
        operation: operation,
      );

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 25));

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'POST',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to post movement transaction. Status code: ${response.statusCode}',
        );
      }

      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
      return json.decode(response.body);
    } catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'POST',
        url: AppConfig.transactionsUrl,
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error posting movement transaction: $e');
      rethrow;
    }
  }

  static Future<TransactionsResponse> getTransactions() async {
    final stopwatch = Stopwatch()..start();
    const operation = 'getTransactions';

    try {
      ApiLogger.logOperationStart(operation);

      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        throw Exception('User is not signed in');
      }

      final userId = await AuthService.getUserId();
      final base = Uri.parse(AppConfig.transactionsUrl);
      final url = base.replace(queryParameters: {'userId': userId});
      final headers = await _buildAuthHeaders();

      ApiLogger.logRequest(
        method: 'GET',
        url: url.toString(),
        headers: headers,
        operation: operation,
      );

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 25));

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to get transactions. Status code: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);
      final items = data['items'] as List;

      final transactionEntries = items.map((item) {
        // Handle amount as string or number
        double amount;
        if (item['amount'] is String) {
          amount = double.parse(item['amount']);
        } else {
          amount = (item['amount'] as num).toDouble();
        }

        return TransactionEntryData(
          transactionId: item['transactionId'],
          transactionEntryId: item['transactionEntryId'],
          type: item['type'],
          amount: amount / 100, // Divide by 100 for display in euros
          groupId: item['groupId'] ?? '',
          userId: item['userId'] ?? '',
          balanceId: item['balanceId'] ?? '',
          balanceTitle: item['balanceTitle'] ?? '',
          balanceCurrency: item['balanceCurrency'] ?? '',
          categoryName: item['categoryName'] ?? '',
          categoryImageUrl: item['categoryImageUrl'],
          merchantName: item['merchantName'] ?? '',
          name: item['name'] ?? '',
          merchantImageUrl: item['merchantImageUrl'],
          operationId: item['operationId'] ?? '',
          approvedAt:
              DateTime.tryParse(item['approvedAt'] ?? '') ?? DateTime.now(),
          transactedAt:
              DateTime.tryParse(item['transactedAt'] ?? '') ?? DateTime.now(),
        );
      }).toList();

      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
      return TransactionsResponse(
        transactionEntries: transactionEntries,
        nextToken: data['nextToken'],
      );
    } on Exception catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'GET',
        url: '${AppConfig.transactionsUrl}?userId={userId}',
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error getting transactions: $e');
      rethrow;
    }
  }

  static Future<CategoriesResponse> getCategories() async {
    final stopwatch = Stopwatch()..start();
    const operation = 'getCategories';

    try {
      ApiLogger.logOperationStart(operation);

      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        throw Exception('User is not signed in');
      }

      final cognitoSession = session as CognitoAuthSession;
      final token = cognitoSession.userPoolTokensResult.value.idToken.raw;

      final url = Uri.parse(AppConfig.categoriesUrl);
      final headers = await _buildAuthHeaders();

      ApiLogger.logRequest(
        method: 'GET',
        url: url.toString(),
        headers: headers,
        operation: operation,
      );

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 25));

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to get categories. Status code: ${response.statusCode}. Response: ${response.body}',
        );
      }

      final data = json.decode(response.body);
      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
      return CategoriesResponse.fromJson(data);
    } on Exception catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'GET',
        url: AppConfig.categoriesUrl,
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error getting categories: $e');
      rethrow;
    }
  }

  static Future<List<Balance>> getBalances() async {
    final stopwatch = Stopwatch()..start();
    const operation = 'getBalances';

    try {
      ApiLogger.logOperationStart(operation);

      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        throw Exception('User is not signed in');
      }
      final userId = await AuthService.getUserId();
      final base = Uri.parse(AppConfig.balancesUrl);
      final url = base.replace(queryParameters: {'userId': userId});
      final headers = await _buildAuthHeaders();

      ApiLogger.logRequest(
        method: 'GET',
        url: url.toString(),
        headers: headers,
        operation: operation,
      );

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 25));

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to get balances. Status code: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);
      final balances = data['items'] as List? ?? [];
      final result = balances.map((e) => Balance.fromJson(e)).toList();

      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'GET',
        url: '${AppConfig.baseUrl}/balances?userId={userId}',
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error getting balances: $e');
      rethrow;
    }
  }

  static Future<dynamic> postBalance({
    required String userId,
    required String groupId,
    required String currency,
    required String title,
    String? description,
  }) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'postBalance';

    try {
      ApiLogger.logOperationStart(operation, {
        'userId': userId,
        'groupId': groupId,
        'currency': currency,
        'title': title,
        'description': description,
      });

      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        throw Exception('User is not signed in');
      }
      final cognitoSession = session as CognitoAuthSession;
      final token = cognitoSession.userPoolTokensResult.value.idToken.raw;

      final url = Uri.parse('${AppConfig.baseUrl}/balances');
      final headers = await _buildAuthHeaders(includeJson: true);
      final body = json.encode({
        'userId': userId,
        'groupId': groupId,
        'currency': currency,
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
      });

      ApiLogger.logRequest(
        method: 'POST',
        url: url.toString(),
        headers: headers,
        body: body,
        operation: operation,
      );

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 25));

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'POST',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to create balance. Status code: ${response.statusCode}',
        );
      }

      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
      return json.decode(response.body);
    } catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'POST',
        url: '${AppConfig.baseUrl}/balances',
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error creating balance: $e');
      rethrow;
    }
  }

  static Future<void> deleteBalance(String balanceId) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'deleteBalance';

    try {
      ApiLogger.logOperationStart(operation, {'balanceId': balanceId});

      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) throw Exception('User is not signed in');
      final cognitoSession = session as CognitoAuthSession;
      final token = cognitoSession.userPoolTokensResult.value.idToken.raw;

      final url = Uri.parse('${AppConfig.baseUrl}/balances/$balanceId');
      final headers = {'Authorization': 'Bearer $token'};

      ApiLogger.logRequest(
        method: 'DELETE',
        url: url.toString(),
        headers: headers,
        operation: operation,
      );

      final response = await http.delete(url, headers: headers);

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'DELETE',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to delete balance. Status code: ${response.statusCode}',
        );
      }

      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
    } catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'DELETE',
        url: '${AppConfig.baseUrl}/balances/$balanceId',
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getTransactionById(
    String transactionId,
  ) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'getTransactionById';

    try {
      ApiLogger.logOperationStart(operation, {'transactionId': transactionId});

      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        throw Exception('User is not signed in');
      }
      final cognitoSession = session as CognitoAuthSession;
      final token = cognitoSession.userPoolTokensResult.value.idToken.raw;
      final url = Uri.parse('${AppConfig.transactionsUrl}/$transactionId');
      final headers = {
        'Authorization': 'Bearer $token',
        'accept': 'application/json',
      };

      ApiLogger.logRequest(
        method: 'GET',
        url: url.toString(),
        headers: headers,
        operation: operation,
      );

      final response = await http.get(url, headers: headers);

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to get transaction. Status code: ${response.statusCode}',
        );
      }

      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
      return json.decode(response.body);
    } catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'GET',
        url: '${AppConfig.transactionsUrl}/$transactionId',
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error getting transaction by id: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateTransaction({
    required String transactionId,
    required TransactionUpdatePayload payload,
  }) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'updateTransaction';

    try {
      ApiLogger.logOperationStart(operation, {
        'transactionId': transactionId,
        'payload': payload.toJson(),
      });

      final url = Uri.parse('${AppConfig.transactionsUrl}/$transactionId');
      final requestId =
          generateOperationId(); // Still generate for X-Request-Id header
      final headers = await _buildAuthHeaders(
        includeJson: true,
        requestId: requestId,
      );

      final bodyMap = payload.toJson();
      // Use operationId from payload (original transaction operationId)
      final body = json.encode(bodyMap);

      // Detailed logging for debugging
      debugPrint('[API_SERVICE] updateTransaction body details:');
      debugPrint('[API_SERVICE] - transactionId: $transactionId');
      debugPrint('[API_SERVICE] - requestId (for header): $requestId');
      debugPrint(
        '[API_SERVICE] - operationId (from payload): ${bodyMap['operationId']}',
      );
      debugPrint('[API_SERVICE] - bodyMap keys: ${bodyMap.keys.toList()}');
      debugPrint('[API_SERVICE] - bodyMap values: $bodyMap');
      debugPrint('[API_SERVICE] - JSON body: $body');

      ApiLogger.logRequest(
        method: 'PUT',
        url: url.toString(),
        headers: headers,
        body: bodyMap,
        operation: operation,
      );

      final response = await http
          .put(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 25));

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'PUT',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to update transaction. Status code: ${response.statusCode}',
        );
      }

      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
      return response.body.isNotEmpty
          ? json.decode(response.body)
          : <String, dynamic>{};
    } catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'PUT',
        url: '${AppConfig.transactionsUrl}/$transactionId',
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error updating transaction: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateTransactionRaw({
    required String transactionId,
    required Map<String, dynamic> bodyMap,
  }) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'updateTransactionRaw';

    try {
      ApiLogger.logOperationStart(operation, {
        'transactionId': transactionId,
        'payload': bodyMap,
      });

      final url = Uri.parse('${AppConfig.transactionsUrl}/$transactionId');
      final requestId = generateOperationId();
      final headers = await _buildAuthHeaders(
        includeJson: true,
        requestId: requestId,
      );
      bodyMap.putIfAbsent('OperationId', () => requestId);

      final body = json.encode(bodyMap);

      // Detailed logging for debugging
      debugPrint('[API_SERVICE] updateTransactionRaw body details:');
      debugPrint('[API_SERVICE] - transactionId: $transactionId');
      debugPrint('[API_SERVICE] - requestId: $requestId');
      debugPrint('[API_SERVICE] - bodyMap keys: ${bodyMap.keys.toList()}');
      debugPrint('[API_SERVICE] - bodyMap values: $bodyMap');
      debugPrint('[API_SERVICE] - JSON body: $body');

      ApiLogger.logRequest(
        method: 'PUT',
        url: url.toString(),
        headers: headers,
        body: bodyMap,
        operation: operation,
      );

      final response = await http
          .put(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 25));

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'PUT',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to update transaction. Status code: ${response.statusCode}',
        );
      }

      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
      return response.body.isNotEmpty
          ? json.decode(response.body)
          : <String, dynamic>{};
    } catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'PUT',
        url: '${AppConfig.transactionsUrl}/$transactionId',
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error updating transaction (raw): $e');
      rethrow;
    }
  }

  static Future<TransactionStatsResponse> getTransactionStats({
    required DateTime startDate,
    required DateTime endDate,
    required TransactionStatsGrouping grouping,
    required TransactionStatsType type,
    required CurrencyCode currency,
    String? categoryId,
    String? balanceId,
    String? merchantId,
    String? groupId,
    String sort = 'amount',
    String order = 'desc',
    int limit = 10,
  }) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'getTransactionStats';

    try {
      ApiLogger.logOperationStart(operation, {
        'startTime': startDate.toIso8601String(),
        'endTime': endDate.toIso8601String(),
      });

      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        throw Exception('User is not signed in');
      }

      final userId = await AuthService.getUserId();
      final base = Uri.parse(AppConfig.transactionsStatsUrl);
      final url = base.replace(
        queryParameters: {
          'groupId': groupId,
          'userId': userId,
          'categoryId': categoryId,
          'balanceId': balanceId,
          'merchantId': merchantId,
          'startTime': startDate.toUtc().toIso8601String(),
          'endTime': endDate.toUtc().toIso8601String(),
          'grouping': grouping.name,
          'type': type.name,
          'displayCurrency': currency.name,
          'limit': limit.toString(),
          'sort': sort,
          'order': order,
        },
      );
      final headers = await _buildAuthHeaders();

      ApiLogger.logRequest(
        method: 'GET',
        url: url.toString(),
        headers: headers,
        operation: operation,
      );

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to get transaction stats. Status code: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);
      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
      return TransactionStatsResponse.fromJson(data);
    } on Exception catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'GET',
        url: AppConfig.transactionsStatsUrl,
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error getting transaction stats: $e');
      rethrow;
    }
  }

  static Future<void> deleteTransaction(String transactionId) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'deleteTransaction';

    try {
      ApiLogger.logOperationStart(operation, {'transactionId': transactionId});

      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        throw Exception('User is not signed in');
      }

      final url = Uri.parse('${AppConfig.transactionsUrl}/$transactionId');
      final requestId = generateOperationId();
      final headers = await _buildAuthHeaders(requestId: requestId);

      ApiLogger.logRequest(
        method: 'DELETE',
        url: url.toString(),
        headers: headers,
        operation: operation,
      );

      final response = await http
          .delete(url, headers: headers)
          .timeout(const Duration(seconds: 25));

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'DELETE',
        url: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to delete transaction. Status code: ${response.statusCode}',
        );
      }

      ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
    } catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'DELETE',
        url: '${AppConfig.transactionsUrl}/$transactionId',
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }
}
