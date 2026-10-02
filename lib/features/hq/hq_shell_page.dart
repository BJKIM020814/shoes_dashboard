import 'package:flutter/material.dart';
import 'approval/approval_page.dart';
import 'branches/branches_page.dart';
import 'contracts/contracts_page.dart';
import 'data/hq_api.dart';
import 'inventory/hq_inventory_page.dart';
import 'members/inquiries_page.dart';
import 'members/members_page.dart';
import 'members/reviews_page.dart';
import 'orders/hq_orders_page.dart';
import 'sales/sales_page.dart';
import 'sales_management/sales_management_page.dart';
import 'dashboard/hq_dashboard_page.dart';
import 'widgets/hq_page_frame.dart';

class HqShellPage extends StatefulWidget {
  const HqShellPage({
    super.key,
    required this.dark,
    required this.onThemeChanged,
  });
  final bool dark;
  final VoidCallback onThemeChanged;
  @override
  State<HqShellPage> createState() => _HqShellPageState();
}

class _HqShellPageState extends State<HqShellPage> {
  int _selected = 0;
  static const _menu = [
    ('대시보드', Icons.grid_view_rounded),
    ('매출 현황', Icons.bar_chart_rounded),
    ('회원 관리', Icons.people_outline),
    ('리뷰 관리', Icons.rate_review_outlined),
    ('문의 관리', Icons.forum_outlined),
    ('주문 관리', Icons.receipt_long_outlined),
    ('재고 관리', Icons.inventory_2_outlined),
    ('결재 관리', Icons.fact_check_outlined),
    ('발주 관리', Icons.request_quote_outlined),
    ('대리점 관리', Icons.storefront_outlined),
    ('계약 관리', Icons.description_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
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
    width: inDrawer ? double.infinity : 238,
    color: hqGreen,
    padding: const EdgeInsets.fromLTRB(18, 25, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SHOEFIT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'HEADQUARTERS ADMIN',
          style: TextStyle(
            color: Color(0xffb6d5d0),
            fontSize: 9,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 27),
        Expanded(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 0, 9),
                child: Text(
                  '본사 운영센터',
                  style: TextStyle(
                    color: Color(0xffa7c6c0),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ..._menu.asMap().entries.map(
                (entry) => _navItem(entry.key, entry.value.$1, entry.value.$2),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0x557dafa8)),
        Row(
          children: [
            const Icon(Icons.key_outlined, size: 17, color: Color(0xffc2ded9)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                HqApi.instance.hasToken ? 'API 세션 연결됨' : 'API 세션 미연결',
                style: const TextStyle(color: Color(0xffc2ded9), fontSize: 11),
              ),
            ),
            IconButton(
              tooltip: 'API 토큰 설정',
              onPressed: _editToken,
              icon: const Icon(Icons.settings, color: Colors.white, size: 18),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _navItem(int index, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selected = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: _selected == index
                ? const Color(0xff0c6b63)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 11),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: _selected == index
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _topBar({required bool showMenu}) => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xffe5ecea))),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HEADQUARTERS · OPERATIONS CENTER',
                style: TextStyle(
                  color: hqGreen,
                  fontSize: 9,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _menu[_selected].$1,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'API 토큰 설정',
          onPressed: _editToken,
          icon: const Icon(Icons.key_outlined),
        ),
        IconButton(
          tooltip: widget.dark ? '라이트 모드' : '다크 모드',
          onPressed: widget.onThemeChanged,
          icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode),
        ),
      ],
    ),
  );

  Widget _page() => switch (_selected) {
    0 => const HqDashboardPage(),
    1 => const SalesPage(),
    2 => const MembersPage(),
    3 => const ReviewsPage(),
    4 => const InquiriesPage(),
    5 => const HqOrdersPage(),
    6 => const HqInventoryPage(),
    7 => const ApprovalPage(),
    8 => const SalesManagementPage(),
    9 => const BranchesPage(),
    10 => const ContractsPage(),
    _ => const SizedBox.shrink(),
  };

  Future<void> _editToken() async {
    final controller = TextEditingController(text: HqApi.instance.token);
    final formKey = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('본사 API 세션'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Bearer access token',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '로그인 accessToken을 입력해 주세요.'
                      : null,
                ),
                const SizedBox(height: 10),
                const Text(
                  '고객 API 로그인에서 받은 토큰을 사용합니다. 직원 이메일 연결이 없으면 서버가 본사 접근을 거부합니다.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('연결'),
          ),
          if (HqApi.instance.hasToken)
            TextButton(
              onPressed: () {
                HqApi.instance.clearToken();
                Navigator.pop(dialogContext, false);
              },
              child: const Text('해제'),
            ),
        ],
      ),
    );
    if (accepted == true) {
      HqApi.instance.setToken(controller.text);
      if (mounted) setState(() {});
    }
    controller.dispose();
  }
}
