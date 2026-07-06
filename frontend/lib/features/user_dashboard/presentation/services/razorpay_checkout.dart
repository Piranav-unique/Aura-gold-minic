import 'package:razorpay_flutter/razorpay_flutter.dart';

typedef RazorpaySuccessHandler = void Function(PaymentSuccessResponse response);
typedef RazorpayErrorHandler = void Function(PaymentFailureResponse response);

class RazorpayCheckout {
  Razorpay? _razorpay;
  RazorpaySuccessHandler? _onSuccess;
  RazorpayErrorHandler? _onError;

  void open({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required RazorpaySuccessHandler onSuccess,
    required RazorpayErrorHandler onError,
  }) {
    dispose();
    _onSuccess = onSuccess;
    _onError = onError;
    _razorpay = Razorpay();
    _razorpay!
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleError)
      ..open({
        'key': keyId,
        'amount': amountPaise,
        'name': 'AURUM',
        'description': 'Gold purchase',
        'order_id': orderId,
        'currency': 'INR',
        'theme': {'color': '#D4AF37'},
      });
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    _onSuccess?.call(response);
    dispose();
  }

  void _handleError(PaymentFailureResponse response) {
    _onError?.call(response);
    dispose();
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _onSuccess = null;
    _onError = null;
  }
}
