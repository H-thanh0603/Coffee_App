class WorkShift {
  final String id;
  final String userId;
  final String userName;
  final DateTime clockIn;
  DateTime? clockOut;

  WorkShift({
    required this.id,
    required this.userId,
    required this.userName,
    DateTime? clockIn,
    this.clockOut,
  }) : clockIn = clockIn ?? DateTime.now();

  bool get isOpen => clockOut == null;

  Duration get worked => (clockOut ?? DateTime.now()).difference(clockIn);
}
