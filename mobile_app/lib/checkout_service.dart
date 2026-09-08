import 'package:flutter/services.dart';

enum CheckoutStatus { completed, cancelled }

class CheckoutKit {
  static const _channel = MethodChannel('com.pinpinskakanin/checkout');

  static Future<CheckoutStatus> present(Uri checkoutUrl) async {
    if (checkoutUrl.scheme != 'https') {
      throw const CheckoutKitException('Invalid checkout URL');
    }

    try {
      final status = await _channel.invokeMethod<String>('present', {
        'checkoutUrl': checkoutUrl.toString(),
      });
      return switch (status) {
        'completed' => CheckoutStatus.completed,
        'cancelled' => CheckoutStatus.cancelled,
        _ => throw const CheckoutKitException('Unknown checkout result'),
      };
    } on PlatformException catch (error) {
      throw CheckoutKitException(error.message ?? 'Checkout failed');
    }
  }
}

class CheckoutKitException implements Exception {
  const CheckoutKitException(this.message);

  final String message;

  @override
  String toString() => message;
}
