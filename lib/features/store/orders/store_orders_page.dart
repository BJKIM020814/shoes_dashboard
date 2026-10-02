import 'package:flutter/material.dart';
import '../../../core/api/store_api.dart';
import '../widgets/store_ui.dart';

/// 주문 현황: GET /orders?status=
class StoreOrdersPage extends StatefulWidget {
  const StoreOrdersPage({super.key});
  @override
  State<StoreOrdersPage> createState() => _StoreOrdersPageState();
}

class _StoreOrdersPageState extends State<StoreOrdersPage> {
  static const _statuses = ['전체', '배송중', '배송완료', '수령완료', '반납완료'];
  String _status = '전체';
  String _query = '';

  StoreTone _tone(String s) => switch (s) {
    '수령완료' || '반납완료' => StoreTone.good,
    '배송중' => StoreTone.warn,
    _ => StoreTone.info,
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StoreHeader('주문 현황', '우리 매장과 연결된 주문의 처리 상태를 확인하세요.'),
        StoreCard(
          title: '주문 목록',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final s in _statuses)
                    ChoiceChip(label: Text(s), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '상품명 또는 고객 검색',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AsyncBody<List<Map<String, dynamic>>>(
                // 상태가 바뀌면 key 가 바뀌어 새로 불러온다
                key: ValueKey(_status),
                load: () => StoreApi.instance.list('/orders', {
                  'status': _status == '전체' ? null : _status,
                  'limit': '200',
                }),
                builder: (context, all, reload) {
                  final rows = all
                      .where((o) => _query.isEmpty || '${o['p_name']} ${o['customer_name']} ${o['customer_id']}'.contains(_query))
                      .toList();
                  if (rows.isEmpty) {
                    return const Padding(padding: EdgeInsets.all(24), child: Text('해당 상태의 주문이 없습니다.'));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('주문일')),
                        DataColumn(label: Text('상품명')),
                        DataColumn(label: Text('고객')),
                        DataColumn(label: Text('금액'), numeric: true),
                        DataColumn(label: Text('상태')),
                        DataColumn(label: Text('상세')),
                      ],
                      rows: [
                        for (final o in rows)
                          DataRow(cells: [
                            DataCell(Text(shortDate(o['p_date'], time: false))),
                            DataCell(Text('${o['p_name'] ?? o['p_code']}')),
                            DataCell(Text('${o['customer_name'] ?? o['customer_id']}')),
                            DataCell(Text(won(o['p_price'] ?? 0))),
                            DataCell(StoreChip('${o['status']}', tone: _tone('${o['status']}'))),
                            DataCell(TextButton(onPressed: () => _detail(o), child: const Text('상세보기'))),
                          ]),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _detail(Map<String, dynamic> o) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('${o['p_name'] ?? o['p_code']} 주문 상세'),
      content: Text(
        '상품코드 ${o['p_code']}\n브랜드 ${o['b_name'] ?? '-'}\n'
        '고객 ${o['customer_name']} (${o['customer_id']})\n'
        '금액 ${won(o['p_price'] ?? 0)}\n주문일 ${shortDate(o['p_date'])}\n상태 ${o['status']}',
        style: const TextStyle(height: 1.6),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
    ),
  );
}
