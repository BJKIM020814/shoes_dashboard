import 'package:flutter/material.dart';
import '../../../core/api/store_api.dart';
import '../widgets/store_ui.dart';

/// 반품 처리: 수령 완료 주문 중 반품 대상 선택 -> 접수(POST /returns) -> 환불 완료(POST /returns/{id}/refund)
class ReturnManagementPage extends StatefulWidget {
  const ReturnManagementPage({super.key});
  @override
  State<ReturnManagementPage> createState() => _ReturnManagementPageState();
}

class _ReturnManagementPageState extends State<ReturnManagementPage> {
  final _api = StoreApi.instance;
  static const _reasons = ['사이즈 불일치', '단순 변심', '상품 불량', '오배송'];
  Key _reloadKey = UniqueKey();

  Future<({List<Map<String, dynamic>> candidates, List<Map<String, dynamic>> returns})> _load() async => (
    candidates: await _api.list('/returns/candidates'),
    returns: await _api.list('/returns'),
  );

  void _refresh() => setState(() => _reloadKey = UniqueKey());

  Future<void> _receive(Map<String, dynamic> c) async {
    var reason = _reasons.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('${c['p_name'] ?? c['p_code']} 반품 접수'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('고객 ${c['customer_name']} (${c['customer_id']})'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: '반품 사유', border: OutlineInputBorder()),
                items: [for (final r in _reasons) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => setLocal(() => reason = v ?? reason),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('접수')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final staff = await ensureStaffId(context);
    if (staff == null || !mounted) return;
    try {
      await _api.post('/returns', {
        'customer_id': c['customer_id'],
        'p_code': c['p_code'],
        'reason': reason,
        'staff_id': staff,
      });
      if (mounted) showStoreMessage(context, '반품이 접수되었습니다.');
      _refresh();
    } on StoreApiException catch (e) {
      if (mounted) showStoreMessage(context, e.message);
    }
  }

  Future<void> _refund(Map<String, dynamic> r) async {
    final staff = await ensureStaffId(context);
    if (staff == null || !mounted) return;
    try {
      await _api.post('/returns/${Uri.encodeComponent('${r['customer_id']}')}/refund', {'staff_id': staff});
      if (mounted) showStoreMessage(context, '반품 처리가 완료되었습니다. 주문 상태가 반납완료로 변경됩니다.');
      _refresh();
    } on StoreApiException catch (e) {
      if (mounted) showStoreMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StoreHeader('반품 처리', '반품 접수부터 검수·환불 완료까지 처리하세요. 완료 시 본사 주문 관리에 즉시 반영됩니다.'),
        AsyncBody<({List<Map<String, dynamic>> candidates, List<Map<String, dynamic>> returns})>(
          key: _reloadKey,
          load: _load,
          builder: (context, data, reload) {
            final pending = data.returns.where((r) => r['refund'] != 1 && r['refund'] != true).toList();
            final done = data.returns.where((r) => r['refund'] == 1 || r['refund'] == true).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StoreCard(
                  title: '반품 접수 대상 (수령 완료 주문)',
                  child: data.candidates.isEmpty
                      ? const Text('반품 접수할 주문이 없습니다.')
                      : Column(
                          children: [
                            for (final c in data.candidates)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${c['p_name'] ?? c['p_code']}'),
                                subtitle: Text('${c['customer_name']} · 수령 ${shortDate(c['pickup_date'])}'),
                                trailing: OutlinedButton(onPressed: () => _receive(c), child: const Text('반품 접수')),
                              ),
                          ],
                        ),
                ),
                StoreCard(
                  title: '검수·환불 대기 ${pending.length}건',
                  child: pending.isEmpty
                      ? const Text('처리할 반품이 없습니다.')
                      : Column(
                          children: [
                            for (final r in pending)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${r['p_name'] ?? r['p_id']}'),
                                subtitle: Text('${r['customer_id']} · ${r['reason']} · 접수 ${shortDate(r['p_date'])}'),
                                trailing: FilledButton(onPressed: () => _refund(r), child: const Text('반품 처리 완료')),
                              ),
                          ],
                        ),
                ),
                StoreCard(
                  title: '처리 완료 ${done.length}건',
                  child: done.isEmpty
                      ? const Text('완료된 반품이 없습니다.')
                      : Column(
                          children: [
                            for (final r in done)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${r['p_name'] ?? r['p_id']}'),
                                subtitle: Text('${r['customer_id']} · ${r['reason']} · ${shortDate(r['p_date'])}'),
                                trailing: const StoreChip('반납완료', tone: StoreTone.good),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
