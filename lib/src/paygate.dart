import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class Paygate {
  static const MethodChannel _channel =
      MethodChannel('com.paygate.flutter/sdk');

  static String? _apiKey;
  static String _baseURL = 'https://api-oh6xuuomca-uc.a.run.app';

  /// Initialize the Paygate SDK with your API key.
  ///
  /// Must be called before [launch]. Typically called in your app's `main()`.
  static Future<void> initialize({
    required String apiKey,
    String? baseURL,
  }) async {
    _apiKey = apiKey;
    if (baseURL != null) _baseURL = baseURL;
  }

  /// Launch a paywall flow.
  ///
  /// Returns the purchased product ID, or `null` if the user dismissed
  /// without purchasing.
  static Future<String?> launch(String flowId, {bool bounces = false}) async {
    if (_apiKey == null) {
      throw PlatformException(
        code: 'NOT_INITIALIZED',
        message: 'Call Paygate.initialize() first.',
      );
    }

    final flowData = await _fetchFlow(flowId);
    final htmlContent = flowData['htmlContent'] as String? ?? '';

    final result = await _channel.invokeMapMethod<String, dynamic>('launch', {
      'htmlContent': htmlContent,
      'bounces': bounces,
    });

    if (result == null) return null;

    final action = result['action'] as String?;
    final productId = result['productId'] as String?;

    if (action == 'purchased' && productId != null) {
      _trackEvent(flowId, 'purchase_completed', {'productId': productId});
      return productId;
    }

    return null;
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
