import '../models/customer.dart';

List<Customer> seedCustomers() => [
      Customer(
        id: 'cu-001',
        fullName: 'Nguyễn Văn An',
        phone: '0911111111',
        email: 'an@gmail.com',
        points: 850,
        totalSpent: 8500000,
        totalOrders: 45,
      ),
      Customer(
        id: 'cu-002',
        fullName: 'Trần Thị Bích',
        phone: '0922222222',
        email: 'bich@gmail.com',
        points: 420,
        totalSpent: 4200000,
        totalOrders: 28,
      ),
      Customer(
        id: 'cu-003',
        fullName: 'Lê Minh Cường',
        phone: '0933333333',
        email: 'cuong@gmail.com',
        points: 180,
        totalSpent: 1800000,
        totalOrders: 15,
      ),
      Customer(
        id: 'cu-004',
        fullName: 'Phạm Thu Dung',
        phone: '0944444444',
        email: 'dung@gmail.com',
        points: 60,
        totalSpent: 600000,
        totalOrders: 5,
      ),
      Customer(
        id: 'cu-005',
        fullName: 'Khách lẻ',
        phone: '0955555555',
        points: 0,
      ),
    ];
