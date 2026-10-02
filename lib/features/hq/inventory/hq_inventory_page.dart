import 'package:flutter/material.dart';
import '../data/hq_api.dart';
import '../widgets/hq_page_frame.dart';

class HqInventoryPage extends StatefulWidget {
  const HqInventoryPage({super.key});
  @override
  State<HqInventoryPage> createState() => _HqInventoryPageState();
}

class _HqInventoryPageState extends State<HqInventoryPage> {
  late Future<Map<String, dynamic>> _inventory;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _inventory = HqApi.instance.get('/api/v1/headquarters/inventory');
  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '재고 관리',
    description: '상품 옵션코드별 본사 재고와 발주 기준을 확인합니다.',
    action: IconButton(
      tooltip: '새로고침',
      onPressed: () => setState(_load),
      icon: const Icon(Icons.refresh),
    ),
    child: Column(
      children: [
        const HqNotice(
          warning: true,
          icon: Icons.inventory_2_outlined,
          title: '현재고 기준 및 입출고 이력 미연결',
          message:
              '현재 데이터에서 최소수량은 확인할 수 있지만, 상품별 출고 연결이 없어 현재고를 안전하게 계산할 수 없습니다. API는 확인되지 않은 수량과 발주 필요 여부를 null로 표시합니다. 재고 조정은 서버에서 차단됩니다.',
        ),
        const SizedBox(height: 16),
        HqPanel(
          title: '본사 상품별 재고',
          child: HqLoadState(
            future: _inventory,
            emptyTitle: '재고 기준이 등록되지 않았습니다.',
            emptyMessage: 'Firestore office_inventory에 등록된 상품이 없습니다.',
            builder: (data) {
              final items = (data['items'] as List)
                  .cast<Map<String, dynamic>>();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('상품코드')),
                    DataColumn(label: Text('상품명')),
                    DataColumn(label: Text('브랜드')),
                    DataColumn(label: Text('현재고')),
                    DataColumn(label: Text('최소수량')),
                    DataColumn(label: Text('발주 필요')),
                  ],
                  rows: items
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text('${item['product_code']}')),
                            DataCell(Text('${item['product_name']}')),
                            DataCell(Text('${item['brand']}')),
                            DataCell(
                              Text(
                                item['current_quantity']?.toString() ?? '미확인',
                              ),
                            ),
                            DataCell(
                              Text(
                                item['minimum_quantity']?.toString() ?? '미설정',
                              ),
                            ),
                            DataCell(_status(item['reorder_required'])),
                          ],
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const HqPanel(
          title: '재고 변경 기록',
          child: HqEmpty(
            title: '재고 원장 연결 후 표시됩니다.',
            message: '수량 변경 사유와 주문·입출고 식별자를 저장할 데이터 구조가 아직 없습니다.',
            icon: Icons.receipt_long_outlined,
          ),
        ),
      ],
    ),
  );

  Widget _status(dynamic value) => Chip(
    label: Text(
      value == true
          ? '발주 필요'
          : value == false
          ? '정상'
          : '판정 불가',
    ),
    backgroundColor: value == true
        ? const Color(0xffffeee8)
        : value == false
        ? const Color(0xffe7f4ec)
        : const Color(0xfff0f2f3),
    labelStyle: TextStyle(
      fontSize: 11,
      color: value == true
          ? Colors.deepOrange
          : value == false
          ? Colors.green.shade800
          : Colors.blueGrey,
    ),
  );
}
