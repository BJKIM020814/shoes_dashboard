import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 네이버 지도(매장 위치 마커). 네이버 지도 SDK 는 iOS/Android 만 지원하므로
/// 그 외 플랫폼이거나 Client ID 가 없으면 안내 문구를 보여 준다.
class StoreMap extends StatefulWidget {
  const StoreMap({super.key, required this.clientId, required this.lat, required this.lng, required this.name});
  final String? clientId;
  final double lat, lng;
  final String name;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  @override
  State<StoreMap> createState() => _StoreMapState();
}

class _StoreMapState extends State<StoreMap> {
  static bool _initialized = false;
  late final Future<void> _init = _initSdk();
  String? _authError;

  Future<void> _initSdk() async {
    if (_initialized) return;
    await FlutterNaverMap().init(
      clientId: widget.clientId!,
      onAuthFailed: (e) {
        if (mounted) setState(() => _authError = '네이버 지도 인증에 실패했습니다. Client ID와 앱 등록 정보를 확인해 주세요.');
      },
    );
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!StoreMap.supported) return _notice('네이버 지도는 iOS/Android 기기에서 표시됩니다.');
    if (widget.clientId == null || widget.clientId!.isEmpty) {
      return _notice('서버에 NAVER_MAP_CLIENT_ID 가 설정되지 않았습니다.');
    }
    if (_authError != null) return _notice(_authError!);
    final position = NLatLng(widget.lat, widget.lng);
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.hasError) return _notice('네이버 지도를 불러오지 못했습니다.');
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 300,
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(target: position, zoom: 16),
                locationButtonEnable: false,
              ),
              onMapReady: (controller) => controller.addOverlay(
                NMarker(id: 'store', position: position, caption: NOverlayCaption(text: widget.name)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _notice(String text) => Container(
    height: 120,
    width: double.infinity,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: const Color(0xfff1f5f4), borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: const TextStyle(color: Colors.blueGrey)),
  );
}
