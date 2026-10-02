import 'package:flutter/material.dart';
import '../../../core/api/store_api.dart';
import '../widgets/store_ui.dart';

/// 대시보드: GET /dashboard (KPI 4개, 오늘의 매장 일정, 운영 현황 공지)
class StoreDashboardPage extends StatefulWidget {
  const StoreDashboardPage({super.key});
  @override
  State<StoreDashboardPage> createState() => _StoreDashboardPageState();
}

class _StoreDashboardPageState extends State<StoreDashboardPage> {
  String _tab = '전체';

  @override
  Widget build(BuildContext context) => AsyncBody<Map<String, dynamic>>(
    load: StoreApi.instance.dashboard,
    builder: (context, d, reload) {
      final storeName = d['store']['name'];
      final k = Map<String, dynamic>.from(d['kpis']);
      final inv = d['inventory'] as Map?;
      final attention = (k['needs_attention'] as num).toInt();
      final notices = (d['notices'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .where((n) => _tab == '전체' || n['category'] == _tab)
          .toList();
      return RefreshIndicator(
        onRefresh: reload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoreHeader('대시보드', '$storeName의 오늘 업무와 매장 소식을 확인하세요.'),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  StoreMetric('오늘 매출', won(k['today_sales']), Icons.payments_outlined,
                      hint: '주문 ${k['today_orders']}건'),
                  StoreMetric('진행 주문', '${k['in_progress_orders']}건',
                      Icons.shopping_bag_outlined),
                  StoreMetric('대여 가능', k['available_stock'] == null ? '-' : '${k['available_stock']}개',
                      Icons.inventory_2_outlined),
                  StoreMetric('확인 필요', '$attention건', Icons.error_outline,
                      hint: attention > 0 ? '주의' : '정상', warn: attention > 0),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, c) {
                  final schedule = _schedule(d, inv);
                  final notice = _notices(notices);
                  return c.maxWidth < 620
                      ? Column(children: [notice, schedule])
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: notice),
                            const SizedBox(width: 18),
                            Expanded(child: schedule),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _schedule(Map<String, dynamic> d, Map? inv) => StoreCard(
    title: '오늘의 매장 일정',
    child: Column(
      children: [
        _row('수령 대기 주문', '${d['pending_pickups']}건'),
        _row('오늘 수령 완료', '${d['today_pickups']}건'),
        _row('반품 접수 / 환불 대기', '${d['today_returns']}건 / ${d['pending_refunds']}건'),
        if (inv != null) _row('입고 검수 예정', '${inv['pending_shipments']}건'),
        if (inv != null) _row('재고 부족 상품', '${inv['low_stock_count']}건'),
      ],
    ),
  );

  Widget _notices(List<Map<String, dynamic>> notices) => StoreCard(
    title: '운영 현황',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final t in const ['전체', '공지', '이벤트', '운영'])
              ChoiceChip(label: Text(t), selected: _tab == t, onSelected: (_) => setState(() => _tab = t)),
          ],
        ),
        const SizedBox(height: 8),
        if (notices.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('등록된 소식이 없습니다.')),
        for (final n in notices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: StoreChip(
              '${n['category']}',
              tone: n['category'] == '이벤트' ? StoreTone.warn : StoreTone.info,
            ),
            title: Text('${n['title']}'),
            trailing: Text(shortDate(n['savedate'], time: false),
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('${n['title']}'),
                content: Text('${n['content']}'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 17, color: storeGreen),
        const SizedBox(width: 9),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
      ],
    ),
  );
}
