import 'package:flutter/material.dart';

class FitpickHome extends StatefulWidget {
  const FitpickHome({
    super.key,
    required this.dark,
    required this.onThemeChanged,
  });
  final bool dark;
  final VoidCallback onThemeChanged;
  @override
  State<FitpickHome> createState() => _FitpickHomeState();
}

class _FitpickHomeState extends State<FitpickHome> {
  int selected = 0;
  final menu = const [
    '대시보드',
    '매출 현황',
    '회원 관리',
    '　└ 리뷰 관리',
    '　└ 문의 관리',
    '주문 관리',
    '재고 관리',
    '결재 관리',
    '발주 관리',
    '대리점 관리',
    '계약 관리',
  ];
  @override
  Widget build(BuildContext context) {
    final title = menu[selected].trim();
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return Scaffold(
      drawer: wide ? null : Drawer(child: _sidebar(inDrawer: true)),
      body: Row(
        children: [
          if (wide) _sidebar(),
          Expanded(
            child: Column(
              children: [
                wide ? _bar() : _mobileBar(),
                Expanded(child: _content(title)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar({bool inDrawer = false}) => Container(
    width: inDrawer ? double.infinity : 220,
    color: const Color(0xff064d47),
    padding: const EdgeInsets.fromLTRB(20, 28, 16, 16),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SHOEFIT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const Text(
            'HEADQUARTERS ADMIN',
            style: TextStyle(
              color: Color(0xffa7d0ca),
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 30),
          _group('본사 운영센터', menu, 0),
          const SizedBox(height: 22),
          const Text(
            '본사 관리자 · SHOEFIT',
            style: TextStyle(color: Color(0xffa7d0ca), fontSize: 11),
          ),
        ],
      ),
    ),
  );
  Widget _group(String name, List<String> values, int offset) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        style: const TextStyle(
          color: Color(0xff87a0be),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 8),
      ...values.asMap().entries.map(
        (e) => InkWell(
          onTap: () => setState(() => selected = offset + e.key),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: selected == offset + e.key
                  ? const Color(0xff0c6b63)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.diamond_outlined,
                  size: 13,
                  color: Color(0xffc2ded9),
                ),
                const SizedBox(width: 8),
                Text(
                  e.value,
                  style: TextStyle(
                    color: selected == offset + e.key
                        ? Colors.white
                        : const Color(0xffc2ded9),
                    fontSize: 13,
                    fontWeight: selected == offset + e.key
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  Widget _bar() => Container(
    height: 78,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.black12)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'HEADQUARTERS · OPERATIONS CENTER',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                '본사 관리자',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onThemeChanged,
          icon: Icon(
            widget.dark ? Icons.light_mode : Icons.dark_mode,
            size: 17,
          ),
          label: Text(widget.dark ? '라이트 모드' : '다크 모드'),
        ),
      ],
    ),
  );
  Widget _mobileBar() => Builder(
    builder: (context) => Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffe6eceb))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'SHOEFIT · 본사 관리자',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: widget.onThemeChanged,
            icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
    ),
  );
  Widget _content(String title) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '본사 운영센터 · HEADQUARTERS',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          title == '주문 관리'
              ? '대리점 처리 결과가 실시간으로 반영되는 주문 현황입니다.'
              : '본사 운영 현황과 주요 업무를 한눈에 확인하세요.',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 25),
        title == '대시보드'
            ? _dashboard()
            : title == '주문 관리'
            ? _orders()
            : Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    '$title 화면\n\n관리 기능을 연결할 수 있는 화면입니다.',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
      ],
    ),
  );
  Widget _dashboard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: const [
          _HqMetric('오늘 매출', '₩324.8M', '▲ 8.4%', Icons.payments_outlined),
          _HqMetric('진행 주문', '1,248', '▲ 8.4%', Icons.shopping_bag_outlined),
          _HqMetric('대여 가능', '86', '▲ 3.1%', Icons.inventory_2_outlined),
          _HqMetric(
            '확인 필요',
            '12',
            '주의',
            Icons.priority_high_rounded,
            alert: true,
          ),
        ],
      ),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 620
            ? Column(
                children: [
                  _hqPanel('운영 현황', _notices()),
                  const SizedBox(height: 18),
                  _hqPanel('실시간 알림', _alerts()),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _hqPanel('운영 현황', _notices())),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: _hqPanel('실시간 알림', _alerts())),
                ],
              ),
      ),
    ],
  );

  Widget _hqPanel(String title, Widget body) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffe4ebea)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            const Text(
              '전체 보기  ›',
              style: TextStyle(
                color: Color(0xff064d47),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        body,
      ],
    ),
  );

  Widget _notices() => Column(
    children: const [
      _HqRow('공지', '2026년 추석 연휴 배송 및 고객센터 운영 안내', '09.28'),
      _HqRow('이벤트', '10월 FITPICK 멤버십 더블 포인트 이벤트', '09.27'),
      _HqRow('운영', '강남점 반품 처리 완료 · 주문 상태 반영', '오늘'),
      _HqRow('공지', '신규 상품 라인업 및 가격 정책 공지', '09.26'),
    ],
  );

  Widget _alerts() => Column(
    children: const [
      _HqRow('알림', '재고 30% 미만 상품 3건', '10:24'),
      _HqRow('알림', '강남점 반품 처리 완료', '09:18'),
      _HqRow('알림', '발주 결재 승인 요청', '08:52'),
      _HqRow('알림', '신규 회원 가입 12명', '08:30'),
    ],
  );
  Widget _orders() {
    final rows = [
      ['FP-202609-120', '뉴발란스 530', '김민수', '강남점', '배송중'],
      ['FP-202609-121', '(W) 나이키 에어포스 1', '이서연', '마포점', '배송완료'],
      ['FP-202609-122', '(K) 아디다스 삼바', '박준호', '성동점', '수령완료'],
      ['FP-202609-123', '(W) 푸마 스웨이드', '최유진', '송파점', '반납완료'],
      ['FP-202609-124', '나이키 덩크 로우', '정하늘', '서초점', '배송중'],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  '주문 목록',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                OutlinedButton(onPressed: () {}, child: const Text('전체 보기  ›')),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              children: ['전체', '배송중', '배송완료', '수령완료', '반납완료']
                  .map(
                    (e) => FilterChip(
                      label: Text(e),
                      selected: e == '전체',
                      onSelected: (_) {},
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('주문번호')),
                  DataColumn(label: Text('상품명')),
                  DataColumn(label: Text('고객')),
                  DataColumn(label: Text('수령 대리점')),
                  DataColumn(label: Text('상태')),
                  DataColumn(label: Text('상세')),
                ],
                rows: rows
                    .map(
                      (r) => DataRow(
                        cells: [
                          DataCell(Text(r[0])),
                          DataCell(Text(r[1])),
                          DataCell(Text(r[2])),
                          DataCell(Text(r[3])),
                          DataCell(Text(r[4])),
                          DataCell(
                            TextButton(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('주문 상세'),
                                  content: Text(r.join('\n')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('닫기'),
                                    ),
                                  ],
                                ),
                              ),
                              child: const Text('상세보기'),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HqMetric extends StatelessWidget {
  const _HqMetric(
    this.label,
    this.value,
    this.change,
    this.icon, {
    this.alert = false,
  });
  final String label;
  final String value;
  final String change;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 178,
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
          Icon(
            icon,
            size: 21,
            color: alert ? const Color(0xffd85656) : const Color(0xff064d47),
          ),
          const SizedBox(height: 13),
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
            change,
            style: TextStyle(
              color: alert ? const Color(0xffd85656) : const Color(0xff168e5d),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _HqRow extends StatelessWidget {
  const _HqRow(this.type, this.text, this.date);
  final String type;
  final String text;
  final String date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xffe5f2f0),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            type,
            style: const TextStyle(
              color: Color(0xff064d47),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          date,
          style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
        ),
      ],
    ),
  );
}
