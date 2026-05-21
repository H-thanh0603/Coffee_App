import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../data/models/order_item.dart';
import '../../data/models/product.dart';
import '../../data/models/topping.dart';
import '../../data/models/voucher.dart';

class CartProvider extends ChangeNotifier {
  final List<OrderItem> _items = [];
  String? _tableId;
  String? _tableName;
  String? _customerId;
  String? _customerName;
  OrderType _orderType = OrderType.dineIn;
  Voucher? _voucher;
  String _note = '';

  List<OrderItem> get items => List.unmodifiable(_items);
  String? get tableId => _tableId;
  String? get tableName => _tableName;
  String? get customerId => _customerId;
  String? get customerName => _customerName;
  OrderType get orderType => _orderType;
  Voucher? get voucher => _voucher;
  String get note => _note;

  int get itemCount => _items.fold<int>(0, (s, e) => s + e.quantity);
  double get subtotal => _items.fold<double>(0, (s, e) => s + e.totalPrice);
  double get discount => _voucher?.calcDiscount(subtotal) ?? 0;
  double get total => subtotal - discount;

  void setTable(String? id, String? name) {
    _tableId = id;
    _tableName = name;
    if (id != null) _orderType = OrderType.dineIn;
    notifyListeners();
  }

  void setOrderType(OrderType t) {
    _orderType = t;
    if (t == OrderType.takeaway) {
      _tableId = null;
      _tableName = null;
    }
    notifyListeners();
  }

  void setCustomer(String? id, String? name) {
    _customerId = id;
    _customerName = name;
    notifyListeners();
  }

  void setVoucher(Voucher? v) {
    _voucher = v;
    notifyListeners();
  }

  void setNote(String n) {
    _note = n;
    notifyListeners();
  }

  void addItem({
    required Product product,
    required DrinkSize size,
    required List<Topping> toppings,
    required SugarLevel sugar,
    required IceLevel ice,
    int quantity = 1,
    String note = '',
  }) {
    final price = product.priceFor(size);
    final tPrice = toppings.fold<double>(0, (s, t) => s + t.price);
    _items.add(OrderItem(
      id: const Uuid().v4(),
      productId: product.id,
      productName: product.name,
      emoji: product.emoji,
      size: size,
      toppingIds: toppings.map((t) => t.id).toList(),
      toppingNames: toppings.map((t) => t.name).toList(),
      toppingsPrice: tPrice,
      sugar: sugar,
      ice: ice,
      quantity: quantity,
      unitPrice: price,
      note: note,
    ));
    notifyListeners();
  }

  void incQty(String itemId) {
    final i = _items.indexWhere((e) => e.id == itemId);
    if (i >= 0) {
      _items[i].quantity += 1;
      notifyListeners();
    }
  }

  void decQty(String itemId) {
    final i = _items.indexWhere((e) => e.id == itemId);
    if (i >= 0) {
      _items[i].quantity -= 1;
      if (_items[i].quantity <= 0) _items.removeAt(i);
      notifyListeners();
    }
  }

  void removeItem(String itemId) {
    _items.removeWhere((e) => e.id == itemId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _tableId = null;
    _tableName = null;
    _customerId = null;
    _customerName = null;
    _orderType = OrderType.dineIn;
    _voucher = null;
    _note = '';
    notifyListeners();
  }
}
