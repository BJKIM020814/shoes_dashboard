import 'package:flutter/material.dart';
import '../data/hq_api.dart';
import '../widgets/hq_page_frame.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});
  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _data = HqApi.instance.get('/api/v1/headquarters/members');

  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '회원 관리',
    description: '고객 DB의 회원 정보와 구매 집계를 조회합니다.',
    action: IconButton(
      tooltip: '새로고침',
      onPressed: () => setState(_load),
      icon: const Icon(Icons.refresh),
    ),
    child: HqPanel(
      title: '회원 목록',
      child: HqLoadState(
        future: _data,
        emptyTitle: '회원 데이터가 없습니다.',
        emptyMessage: 'MySQL customer 테이블에 실제 회원이 없습니다.',
        builder: (data) {
          final rows = (data['items'] as List).cast<Map<String, dynamic>>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('총 ${data['total'] ?? rows.length}명'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('회원 ID')),
                    DataColumn(label: Text('이름')),
                    DataColumn(label: Text('연락처')),
                    DataColumn(label: Text('성별')),
                    DataColumn(label: Text('나이')),
                    DataColumn(label: Text('구매')),
                    DataColumn(label: Text('누적 결제')),
                  ],
                  rows: rows
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(Text('${r['customer_id'] ?? '-'}')),
                            DataCell(Text('${r['name'] ?? '-'}')),
                            DataCell(Text('${r['phone'] ?? '-'}')),
                            DataCell(Text('${r['gender'] ?? '-'}')),
                            DataCell(Text('${r['age'] ?? '-'}')),
                            DataCell(Text('${r['purchase_count'] ?? 0}건')),
                            DataCell(Text('${r['totalprice'] ?? 0}원')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
