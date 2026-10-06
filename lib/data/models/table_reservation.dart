import '../../core/constants/enums.dart';

class TableReservation {
  final String id;
  final String tableId;
  final String tableName;
  final String customerName;
  final String phone;
  final int guests;
  final DateTime reservedAt;
  TableReservationStatus status;
  final String note;

  TableReservation({
    required this.id,
    required this.tableId,
    required this.tableName,
    required this.customerName,
    required this.phone,
    this.guests = 2,
    required this.reservedAt,
    this.status = TableReservationStatus.upcoming,
    this.note = '',
  });

  /// Quá giờ hẹn 15 phút vẫn chưa nhận bàn.
  bool get isOverdue =>
      status == TableReservationStatus.upcoming &&
      DateTime.now().difference(reservedAt).inMinutes > 15;
}
