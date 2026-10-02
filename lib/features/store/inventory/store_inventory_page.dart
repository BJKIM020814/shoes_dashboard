import 'package:flutter/material.dart';
import '../../../core/api/store_api.dart';
import '../widgets/store_ui.dart';

/// 재고 관리: 재고 현황(GET /inventory) / 입출고 내역(GET /inventory/movements) + 본사 발송 수령 처리
class StoreInventoryPage extends StatefulWidget {
  const StoreInventoryPage({super.key});
  @override
  State<StoreInventoryPage> createState() => _StoreInventoryPageState();
}

class _StoreInventoryPageState extends State<StoreInventoryPage> {
  final _api = StoreApi.instance;
  bool _movements = false;
  bool _lowOnly = false;
  String _query = '';
  Key _reloadKey = UniqueKey();

  Future<Map<String, List<Map<String, dynamic>>>> _load() async => {
    'items': await _api.list('/inventory'),
    'moves': await _api.list('/inventory/movements'),
    'shipments': await _api.list('/inventory/shipments', {'pending_only': 'true'}),
  };

  Future<void> _receive(Map<String, dynamic> shipment, List<Map<String, dynamic>> items) async {
    String? productId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('입고 상품 수령'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('발송 수량 ${shipment['quantity']}개'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: productId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '재고에 더할 상품', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('재고 반영 안 함')),
                  for (final i in items)
                    DropdownMenuItem(
                      value: '${i['productId']}',
                      child: Text('${i['product']?['p_name'] ?? i['productId']}'),
                    ),
                ],
                onChanged: (v) => setLocal(() => productId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('수령 처리')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final staff = await ensureStaffId(context);
    if (staff == null || !mounted) return;
    try {
      await _api.post('/inventory/shipments/${shipment['id']}/receive', {
        'staff_id': staff,
        if (productId != null) 'product_id': productId,
      });
      if (mounted) showStoreMessage(context, '입고 수령 처리되었습니다.');
      setState(() => _reloadKey = UniqueKey());
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
        const StoreHeader('재고 관리', '매장 상품별 재고와 입출고 내역을 확인하세요.'),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('재고 현황')),
            ButtonSegment(value: true, label: Text('입출고 내역')),
          ],
          selected: {_movements},
          onSelectionChanged: (v) => setState(() => _movements = v.first),
        ),
        const SizedBox(height: 16),
        AsyncBody<Map<String, List<Map<String, dynamic>>>>(
          key: _reloadKey,
          load: _load,
          builder: (context, data, reload) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data['shipments']!.isNotEmpty && !_movements) _shipments(data),
              _movements ? _moves(data['moves']!) : _stock(data['items']!),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _shipments(Map<String, List<Map<String, dynamic>>> data) => StoreCard(
    title: '수령 대기 중인 본사 발송 ${data['shipments']!.length}건',
    child: Column(
      children: [
        for (final s in data['shipments']!)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('발송 ${s['quantity']}개'),
            subtitle: Text('${shortDate(s['sentAt'])} · 발송자 ${s['employeeId'] ?? '-'}'),
            trailing: FilledButton(
              onPressed: () => _receive(s, data['items']!),
              child: const Text('수령 처리'),
            ),
          ),
      ],
    ),
  );

  Widget _stock(List<Map<String, dynamic>> items) {
    final rows = items.where((i) {
      final name = '${i['product']?['p_name'] ?? ''} ${i['productId']}';
      return (!_lowOnly || i['low_stock'] == true) && (_query.isEmpty || name.contains(_query));
    }).toList();
    return StoreCard(
      title: '재고 현황',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(label: const Text('전체'), selected: !_lowOnly, onSelected: (_) => setState(() => _lowOnly = false)),
              ChoiceChip(label: const Text('재고 부족'), selected: _lowOnly, onSelected: (_) => setState(() => _lowOnly = true)),
              SizedBox(
                width: 240,
                child: TextField(
                  decoration: const InputDecoration(hintText: '상품명 또는 코드 검색', isDense: true, border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('표시할 재고가 없습니다.')),
          if (rows.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('상품코드')),
                  DataColumn(label: Text('상품명')),
                  DataColumn(label: Text('사이즈')),
                  DataColumn(label: Text('색상')),
                  DataColumn(label: Text('수량'), numeric: true),
                  DataColumn(label: Text('상태')),
                ],
                rows: [
                  for (final i in rows)
                    DataRow(cells: [
                      DataCell(Text('${i['productId']}')),
                      DataCell(Text('${i['product']?['p_name'] ?? '-'}')),
                      DataCell(Text('${i['product']?['p_size'] ?? '-'}')),
                      DataCell(Text('${i['product']?['p_color'] ?? '-'}')),
                      DataCell(Text('${i['quantity']}')),
                      DataCell(StoreChip(
                        i['low_stock'] == true ? '재고 부족' : '정상',
                        tone: i['low_stock'] == true ? StoreTone.bad : StoreTone.good,
                      )),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _moves(List<Map<String, dynamic>> moves) => StoreCard(
    title: '입출고 내역',
    child: moves.isEmpty
        ? const Text('입출고 내역이 없습니다.')
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('일시')),
                DataColumn(label: Text('구분')),
                DataColumn(label: Text('상품')),
                DataColumn(label: Text('사이즈')),
                DataColumn(label: Text('색상')),
                DataColumn(label: Text('수량'), numeric: true),
                DataColumn(label: Text('처리자')),
                DataColumn(label: Text('비고')),
              ],
              rows: [
                for (final m in moves)
                  DataRow(cells: [
                    DataCell(Text(shortDate(m['at']))),
                    DataCell(StoreChip('${m['kind']}', tone: m['kind'] == '입고' ? StoreTone.good : StoreTone.warn)),
                    DataCell(Text('${m['p_name'] ?? '-'}')),
                    DataCell(Text('${m['size'] ?? '-'}')),
                    DataCell(Text('${m['color'] ?? '-'}')),
                    DataCell(Text('${m['quantity'] ?? '-'}')),
                    DataCell(Text('${m['staff_id'] ?? '-'}')),
                    DataCell(Text('${m['note'] ?? ''}')),
                  ]),
              ],
            ),
          ),
  );
}
