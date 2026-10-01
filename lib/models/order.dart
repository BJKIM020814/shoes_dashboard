class Order {
  const Order({
    required this.id,
    required this.product,
    required this.customer,
    required this.branch,
    required this.status,
  });
  final String id, product, customer, branch, status;
}
