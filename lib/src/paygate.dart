import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

enum PaygatePresentationStyle {
  fullScreen,
  sheet,
}

class Paygate {
  static const MethodChannel _channel =
      MethodChannel('com.paygate.flutter/sdk');

  static String? _apiKey;
  static String _baseURL = 'https://api-oh6xuuomca-uc.a.run.app';
  static final Map<String, Map<String, dynamic>> _gateCache = {};
  static final Set<String> _purchasedProductIDs = {};

  /// The set of App Store product IDs the user currently owns.
  static Set<String> get purchasedProductIDs =>
      Set.unmodifiable(_purchasedProductIDs);

  /// Initialize the Paygate SDK with your API key.
  ///
  /// Must be called before [launchFlow] or [launchGate]. Typically called in your app's `main()`.
  /// On iOS this also starts the StoreKit 2 transaction listener and loads
  /// the user's existing purchases.
  static Future<void> initialize({
    required String apiKey,
    String? baseURL,
  }) async {
    _apiKey = apiKey;
    if (baseURL != null) _baseURL = baseURL;

    if (Platform.isIOS) {
      final result = await _channel.invokeMethod<List>('initialize');
      if (result != null) {
        _purchasedProductIDs.addAll(result.cast<String>());
      }
    }
  }

  /// Launch a paywall flow.
  ///
  /// Returns the purchased product ID, or `null` if the user dismissed
  /// without purchasing.
  static Future<String?> launchFlow(
    String flowId, {
    bool bounces = false,
    PaygatePresentationStyle presentationStyle = PaygatePresentationStyle.sheet,
  }) async {
    if (_apiKey == null) {
      throw PlatformException(
        code: 'NOT_INITIALIZED',
        message: 'Call Paygate.initialize() first.',
      );
    }

    final flowData = await _fetchFlow(flowId);
    final htmlContent = flowData['htmlContent'] as String? ?? '';
    final productIdMap = _buildProductIdMap(flowData);

    final owned = _findOwnedProduct(flowData, productIdMap);
    if (owned != null) return owned;

    _trackEvent(flowId, 'purchase_initiated', {});

    final result = await _channel.invokeMapMethod<String, dynamic>('launch', {
      'htmlContent': htmlContent,
      'bounces': bounces,
      'presentationStyle': presentationStyle.name,
      'productIdMap': productIdMap,
    });

    if (result == null) return null;

    final action = result['action'] as String?;
    final productId = result['productId'] as String?;

    if (action == 'purchased' && productId != null) {
      _purchasedProductIDs.add(productId);
      _trackEvent(flowId, 'purchase_completed', {'productId': productId});
      return productId;
    }

    if (action == 'error') {
      throw PlatformException(
        code: 'PURCHASE_ERROR',
        message: 'Purchase failed at the native layer.',
      );
    }

    return null;
  }

  /// Launch a gate, which randomly selects a flow based on configured weights.
  ///
  /// Returns the purchased product ID, or `null` if the user dismissed
  /// without purchasing.
  static Future<String?> launchGate(
    String gateId, {
    bool bounces = false,
    PaygatePresentationStyle presentationStyle = PaygatePresentationStyle.sheet,
  }) async {
    if (_apiKey == null) {
      throw PlatformException(
        code: 'NOT_INITIALIZED',
        message: 'Call Paygate.initialize() first.',
      );
    }

    final Map<String, dynamic> flowData;
    if (_gateCache.containsKey(gateId)) {
      flowData = _gateCache[gateId]!;
    } else {
      final fetched = await _fetchGate(gateId);
      _gateCache[gateId] = fetched;
      flowData = fetched;
    }
    final htmlContent = flowData['htmlContent'] as String? ?? '';
    final selectedFlowId = flowData['selectedFlowId'] as String? ?? gateId;
    final productIdMap = _buildProductIdMap(flowData);

    final owned = _findOwnedProduct(flowData, productIdMap);
    if (owned != null) return owned;

    _trackEvent(selectedFlowId, 'purchase_initiated', {});

    final result = await _channel.invokeMapMethod<String, dynamic>('launch', {
      'htmlContent': htmlContent,
      'bounces': bounces,
      'presentationStyle': presentationStyle.name,
      'productIdMap': productIdMap,
    });

    if (result == null) return null;

    final action = result['action'] as String?;
    final productId = result['productId'] as String?;

    if (action == 'purchased' && productId != null) {
      _purchasedProductIDs.add(productId);
      _trackEvent(selectedFlowId, 'purchase_completed', {'productId': productId});
      return productId;
    }

    if (action == 'error') {
      throw PlatformException(
        code: 'PURCHASE_ERROR',
        message: 'Purchase failed at the native layer.',
      );
    }

    return null;
  }

  /// Returns the first already-owned App Store product ID for this flow, or
  /// `null` if nothing is owned yet.
  static String? _findOwnedProduct(
    Map<String, dynamic> flowData,
    Map<String, String> productIdMap,
  ) {
    final productIds = (flowData['productIds'] as List?)?.cast<String>() ?? [];
    for (final id in productIds) {
      final storeId = productIdMap[id] ?? id;
      if (_purchasedProductIDs.contains(storeId)) return storeId;
    }
    return null;
  }

  static Map<String, String> _buildProductIdMap(Map<String, dynamic> flowData) {
    final products = flowData['products'] as List? ?? [];
    final map = <String, String>{};
    for (final product in products) {
      if (product is Map<String, dynamic>) {
        final id = product['id'] as String?;
        final appStoreId = product['appStoreId'] as String?;
        if (id != null && appStoreId != null && appStoreId.isNotEmpty) {
          map[id] = appStoreId;
        }
      }
    }
    return map;
  }

  static Future<Map<String, dynamic>> _fetchGate(String gateId) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('$_baseURL/api/sdk/gates/$gateId'),
      );
      request.headers.set('X-API-Key', _apiKey!);

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Failed to load gate (HTTP ${response.statusCode})',
        );
      }

      return json.decode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _fetchFlow(String flowId) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('$_baseURL/api/sdk/flows/$flowId'),
      );
      request.headers.set('X-API-Key', _apiKey!);

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Failed to load flow (HTTP ${response.statusCode})',
        );
      }

      return json.decode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  static void _trackEvent(
    String flowId,
    String eventType,
    Map<String, String> metadata,
  ) {
    () async {
      final client = HttpClient();
      try {
        final request = await client.postUrl(
          Uri.parse('$_baseURL/api/sdk/flows/$flowId/events'),
        );
        request.headers.set('X-API-Key', _apiKey!);
        request.headers.contentType = ContentType.json;
        request.write(json.encode({
          'eventType': eventType,
          'metadata': metadata,
        }));
        await request.close();
      } catch (_) {
      } finally {
        client.close();
      }
    }();
  }
}
