import 'package:flutter/material.dart';
import '../data/hq_api.dart';
import '../widgets/hq_page_frame.dart';

class ApprovalPage extends StatefulWidget {
  const ApprovalPage({super.key});
  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  late Future<Map<String, dynamic>> _approvals;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _approvals = HqApi.instance.get('/api/v1/headquarters/approvals');
  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '결재 관리',
    description: '발주 품의의 팀장·이사 단계와 처리 이력을 관리합니다.',
    action: FilledButton.icon(
      onPressed: _create,
      icon: const Icon(Icons.add),
      label: const Text('품의 작성'),
    ),
    child: Column(
      children: [
        const HqNotice(
          warning: true,
          title: '승인 권한은 서버 직원 직급으로 확인됩니다.',
          message:
              '직원 이메일 연결 전에는 본사 세션이 승인 권한을 얻지 못합니다. 견적 데이터에 상품코드·제조사 연결도 없어 해당 관계가 보완될 때까지 품의 생성과 최종 발주가 차단됩니다.',
        ),
        const SizedBox(height: 16),
        HqPanel(
          title: '발주 품의 목록',
          trailing: IconButton(
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
          child: HqLoadState(
            future: _approvals,
            emptyTitle: '등록된 품의가 없습니다.',
            emptyMessage: '현재 결재 저장소에 실제 품의가 없습니다.',
            builder: (data) {
              final rows = (data['items'] as List).cast<Map<String, dynamic>>();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('품의 ID')),
                    DataColumn(label: Text('상품코드')),
                    DataColumn(label: Text('수량')),
                    DataColumn(label: Text('결재 단계')),
                    DataColumn(label: Text('상태')),
                    DataColumn(label: Text('처리 이력')),
                    DataColumn(label: Text('액션')),
                  ],
                  rows: rows
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text('${item['id']}')),
                            DataCell(Text('${item['product_code'] ?? '-'}')),
                            DataCell(Text('${item['quantity'] ?? '-'}')),
                            DataCell(Text(_stage(item['stage']))),
                            DataCell(Text('${item['status'] ?? '-'}')),
                            DataCell(
                              Text(
                                '${(item['history'] as List?)?.length ?? 0}건',
                              ),
                            ),
                            DataCell(
                              item['status'] == 'pending'
                                  ? Wrap(
                                      spacing: 4,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              _decide(item, 'approve'),
                                          child: const Text('승인'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              _decide(item, 'reject'),
                                          child: const Text('반려'),
                                        ),
                                      ],
                                    )
                                  : const Text('완료'),
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

  String _stage(dynamic value) => switch (value) {
    'team_leader' => '팀장 승인',
    'director' => '이사 승인',
    'rejected' => '반려',
    _ => '${value ?? '-'}',
  };
  Future<void> _decide(Map<String, dynamic> item, String decision) async {
    final id = item['id'];
    if (id == null) return;
    try {
      await HqApi.instance.patch(
        '/api/v1/headquarters/approvals/$id/decision',
        body: {'decision': decision},
      );
      if (mounted) {
        setState(_load);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decision == 'approve' ? '승인 처리했습니다.' : '반려 처리했습니다.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) _error(error);
    }
  }

  Future<void> _create() async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(),
        qty = TextEditingController(),
        quote = TextEditingController(),
        manufacturer = TextEditingController(),
        reason = TextEditingController();
    String? value(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('발주 품의 작성'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(code, '상품코드'),
                  _field(qty, '발주 수량', numeric: true),
                  _field(quote, '견적 seq', numeric: true),
                  _field(manufacturer, '제조사 ID'),
                  _field(reason, '품의 사유', maxLines: 3),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await HqApi.instance.post(
                  '/api/v1/headquarters/approvals',
                  body: {
                    'product_code': value(code),
                    'quantity': int.parse(qty.text),
                    'quotation_seq': int.parse(quote.text),
                    'manufacturer_id': value(manufacturer),
                    'reason': value(reason),
                  },
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) setState(_load);
              } catch (error) {
                if (mounted) _error(error);
              }
            },
            child: const Text('상신'),
          ),
        ],
      ),
    );
    code.dispose();
    qty.dispose();
    quote.dispose();
    manufacturer.dispose();
    reason.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      validator: (text) {
        if (text == null || text.trim().isEmpty) return '$label 입력이 필요합니다.';
        if (numeric && int.tryParse(text) == null) return '숫자로 입력해 주세요.';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  void _error(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));
}
