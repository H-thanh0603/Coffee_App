import '../../core/constants/enums.dart';

class Customer {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  int points;
  CustomerRank rank;
  double totalSpent;
  int totalOrders;
  final List<String> favoriteProducts;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email = '',
    this.points = 0,
    CustomerRank? rank,
    this.totalSpent = 0,
    this.totalOrders = 0,
    List<String>? favoriteProducts,
    DateTime? createdAt,
  })  : rank = rank ?? CustomerRank.fromPoints(points),
        favoriteProducts = favoriteProducts ?? <String>[],
        createdAt = createdAt ?? DateTime.now();

  void addPoints(int amount) {
    points += amount;
    rank = CustomerRank.fromPoints(points);
  }

  void addOrder(double amount) {
    totalOrders += 1;
    totalSpent += amount;
  }
}
