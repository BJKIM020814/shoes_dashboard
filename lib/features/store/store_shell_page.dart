import 'package:flutter/material.dart';

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
    ('주문 관리', Icons.receipt_long_outlined),
    ('수령 확인', Icons.inventory_2_outlined),
    ('반품 처리', Icons.assignment_return_outlined),
    ('재고 관리', Icons.warehouse_outlined),
    ('매출 현황', Icons.bar_chart_rounded),
    ('매장 정보', Icons.store_outlined),
  ];

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
                  Expanded(child: _selected == 0 ? _dashboard() : _emptyPage()),
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

  Widget _dashboard() => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '대리점 대시보드',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(
          '강남점의 오늘 운영 현황을 빠르고 정확하게 확인하세요.',
          style: TextStyle(color: Colors.blueGrey.shade600),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: const [
            _MetricCard('오늘 매출', '₩3,240,000', Icons.payments_outlined, '13%'),
            _MetricCard('오늘 주문', '12건', Icons.shopping_bag_outlined, '3건'),
            _MetricCard('현재 재고', '320개', Icons.inventory_2_outlined, '정상'),
            _MetricCard(
              '오늘 반품',
              '2건',
              Icons.assignment_return_outlined,
              '확인 필요',
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 620
              ? Column(
                  children: [
                    _todaySchedule(),
                    const SizedBox(height: 18),
                    _notice(),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _todaySchedule()),
                    const SizedBox(width: 18),
                    Expanded(child: _notice()),
                  ],
                ),
        ),
      ],
    ),
  );

  Widget _todaySchedule() => _panel('오늘의 일정', const [
    ('오전 수령 예약 5건', '09:00 · 12:00'),
    ('오후 수령 예약 7건', '13:00 · 18:00'),
    ('반품 접수 2건', '처리하기'),
  ]);

  Widget _notice() => _panel('공지사항', const [
    ('신상품 입고 안내', '09.22'),
    ('추석 연휴 운영 안내', '09.21'),
    ('반품 정책 변경 안내', '09.20'),
  ]);

  Widget _panel(String title, List<(String, String)> items) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffe4ebea)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 17, color: _green),
                const SizedBox(width: 9),
                Expanded(child: Text(item.$1)),
                Text(
                  item.$2,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _emptyPage() => Center(
    child: Text(
      '${_menu[_selected].$1} 화면을 준비하고 있습니다.',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon, this.hint);
  final String label, value, hint;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 188,
    child: Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe4ebea)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: const Color(0xff064d47)),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            hint,
            style: const TextStyle(
              color: Color(0xff168e5d),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
