import '../models/order.dart';

abstract final class MockData {
  static const orders = [
    Order(
      id: 'FP-202609-120',
      product: '뉴발란스 530',
      customer: '김민수',
      branch: '강남점',
      status: '배송중',
    ),
  ];
}
