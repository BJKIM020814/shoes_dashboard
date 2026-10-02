import 'package:flutter/material.dart';
import '../data/hq_api.dart';
import '../widgets/hq_page_frame.dart';

class InquiriesPage extends StatefulWidget {
  const InquiriesPage({super.key});
  @override
  State<InquiriesPage> createState() => _InquiriesPageState();
}

class _InquiriesPageState extends State<InquiriesPage> {
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _data = HqApi.instance.get('/api/v1/headquarters/inquiries');

  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '문의 관리',
    description: '고객 문의와 기존 답변 상태를 조회합니다.',
    action: IconButton(
      tooltip: '새로고침',
      onPressed: () => setState(_load),
      icon: const Icon(Icons.refresh),
    ),
    child: HqPanel(
      title: '문의 목록',
      child: HqLoadState(
        future: _data,
        emptyTitle: '문의 데이터가 없습니다.',
        emptyMessage: 'MySQL contact 테이블에 실제 문의가 없습니다.',
        builder: (data) {
          final rows = (data['items'] as List).cast<Map<String, dynamic>>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('총 ${data['total'] ?? rows.length}건'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('작성일')),
                    DataColumn(label: Text('회원 ID')),
                    DataColumn(label: Text('문의')),
                    DataColumn(label: Text('상태')),
                    DataColumn(label: Text('답변')),
                    DataColumn(label: Text('답변일')),
                  ],
                  rows: rows
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(Text('${r['c_date'] ?? '-'}')),
                            DataCell(Text('${r['customer_id'] ?? '-'}')),
                            DataCell(
                              SizedBox(
                                width: 300,
                                child: Text(
                                  '${r['contact_post'] ?? '-'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Chip(
                                label: Text(
                                  r['c_status'] == 1 ? '답변 완료' : '미답변',
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 300,
                                child: Text(
                                  '${r['c_answer'] ?? '미답변'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text('${r['c_answerdate'] ?? '-'}')),
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
