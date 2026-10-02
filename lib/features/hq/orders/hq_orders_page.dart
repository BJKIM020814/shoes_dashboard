import 'package:flutter/material.dart';
import '../data/hq_api.dart';
import '../widgets/hq_page_frame.dart';

class HqOrdersPage extends StatefulWidget {
  const HqOrdersPage({super.key});
  @override
  State<HqOrdersPage> createState() => _HqOrdersPageState();
}

class _HqOrdersPageState extends State<HqOrdersPage> {
  late Future<Map<String, dynamic>> _orders;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _orders = HqApi.instance.get('/api/v1/headquarters/orders');

  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '주문 관리',
    description: '고객 앱에서 생성된 주문과 상품 정보를 확인합니다.',
    action: IconButton(
      tooltip: '새로고침',
      onPressed: () => setState(_load),
      icon: const Icon(Icons.refresh),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HqNotice(
          warning: true,
          title: '기존 주문 스키마의 표시 제한',
          message:
              '현재 DB에는 주문 수량·결제 상세·수령 대리점·배송 상태가 저장되지 않습니다. 상품코드와 실제 주문 금액만 표시하며, 대리점 처리 결과와 추정 상태는 덧붙이지 않습니다.',
        ),
        const SizedBox(height: 16),
        HqPanel(
          title: '고객 주문 목록',
          child: HqLoadState(
            future: _orders,
            emptyTitle: '주문 내역이 없습니다.',
            emptyMessage: '현재 purchase 테이블에 등록된 실제 주문이 없습니다.',
            builder: (data) {
              final rows = (data['items'] as List).cast<Map<String, dynamic>>();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('주문 시각')),
                    DataColumn(label: Text('고객 ID')),
                    DataColumn(label: Text('상품코드')),
                    DataColumn(label: Text('상품명')),
                    DataColumn(label: Text('브랜드')),
                    DataColumn(label: Text('결제액')),
                    DataColumn(label: Text('환불')),
                    DataColumn(label: Text('상세')),
                  ],
                  rows: rows
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(Text(_date(row['purchased_at']))),
                            DataCell(Text('${row['customer_id']}')),
                            DataCell(Text('${row['product_code']}')),
                            DataCell(Text('${row['product_name']}')),
                            DataCell(Text('${row['brand']}')),
                            DataCell(Text('${row['paid_amount']}원')),
                            DataCell(
                              Text(row['refunded'] == true ? '환불됨' : '환불 아님'),
                            ),
                            DataCell(
                              TextButton(
                                onPressed: () => _showDetail(context, row),
                                child: const Text('상세보기'),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null
        ? '-'
        : '${parsed.toLocal().year}.${parsed.toLocal().month.toString().padLeft(2, '0')}.${parsed.toLocal().day.toString().padLeft(2, '0')}';
  }

  void _showDetail(BuildContext context, Map<String, dynamic> row) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('주문 상세'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detail(
                  '상품',
                  '${row['product_name']} (${row['product_code']})',
                ),
                _detail('브랜드', '${row['brand']}'),
                _detail('고객 ID', '${row['customer_id']}'),
                _detail('본사 ID', '${row['head_office_id']}'),
                _detail('주문 시각', '${row['purchased_at']}'),
                _detail('결제액', '${row['paid_amount']}원'),
                _detail('수량', 'DB 미제공'),
                _detail('대리점/수령상태', 'DB 미제공'),
                _detail('결제수단 상세', 'DB 미제공'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(color: Colors.blueGrey)),
        ),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}
