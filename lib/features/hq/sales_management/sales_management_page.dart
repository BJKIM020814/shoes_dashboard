import 'package:flutter/material.dart';
import '../widgets/hq_page_frame.dart';

class SalesManagementPage extends StatelessWidget {
  const SalesManagementPage({super.key});
  @override
  Widget build(BuildContext context) => HqPageFrame(
    title: '제조사 발주 관리',
    description: '결재 완료된 발주와 제조사 견적 정보를 연결합니다.',
    child: const Column(
      children: [
        HqNotice(
          warning: true,
          icon: Icons.link_off,
          title: '견적·품의 상품 연결이 필요합니다.',
          message:
              '현재 견적 데이터에 productId와 manufacturerId가 없어 상품코드 옵션 단위로 안전하게 발주를 생성하거나 중복 방지할 수 없습니다. 관계가 보완되기 전까지 발주 생성 버튼은 제공하지 않습니다.',
        ),
        SizedBox(height: 16),
        HqPanel(
          child: HqEmpty(
            title: '표시할 발주가 없습니다.',
            message: '실제 제조사 발주 데이터가 연결되면 이 화면에 나타납니다.',
            icon: Icons.request_quote_outlined,
          ),
        ),
      ],
    ),
  );
}
