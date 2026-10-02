import 'package:flutter/material.dart';
import '../../../core/api/store_api.dart';
import '../widgets/store_ui.dart';
import 'store_map.dart';

/// 매장 정보: GET /info (매장 정보 + 사진/영업시간 + 네이버 지도 설정 + 공지)
class StoreInformationPage extends StatelessWidget {
  const StoreInformationPage({super.key});

  @override
  Widget build(BuildContext context) => AsyncBody<Map<String, dynamic>>(
    load: () => StoreApi.instance.map('/info'),
    builder: (context, d, reload) {
      final store = Map<String, dynamic>.from(d['store']);
      final profile = Map<String, dynamic>.from(d['profile'] ?? {});
      final map = Map<String, dynamic>.from(d['map']);
      final hours = profile['open_time'] != null && profile['close_time'] != null
          ? '${profile['open_time']} – ${profile['close_time']}'
          : '등록되지 않음';
      final photo = profile['photo_url'] as String?;
      final lat = (map['lat'] as num?)?.toDouble();
      final lng = (map['lng'] as num?)?.toDouble();
      return SingleChildScrollView(
        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreHeader('매장 정보', '${store['name']} 운영 정보'),
            StoreCard(
              title: '${store['name']}',
              child: Wrap(
                spacing: 20,
                runSpacing: 16,
                children: [
                  Container(
                    width: 180,
                    height: 120,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xffd8ece8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: photo != null && photo.isNotEmpty
                        ? Image.network(photo, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.storefront_outlined, size: 40, color: storeGreen))
                        : const Icon(Icons.storefront_outlined, size: 40, color: storeGreen),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _line(Icons.place_outlined, '${store['address'] ?? '-'}'),
                      _line(Icons.schedule, '영업 시간 $hours'),
                      _line(Icons.person_outline, '담당자 ${store['manager'] ?? '-'}'),
                      _line(Icons.phone_outlined, '${store['dealer_number'] ?? '-'}'),
                    ],
                  ),
                ],
              ),
            ),
            StoreCard(
              title: '매장 지도',
              child: lat == null || lng == null
                  ? const Text('매장 좌표가 등록되지 않았습니다.')
                  : StoreMap(clientId: map['client_id'] as String?, lat: lat, lng: lng, name: '${store['name']}'),
            ),
          ],
        ),
      );
    },
  );

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18, color: storeGreen), const SizedBox(width: 8), Text(text)],
    ),
  );
}
