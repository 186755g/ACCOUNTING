import 'payment.dart';

class SaleTender {
  const SaleTender({required this.method, required this.amountMinor});

  final PaymentMethod method;
  final int amountMinor;
}
