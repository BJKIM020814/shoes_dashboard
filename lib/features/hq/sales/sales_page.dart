import 'package:flutter/material.dart';
import '../data/hq_api.dart';
import '../widgets/hq_page_frame.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  String _group = 'day';
  late Future<Map<String, dynamic>> _sales;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final start = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final end = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
    ).add(const Duration(days: 1));
    _sales = HqApi.instance.get(
      '/api/v1/headquarters/sales/summary',
      query: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'group_by': _group,
      },
    );
  }

  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '매출 현황',
    description: '기간과 상품 기준으로 실제 결제 매출을 조회합니다. 환불 완료 금액은 매출에서 제외합니다.',
    action: OutlinedButton.icon(
      onPressed: _pickRange,
      icon: const Icon(Icons.date_range),
      label: Text('${_fmt(_range.start)} – ${_fmt(_range.end)}'),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              label: const Text('일별'),
              selected: _group == 'day',
              onSelected: (_) => setState(() {
                _group = 'day';
                _load();
              }),
            ),
            ChoiceChip(
              label: const Text('상품별'),
              selected: _group == 'product',
              onSelected: (_) => setState(() {
                _group = 'product';
                _load();
              }),
            ),
            IconButton(
              tooltip: '새로고침',
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 14),
        HqLoadState(
          future: _sales,
          emptyTitle: '기간 내 매출이 없습니다.',
          emptyMessage: '선택 기간의 실제 구매 데이터가 없습니다.',
          builder: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  HqMetricCard(
                    label: '환불 제외 순매출',
                    value: _money(data['net_sales']),
                    icon: Icons.payments_outlined,
                    caption: '선택 기간 기준',
                  ),
                  HqMetricCard(
                    label: '유효 주문',
                    value: '${data['purchase_count'] ?? 0}건',
                    icon: Icons.shopping_bag_outlined,
                    caption: '환불완료 건 제외',
                  ),
                  HqMetricCard(
                    label: '제외 환불',
                    value: '${data['excluded_refund_count'] ?? 0}건',
                    icon: Icons.assignment_return_outlined,
                    caption: '환불 금액은 미합산',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              HqPanel(
                title: _group == 'day' ? '일별 매출' : '상품별 매출',
                child: _table(data['items'] as List? ?? const []),
              ),
              const SizedBox(height: 16),
              const HqNotice(
                warning: true,
                title: '집계 차원 제한',
                message:
                    '현재 purchase에는 판매 수량과 대리점 연결키가 없습니다. 따라서 수량 집계 및 대리점별 매출 화면은 아직 제공할 수 없습니다.',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _table(List rows) => rows.isEmpty
      ? const HqEmpty(title: '집계 결과가 없습니다.', message: '조건에 해당하는 실제 매출이 없습니다.')
      : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(_group == 'day' ? '날짜' : '상품코드')),
              if (_group == 'product') const DataColumn(label: Text('상품명')),
              const DataColumn(label: Text('구매 건수')),
              const DataColumn(label: Text('환불 제외 매출')),
            ],
            rows: rows
                .map(
                  (row) => DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${row[_group == 'day' ? 'period' : 'product_code']}',
                        ),
                      ),
                      if (_group == 'product')
                        DataCell(Text('${row['product_name']}')),
                      DataCell(Text('${row['purchase_count']}건')),
                      DataCell(Text(_money(row['net_sales']))),
                    ],
                  ),
                )
                .toList(),
          ),
        );

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _load();
      });
    }
  }

  String _money(dynamic value) =>
      '${(value is num ? value : 0).toStringAsFixed(0)}원';
  String _fmt(DateTime date) => '${date.month}.${date.day}';
}
