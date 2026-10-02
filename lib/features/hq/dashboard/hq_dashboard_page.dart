import 'package:flutter/material.dart';
import '../data/hq_api.dart';
import '../widgets/hq_page_frame.dart';

class HqDashboardPage extends StatelessWidget {
  const HqDashboardPage({super.key});
  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '본사 운영 대시보드',
    description: '실제 주문·매출·재고 데이터를 요약합니다.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: HqApi.instance.get('/api/v1/headquarters/orders'),
          builder: (context, snapshot) {
            final total = snapshot.data?['total'];
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                HqMetricCard(
                  label: '등록 주문',
                  value: snapshot.hasError
                      ? '확인 불가'
                      : total?.toString() ?? '불러오는 중',
                  icon: Icons.shopping_bag_outlined,
                  caption: '실제 purchase 행 기준',
                ),
                const HqMetricCard(
                  label: '매출 집계',
                  value: '매출 현황에서 조회',
                  icon: Icons.payments_outlined,
                  caption: '기간 선택 후 확인',
                ),
                const HqMetricCard(
                  label: '재고 상태',
                  value: '현재고 기준 필요',
                  icon: Icons.inventory_2_outlined,
                  caption: '검증 가능한 수량만 표시',
                ),
                const HqMetricCard(
                  label: '결재 권한',
                  value: '직원 연결 필요',
                  icon: Icons.fact_check_outlined,
                  caption: '직원 직급을 서버에서 확인',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const HqNotice(
          warning: true,
          title: '대시보드 지표는 모두 실제 서버 데이터 기반입니다.',
          message:
              '미연결·미정의된 값은 임의의 숫자로 채우지 않습니다. 주문을 조회할 수 없거나 권한이 연결되지 않은 경우에는 해당 상태를 그대로 표시합니다.',
        ),
        const SizedBox(height: 18),
        const HqPanel(
          title: '운영 준비 항목',
          child: Column(
            children: [
              _ChecklistRow(
                '직원 로그인 이메일을 employee 문서에 연결',
                Icons.person_add_alt_1_outlined,
              ),
              _ChecklistRow('주문에 상품 수량·수령 지점·상태 연결', Icons.link_outlined),
              _ChecklistRow(
                '현재고와 입출고 원장을 상품코드 기준으로 연결',
                Icons.inventory_outlined,
              ),
              _ChecklistRow('견적에 상품코드·제조사 ID 지정', Icons.request_quote_outlined),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Icon(icon, color: hqGreen, size: 19),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    ),
  );
}
