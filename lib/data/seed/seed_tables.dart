import '../models/cafe_table.dart';

List<CafeTable> seedTables() {
  final tables = <CafeTable>[];
  for (var i = 1; i <= 12; i++) {
    final name = 'B' + i.toString().padLeft(2, '0');
    tables.add(CafeTable(
      id: 'tb-' + name,
      tableName: name,
      capacity: i <= 4 ? 2 : (i <= 8 ? 4 : 6),
    ));
  }
  return tables;
}
