import '../../core/constants/enums.dart';

class CafeTable {
  final String id;
  final String tableName;
  final int capacity;
  TableStatus status;
  String? currentOrderId;
  final String qrCodeValue;

  CafeTable({
    required this.id,
    required this.tableName,
    required this.capacity,
    this.status = TableStatus.empty,
    this.currentOrderId,
    String? qrCodeValue,
  }) : qrCodeValue = qrCodeValue ?? 'smartcafe://table/\$id';
}
