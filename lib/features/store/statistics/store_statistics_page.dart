import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/api/store_api.dart';
import '../widgets/store_ui.dart';

/// 매장 통계: GET /statistics?period=daily|weekly|monthly&date=
class StoreStatisticsPage extends StatefulWidget {
  const StoreStatisticsPage({super.key});
  @override
  State<StoreStatisticsPage> createState() => _StoreStatisticsPageState();
}

class _StoreStatisticsPageState extends State<StoreStatisticsPage> {
  static const _periods = {'daily': '일별', 'weekly': '주별', 'monthly': '월별'};
  String _period = 'daily';
  DateTime _date = DateTime.now();

  String get _dateParam =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StoreHeader('매장 통계', '매장 매출·주문·수령·반품 현황을 기간별로 확인하세요.'),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: [for (final e in _periods.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: {_period},
              onSelectionChanged: (v) => setState(() => _period = v.first),
            ),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_dateParam.replaceAll('-', '.')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncBody<Map<String, dynamic>>(
          key: ValueKey('$_period$_dateParam'),
          load: () => StoreApi.instance.map('/statistics', {'period': _period, 'date': _dateParam}),
          builder: (context, s, reload) {
            final series = (s['sales_series'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
            final top = (s['pickup_by_product'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
            final totalPickup = top.fold<int>(0, (a, b) => a + (b['quantity'] as num).toInt());
            final avg = s['avg_pickup_minutes'];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    StoreMetric('${_periods[_period]} 매출', won(s['sales']), Icons.payments_outlined),
                    StoreMetric('매장 주문', '${s['orders']}건', Icons.shopping_bag_outlined),
                    StoreMetric('수령 현황', '수령 ${s['pickups']}건', Icons.inventory_2_outlined),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, c) {
                    final chart = StoreCard(title: '${_periods[_period]} 매출 추이', child: _chart(series));
                    final metrics = StoreCard(
                      title: '운영 지표',
                      child: Column(
                        children: [
                          _row('수령 완료', '${s['pickups']}건'),
                          _row('반품 접수', '${s['returns']}건'),
                          _row('평균 수령 소요 시간', avg == null ? '-' : '$avg분'),
                        ],
                      ),
                    );
                    return c.maxWidth < 620
                        ? Column(children: [chart, metrics])
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Expanded(flex: 3, child: chart), const SizedBox(width: 18), Expanded(flex: 2, child: metrics)],
                          );
                  },
                ),
                StoreCard(
                  title: '수령 완료 제품별 수량',
                  child: top.isEmpty
                      ? const Text('이 기간의 수령 내역이 없습니다.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('총 수령 수량 $totalPickup개', style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            for (var i = 0; i < top.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    SizedBox(width: 160, child: Text('${i + 1}. ${top[i]['p_name'] ?? top[i]['p_code']}', overflow: TextOverflow.ellipsis)),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: (top[i]['quantity'] as num) / (top.first['quantity'] as num),
                                        minHeight: 8,
                                        color: storeGreen,
                                        backgroundColor: const Color(0xffe3ece9),
                                      ),
                                    ),
                                    SizedBox(width: 56, child: Text('${top[i]['quantity']}개', textAlign: TextAlign.right)),
                                  ],
                                ),
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

  Widget _chart(List<Map<String, dynamic>> series) {
    final maxY = series.fold<double>(0, (m, e) => (e['sales'] as num) > m ? (e['sales'] as num).toDouble() : m);
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.2,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${series[v.toInt()]['label']}', style: const TextStyle(fontSize: 11)),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(won(rod.toY), const TextStyle(color: Colors.white)),
            ),
          ),
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: (series[i]['sales'] as num).toDouble(),
                  width: 22,
                  color: const Color(0xff7cc4b8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(color: Colors.blueGrey)),
      ],
    ),
  );
}
