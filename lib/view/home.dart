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
    '판매 관리',
    '대리점 관리',
    '계약 관리',
  ];
  final store = const [
    '대시보드',
    '수령 확인',
    '반품 처리',
    '재고 관리',
    '주문 현황',
    '매장 통계',
    '매장 정보',
  ];
  @override
  Widget build(BuildContext context) {
    final title = selected < menu.length
        ? menu[selected].trim()
        : store[selected - menu.length];
    return Scaffold(
      body: Row(
        children: [
          _sidebar(),
          Expanded(
            child: Column(
              children: [
                _bar(),
                Expanded(child: _content(title)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() => Container(
    width: 250,
    color: const Color(0xff10233e),
    padding: const EdgeInsets.fromLTRB(20, 28, 16, 16),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✦ FITPICK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const Text(
            'TABLET ADMIN PROTOTYPE',
            style: TextStyle(
              color: Color(0xff7e9abb),
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 30),
          _group('HEADQUARTERS', menu, 0),
          const SizedBox(height: 22),
          _group('GANGNAM STORE', store, menu.length),
          const SizedBox(height: 22),
          const Text(
            'Designed for 11–13 inch PAD',
            style: TextStyle(color: Color(0xff6f89a9), fontSize: 10),
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
                  ? const Color(0xff24466f)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.diamond_outlined,
                  size: 13,
                  color: Color(0xff91a9c4),
                ),
                const SizedBox(width: 8),
                Text(
                  e.value,
                  style: TextStyle(
                    color: selected == offset + e.key
                        ? Colors.white
                        : const Color(0xffa8bad0),
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
    height: 92,
    padding: const EdgeInsets.symmetric(horizontal: 30),
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
                'FITPICK OPERATIONS CENTER',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                '안녕하세요, FITPICK 운영팀',
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
  Widget _content(String title) => SingleChildScrollView(
    padding: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '본사 운영센터',
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
              : 'FITPICK 운영 데이터를 관리하는 화면입니다.',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 25),
        title == '주문 관리'
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
