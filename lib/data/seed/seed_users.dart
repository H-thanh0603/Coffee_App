import 'package:uuid/uuid.dart';
import '../../core/constants/enums.dart';
import '../models/user.dart';

List<AppUser> seedUsers() {
  const u = Uuid();
  return [
    AppUser(
      id: u.v4(),
      fullName: 'Nguyễn Hữu Thanh',
      email: 'admin@smartcafe.com',
      phone: '0901234567',
      role: UserRole.admin,
    ),
    AppUser(
      id: u.v4(),
      fullName: 'Trần Thị Thu Ngân',
      email: 'cashier@smartcafe.com',
      phone: '0902345678',
      role: UserRole.cashier,
    ),
    AppUser(
      id: u.v4(),
      fullName: 'Lê Pha Chế',
      email: 'barista@smartcafe.com',
      phone: '0903456789',
      role: UserRole.barista,
    ),
    AppUser(
      id: u.v4(),
      fullName: 'Phạm Phục Vụ',
      email: 'waiter@smartcafe.com',
      phone: '0904567890',
      role: UserRole.waiter,
    ),
    AppUser(
      id: u.v4(),
      fullName: 'Khách Vãng Lai',
      email: 'customer@smartcafe.com',
      phone: '0905678901',
      role: UserRole.customer,
    ),
  ];
}
