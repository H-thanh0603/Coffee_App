import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product.dart';
import '../../data/models/topping.dart';
import '../../data/services/data_store.dart';
import '../cart/cart_provider.dart';

class ProductOptionsSheet extends StatefulWidget {
  final Product product;
  const ProductOptionsSheet({super.key, required this.product});
  @override
  State<ProductOptionsSheet> createState() => _ProductOptionsSheetState();
}

class _ProductOptionsSheetState extends State<ProductOptionsSheet> {
  late DrinkSize _size;
  final Set<String> _toppingIds = {};
  SugarLevel _sugar = SugarLevel.full;
  IceLevel _ice = IceLevel.normal;
  int _qty = 1;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _size = widget.product.priceBySize.keys.first;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final p = widget.product;
    final allTops = store.toppings.where((t) =>
        p.availableToppingIds.contains(t.id) && t.available).toList();
    final selectedTops = allTops.where((t) => _toppingIds.contains(t.id)).toList();
    final base = p.priceFor(_size);
    final tPrice = selectedTops.fold<double>(0, (s, t) => s + t.price);
    final unit = base + tPrice;
    final total = unit * _qty;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 48))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          if (p.description.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 4),
                              child: Text(p.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                          const SizedBox(height: 6),
                          Text(Fmt.money(p.basePrice),
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (p.priceBySize.length > 1) _section('Kích cỡ', _sizePicker(p)),
                  if (allTops.isNotEmpty) _section('Topping', _toppingPicker(allTops)),
                  _section('Đường', _enumChips<SugarLevel>(SugarLevel.values, _sugar, (v) => setState(() => _sugar = v), (e) => e.label)),
                  _section('Đá', _enumChips<IceLevel>(IceLevel.values, _ice, (v) => setState(() => _ice = v), (e) => e.label)),
                  _section('Ghi chú',
                      TextField(controller: _noteCtrl, maxLines: 2, decoration: const InputDecoration(hintText: 'Ghi chú thêm...'))),
                ],
              ),
            ),
            _bottomBar(unit: unit, total: total),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }

  Widget _sizePicker(Product p) {
    return Wrap(spacing: 8, children: p.priceBySize.entries.map((e) {
      final selected = _size == e.key;
      return ChoiceChip(
        label: Text(e.key.code + ' - ' + Fmt.money(e.value)),
        selected: selected,
        onSelected: (_) => setState(() => _size = e.key),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
      );
    }).toList());
  }

  Widget _toppingPicker(List<Topping> tops) {
    return Wrap(spacing: 8, runSpacing: 8, children: tops.map((t) {
      final selected = _toppingIds.contains(t.id);
      return FilterChip(
        label: Text(t.name + ' +' + Fmt.money(t.price)),
        selected: selected,
        onSelected: (v) => setState(() {
          if (v) {
            _toppingIds.add(t.id);
          } else {
            _toppingIds.remove(t.id);
          }
        }),
        selectedColor: AppColors.secondary,
      );
    }).toList());
  }

  Widget _enumChips<T>(List<T> values, T current, ValueChanged<T> onTap, String Function(T) labelOf) {
    return Wrap(spacing: 8, children: values.map((e) {
      final selected = e == current;
      return ChoiceChip(
        label: Text(labelOf(e)),
        selected: selected,
        onSelected: (_) => onTap(e),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
      );
    }).toList());
  }

  Widget _bottomBar({required double unit, required double total}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          _qtyBtn(Icons.remove, () => setState(() => _qty = (_qty - 1).clamp(1, 99))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_qty.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          _qtyBtn(Icons.add, () => setState(() => _qty = (_qty + 1).clamp(1, 99))),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _addToCart,
              child: Text('Thêm • ' + Fmt.money(total)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _qtyBtn(IconData ic, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(ic, size: 18),
        ),
      );

  void _addToCart() {
    final store = context.read<DataStore>();
    final cart = context.read<CartProvider>();
    final tops = store.toppings.where((t) => _toppingIds.contains(t.id)).toList();
    cart.addItem(
      product: widget.product,
      size: _size,
      toppings: tops,
      sugar: _sugar,
      ice: _ice,
      quantity: _qty,
      note: _noteCtrl.text,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã thêm ' + widget.product.name + ' vào giỏ'), duration: const Duration(seconds: 1)),
    );
  }
}
