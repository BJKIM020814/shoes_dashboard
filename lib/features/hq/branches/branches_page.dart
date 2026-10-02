import 'package:flutter/material.dart';
import '../data/hq_api.dart';
import '../widgets/hq_page_frame.dart';

class BranchesPage extends StatefulWidget {
  const BranchesPage({super.key});
  @override
  State<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends State<BranchesPage> {
  bool _seoulOnly = true;
  late Future<Map<String, dynamic>> _branches;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _branches = HqApi.instance.get(
    '/api/v1/headquarters/branches',
    query: {'seoul_only': '$_seoulOnly'},
  );
  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '대리점 관리',
    description: '등록된 지점의 주소와 기존 좌표를 확인합니다.',
    action: IconButton(
      onPressed: () => setState(_load),
      tooltip: '새로고침',
      icon: const Icon(Icons.refresh),
    ),
    child: Column(
      children: [
        HqPanel(
          child: Row(
            children: [
              const Icon(Icons.map_outlined, color: hqGreen),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '지도 API 연동 준비',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Text(
                'Naver 지도 미연결',
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        HqPanel(
          title: '대리점 목록',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('서울만'),
              Switch(
                value: _seoulOnly,
                onChanged: (value) => setState(() {
                  _seoulOnly = value;
                  _load();
                }),
              ),
            ],
          ),
          child: HqLoadState(
            future: _branches,
            emptyTitle: '등록된 대리점이 없습니다.',
            emptyMessage: 'authorized_dealer에 실제 지점 데이터가 없습니다.',
            builder: (data) {
              final items = (data['items'] as List)
                  .cast<Map<String, dynamic>>();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('지점 ID')),
                    DataColumn(label: Text('지점명')),
                    DataColumn(label: Text('사업자번호')),
                    DataColumn(label: Text('담당자')),
                    DataColumn(label: Text('주소')),
                    DataColumn(label: Text('좌표')),
                  ],
                  rows: items
                      .map(
                        (branch) => DataRow(
                          cells: [
                            DataCell(Text('${branch['id']}')),
                            DataCell(Text('${branch['name']}')),
                            DataCell(Text('${branch['dealer_number']}')),
                            DataCell(Text('${branch['manager']}')),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: Text(
                                  '${branch['address']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                branch['latitude'] == null ||
                                        branch['longitude'] == null
                                    ? '미등록'
                                    : '${branch['latitude']}, ${branch['longitude']}',
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
        const SizedBox(height: 14),
        const HqNotice(
          title: '지도·주소 검색은 별도 연결입니다.',
          message:
              '현재는 저장된 주소와 위도·경도만 조회합니다. 지도 타일, 주소 검색 및 주소→좌표 변환은 네이버 API 설정 후 연결할 수 있습니다. 임의 좌표는 표시하지 않습니다.',
        ),
      ],
    ),
  );
}
