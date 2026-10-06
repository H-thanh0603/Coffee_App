import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/cafe_table.dart';
import '../../data/models/order.dart';
import '../../data/models/table_reservation.dart';
import '../../data/services/data_store.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final tables = store.tables;
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Sơ đồ bàn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotifications(context, store),
          ),
        ],
      ),
      body: Column(
        children: [
          const _ReservationStrip(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in TableStatus.values) StatusBadge.table(s),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: tables.length,
              itemBuilder: (_, i) => _TableCard(table: tables[i], store: store),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context, DataStore store) {
    final role = context.read<AuthProvider>().role;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final list =
            role == null ? <dynamic>[] : store.notificationsForRole(role);
        if (list.isEmpty) {
          return const SizedBox(
              height: 200,
              child: EmptyState(emoji: '🔔', title: 'Không có thông báo'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final n = list[i];
            return ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(n.title),
              subtitle: Text(n.message),
              trailing: Text(Fmt.relative(n.createdAt),
                  style: const TextStyle(fontSize: 11)),
            );
          },
        );
      },
    );
  }
}

/// Dải đơn đặt trước sắp tới + nút quản lý (nhận bàn / hủy).
class _ReservationStrip extends StatelessWidget {
  const _ReservationStrip();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final list = store.upcomingReservations;
    if (list.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final r = list[i];
          return Container(
            width: 250,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: r.isOverdue
                  ? AppColors.danger.withOpacity(0.1)
                  : AppColors.cardBg,
              border: Border.all(
                  color:
                      r.isOverdue ? AppColors.danger : AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.tableName + ' • ' + Fmt.time(r.reservedAt),
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: r.isOverdue
                                  ? AppColors.danger
                                  : AppColors.textPrimary)),
                      Text(r.customerName + ' • ' + r.guests.toString() + ' khách',
                          style: const TextStyle(fontSize: 12)),
                      Text(Fmt.date(r.reservedAt),
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ]),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline,
                    color: AppColors.success),
                tooltip: 'Nhận bàn',
                onPressed: () => store.seatReservation(r.id),
              ),
              IconButton(
                icon:
                    const Icon(Icons.close, color: AppColors.danger, size: 20),
                tooltip: 'Hủy đặt',
                onPressed: () => store.cancelReservation(r.id),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// Form đặt bàn trước có giờ (chặn trùng giờ ±60 phút ở store).
class _ReservationForm extends StatefulWidget {
  final CafeTable table;
  const _ReservationForm({required this.table});
  @override
  State<_ReservationForm> createState() => _ReservationFormState();
}

class _ReservationFormState extends State<_ReservationForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  int _guests = 2;
  DateTime _at = DateTime.now().add(const Duration(hours: 1));

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Đặt bàn ' + widget.table.tableName + ' trước',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _name,
              decoration: const InputDecoration(labelText: 'Tên khách')),
          const SizedBox(height: 8),
          TextField(controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'SĐT')),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Số khách'),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () =>
                    setState(() => _guests = (_guests - 1).clamp(1, 20))),
            Text(_guests.toString(),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: () =>
                    setState(() => _guests = (_guests + 1).clamp(1, 20))),
          ]),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.schedule, color: AppColors.primary),
            title: Text(Fmt.dateTime(_at)),
            trailing: const Text('Đổi giờ'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _at,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (d == null) return;
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_at),
              );
              if (t == null || !context.mounted) return;
              setState(() => _at = DateTime(
                  d.year, d.month, d.day, t.hour, t.minute));
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_name.text.trim().isEmpty) return;
                final ok = context.read<DataStore>().addReservation(
                      TableReservation(
                        id: const Uuid().v4(),
                        tableId: widget.table.id,
                        tableName: widget.table.tableName,
                        customerName: _name.text.trim(),
                        phone: _phone.text.trim(),
                        guests: _guests,
                        reservedAt: _at,
                      ),
                    );
                if (!context.mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Giờ này đã có khách đặt (±60 phút)')),
                  );
                  return;
                }
                Navigator.pop(context);
              },
              child: const Text('Xác nhận đặt bàn'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final CafeTable table;
  final DataStore store;
  const _TableCard({required this.table, required this.store});

  Color get _color {
    switch (table.status) {
      case TableStatus.empty:
        return AppColors.tableEmpty;
      case TableStatus.serving:
        return AppColors.tableServing;
      case TableStatus.waiting:
        return AppColors.tableWaiting;
      case TableStatus.reserved:
        return AppColors.tableReserved;
      case TableStatus.needsClean:
        return AppColors.tableNeedsClean;
    }
  }

  AppOrder? get _order => table.currentOrderId == null
      ? null
      : store.orders
          .cast<AppOrder?>()
          .firstWhere((o) => o?.id == table.currentOrderId, orElse: () => null);

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.08),
          border: Border.all(color: _color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.chair, color: _color),
            const Spacer(),
            Text(table.tableName,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18, color: _color)),
          ]),
          const Spacer(),
          Text(table.status.label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
          const SizedBox(height: 2),
          Text(table.capacity.toString() + ' chỗ',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          if (order != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(order.orderCode,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }

  void _showActions(BuildContext ctx) {
    final order = _order;
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.point_of_sale, color: AppColors.primary),
            title: Text('Tạo đơn cho ' + table.tableName),
            subtitle: table.status != TableStatus.empty
                ? const Text('Sẽ chọn sẵn bàn trong giỏ',
                    style: TextStyle(fontSize: 11))
                : null,
            onTap: () {
              final cart = ctx.read<CartProvider>();
              cart.setTable(table.id, table.tableName);
              Navigator.pop(ctx);
              ctx.go('/cashier');
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.event_seat, color: AppColors.primary),
            title: Text('Đặt bàn ' + table.tableName + ' trước'),
            onTap: () {
              Navigator.pop(ctx);
              _bookTable(ctx);
            },
          ),
          if (order != null) ...[
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: AppColors.primary),
              title: const Text('Chuyển bàn'),
              onTap: () {
                Navigator.pop(ctx);
                _pickTableToMove(ctx, order);
              },
            ),
            ListTile(
              leading: const Icon(Icons.merge, color: AppColors.accent),
              title: const Text('Gộp bàn vào...'),
              onTap: () {
                Navigator.pop(ctx);
                _pickTableToMerge(ctx);
              },
            ),
          ],
          ...TableStatus.values
              .where((s) => s != table.status)
              .map((s) => ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text('Chuyển trạng thái: ' + s.label),
                    onTap: () {
                      store.setTableStatus(table.id, s);
                      Navigator.pop(ctx);
                    },
                  )),
        ]),
      ),
    );
  }

  /// Chọn bàn trống để chuyển order sang.
  void _pickTableToMove(BuildContext ctx, AppOrder order) {
    final available = store.tables
        .where((t) => t.id != table.id && t.status == TableStatus.empty)
        .toList();
    showModalBottomSheet(
      context: ctx,
      builder: (_) => available.isEmpty
          ? const SizedBox(
              height: 160, child: Center(child: Text('Không có bàn trống')))
          : SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: available
                    .map((t) => ListTile(
                          leading:
                              const Icon(Icons.chair, color: AppColors.primary),
                          title: Text('Chuyển sang ' + t.tableName),
                          subtitle: Text(t.capacity.toString() +
                              ' chỗ • ' +
                              t.status.label),
                          onTap: () {
                            store.moveOrderToTable(order.id, t.id);
                            Navigator.pop(ctx);
                          },
                        ))
                    .toList(),
              ),
            ),
    );
  }

  /// Mở form đặt bàn trước có giờ cho bàn này.
  void _bookTable(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ReservationForm(table: table),
      ),
    );
  }

  /// Chọn bàn đang phục vụ để gộp (bàn này sẽ gộp vào bàn kia).
  void _pickTableToMerge(BuildContext ctx) {
    final serving = store.tables
        .where((t) => t.id != table.id && t.status == TableStatus.serving)
        .toList();
    showModalBottomSheet(
      context: ctx,
      builder: (_) => serving.isEmpty
          ? const SizedBox(
              height: 160,
              child: Center(child: Text('Không có bàn đang phục vụ khác')))
          : SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: serving
                    .map((t) => ListTile(
                          leading: Icon(Icons.merge, color: AppColors.accent),
                          title: Text(
                              'Gộp ' + table.tableName + ' vào ' + t.tableName),
                          subtitle:
                              Text('Toàn bộ món sẽ dồn về ' + t.tableName),
                          onTap: () {
                            store.mergeTables(table.id, t.id);
                            Navigator.pop(ctx);
                          },
                        ))
                    .toList(),
              ),
            ),
    );
  }
}
