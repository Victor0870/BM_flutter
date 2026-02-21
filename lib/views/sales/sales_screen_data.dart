import '../../controllers/sales_provider.dart';

/// Model cho một tab hóa đơn (POS).
class InvoiceTab {
  final int id;
  final String name;
  final SalesProvider salesProvider;

  InvoiceTab({
    required this.id,
    required this.name,
    required this.salesProvider,
  });
}
