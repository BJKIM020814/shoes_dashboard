import 'package:flutter/material.dart';
import '../data/hq_api.dart';
import '../widgets/hq_page_frame.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});
  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _data = HqApi.instance.get('/api/v1/headquarters/reviews');

  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '리뷰 관리',
    description: '고객 리뷰와 상품 옵션 정보를 조회합니다.',
    action: IconButton(
      tooltip: '새로고침',
      onPressed: () => setState(_load),
      icon: const Icon(Icons.refresh),
    ),
    child: HqPanel(
      title: '리뷰 목록',
      child: HqLoadState(
        future: _data,
        emptyTitle: '리뷰 데이터가 없습니다.',
        emptyMessage: 'MySQL review 테이블에 실제 리뷰가 없습니다.',
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
                    DataColumn(label: Text('상품코드')),
                    DataColumn(label: Text('상품명')),
                    DataColumn(label: Text('평점')),
                    DataColumn(label: Text('내용')),
                    DataColumn(label: Text('도움돼요')),
                  ],
                  rows: rows
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(Text('${r['r_date'] ?? '-'}')),
                            DataCell(Text('${r['customer_id'] ?? '-'}')),
                            DataCell(Text('${r['product_code'] ?? '-'}')),
                            DataCell(Text('${r['product_name'] ?? '-'}')),
                            DataCell(Text('${r['rating'] ?? '-'}')),
                            DataCell(
                              SizedBox(
                                width: 280,
                                child: Text(
                                  '${r['context'] ?? '-'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text('${r['likecount'] ?? 0}')),
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
