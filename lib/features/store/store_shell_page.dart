import 'package:flutter/material.dart';
import 'dashboard/store_dashboard_page.dart';
import 'information/store_information_page.dart';
import 'inventory/store_inventory_page.dart';
import 'orders/store_orders_page.dart';
import 'pickup/pickup_confirmation_page.dart';
import 'returns/return_management_page.dart';
import 'statistics/store_statistics_page.dart';

class StoreShellPage extends StatefulWidget {
  const StoreShellPage({super.key});

  @override
  State<StoreShellPage> createState() => _StoreShellPageState();
}

class _StoreShellPageState extends State<StoreShellPage> {
  static const _green = Color(0xff064d47);
  int _selected = 0;
  final _menu = const [
    ('대시보드', Icons.grid_view_rounded),
    ('수령 확인', Icons.qr_code_scanner),
    ('반품 처리', Icons.assignment_return_outlined),
    ('재고 관리', Icons.warehouse_outlined),
    ('주문 현황', Icons.receipt_long_outlined),
    ('매장 통계', Icons.bar_chart_rounded),
    ('매장 정보', Icons.store_outlined),
  ];

  Widget _page() => switch (_selected) {
    0 => const StoreDashboardPage(),
    1 => const PickupConfirmationPage(),
    2 => const ReturnManagementPage(),
    3 => const StoreInventoryPage(),
    4 => const StoreOrdersPage(),
    5 => const StoreStatisticsPage(),
    _ => const StoreInformationPage(),
  };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return Scaffold(
      drawer: wide ? null : Drawer(child: _sidebar(inDrawer: true)),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _sidebar(),
            Expanded(
              child: Column(
                children: [
                  _topBar(showMenu: !wide),
                  Expanded(child: _page()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar({bool inDrawer = false}) => Container(
    width: inDrawer ? double.infinity : 220,
    color: _green,
    padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SHOEFIT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'GANGNAM STORE ADMIN',
          style: TextStyle(
            color: Color(0xffa7d0ca),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 32),
        ..._menu.asMap().entries.map(
          (entry) => _navItem(entry.key, entry.value.$1, entry.value.$2),
        ),
        const Spacer(),
        const Divider(color: Color(0x557dafa8)),
        const SizedBox(height: 8),
        const Text(
          '강남점 · 대리점 관리자',
          style: TextStyle(color: Color(0xffc2ded9), fontSize: 12),
        ),
      ],
    ),
  );

  Widget _navItem(int index, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selected = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _selected == index
                ? const Color(0xff0c6b63)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 11),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _topBar({required bool showMenu}) => Container(
    height: 78,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xffe6eceb))),
    ),
    child: Row(
      children: [
        if (showMenu)
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu),
            ),
          ),
        Expanded(
          child: Text(
            '강남점 대리점 관리자',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        const Icon(Icons.notifications_none, color: _green),
        const SizedBox(width: 18),
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xffd8ece8),
          child: Icon(Icons.person, color: _green),
        ),
      ],
    ),
  );
}
