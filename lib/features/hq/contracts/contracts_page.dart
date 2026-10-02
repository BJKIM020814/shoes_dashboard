import 'package:flutter/material.dart';
import '../data/hq_api.dart';
import '../widgets/hq_page_frame.dart';

class ContractsPage extends StatefulWidget {
  const ContractsPage({super.key});
  @override
  State<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends State<ContractsPage> {
  late Future<Map<String, dynamic>> _contracts;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _contracts = HqApi.instance.get('/api/v1/headquarters/contracts');
  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '계약 관리',
    description: '모델별 계약 기간·계약금·종료 기록을 조회합니다.',
    action: IconButton(
      tooltip: '새로고침',
      onPressed: () => setState(_load),
      icon: const Icon(Icons.refresh),
    ),
    child: Column(
      children: [
        const HqNotice(
          warning: true,
          title: '계약 변경은 정책 확정 후 제공됩니다.',
          message:
              '계약 상태 판정과 위약금 산식, 등록·수정·종료 정책이 확정되지 않아 현재는 저장된 계약을 조회만 합니다.',
        ),
        const SizedBox(height: 16),
        HqPanel(
          title: '모델 계약 목록',
          child: HqLoadState(
            future: _contracts,
            emptyTitle: '계약 정보가 없습니다.',
            emptyMessage: '현재 contract 테이블에 실제 계약이 없습니다.',
            builder: (data) {
              final items = (data['items'] as List)
                  .cast<Map<String, dynamic>>();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('모델')),
                    DataColumn(label: Text('관리 담당')),
                    DataColumn(label: Text('계약 시작')),
                    DataColumn(label: Text('계약 종료')),
                    DataColumn(label: Text('계약금')),
                    DataColumn(label: Text('옵션')),
                    DataColumn(label: Text('종료 기록')),
                  ],
                  rows: items
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(
                              Text(
                                '${item['model_name']} (ID ${item['model_id']})',
                              ),
                            ),
                            DataCell(Text('${item['management']}')),
                            DataCell(Text(_date(item['start_date']))),
                            DataCell(Text(_date(item['end_date']))),
                            DataCell(Text('${item['contract_fee']}원')),
                            DataCell(Text('${item['option']}')),
                            DataCell(
                              Text(
                                item['termination_sequence'] == null
                                    ? '없음'
                                    : '${item['termination_date']} · ${item['termination_fee']}',
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
    final date = DateTime.tryParse('$value');
    return date == null
        ? '-'
        : '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
