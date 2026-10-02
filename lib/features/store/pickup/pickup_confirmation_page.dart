import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/api/store_api.dart';
import '../widgets/store_ui.dart';

/// 수령 확인: 카메라 QR 스캔(mobile_scanner) 또는 6자리 난수 입력 -> verify -> confirm
class PickupConfirmationPage extends StatefulWidget {
  const PickupConfirmationPage({super.key});
  @override
  State<PickupConfirmationPage> createState() => _PickupConfirmationPageState();
}

class _PickupConfirmationPageState extends State<PickupConfirmationPage> {
  final _api = StoreApi.instance;
  final _code = TextEditingController();
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    autoStart: false,
  );
  bool _useCamera = true;
  bool _busy = false;
  Map<String, dynamic>? _verified; // verify 응답
  String? _qr, _codeValue; // 확정 때 다시 보낼 인증 값
  Map<String, dynamic>? _done; // confirm 응답
  String? _error;

  // 카메라 스캔은 iOS/Android/웹에서만 지원한다.
  bool get _cameraSupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _useCamera = _cameraSupported;
    if (_useCamera) _scanner.start().catchError((_) {});
  }

  @override
  void dispose() {
    _scanner.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify({String? qr, String? code}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _api.verifyPickup(qr: qr, code: code);
      if (!mounted) return;
      setState(() {
        _verified = res;
        _qr = qr;
        _codeValue = code;
      });
      _scanner.stop();
    } on StoreApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final staff = await ensureStaffId(context);
    if (staff == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await _api.confirmPickup(qr: _qr, code: _codeValue, staffId: staff);
      if (mounted) setState(() => _done = res);
    } on StoreApiException catch (e) {
      if (mounted) showStoreMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _verified = null;
      _qr = _codeValue = null;
      _done = null;
      _error = null;
      _code.clear();
    });
    if (_useCamera) _scanner.start().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StoreHeader('수령 확인', '고객 QR 또는 난수 인증 후 수령을 처리하세요. 완료 시 본사 주문 관리에 즉시 반영됩니다.'),
        StoreCard(
          title: '수령 확인',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _steps(),
              const SizedBox(height: 16),
              if (_verified == null) ...[_methodTabs(), const SizedBox(height: 14), _useCamera ? _camera() : _codeInput()],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Color(0xffc0392b))),
                ),
              if (_verified != null) _order(_verified!),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _steps() {
    final step = _done != null ? 3 : (_verified != null ? 2 : 1);
    Widget dot(int n, String label) => Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: step >= n ? storeGreen : const Color(0xffd5dedc),
          child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(1, '요청'),
        const SizedBox(width: 40, child: Divider()),
        dot(2, 'QR 인증'),
        const SizedBox(width: 40, child: Divider()),
        dot(3, '완료'),
      ],
    );
  }

  Widget _methodTabs() => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(value: true, label: Text('카메라 QR 스캔'), icon: Icon(Icons.qr_code_scanner)),
      ButtonSegment(value: false, label: Text('난수 입력'), icon: Icon(Icons.pin_outlined)),
    ],
    selected: {_useCamera},
    onSelectionChanged: (v) {
      final camera = v.first;
      if (camera && !_cameraSupported) {
        showStoreMessage(context, '이 기기에서는 카메라 스캔을 지원하지 않습니다. 난수를 입력해 주세요.');
        return;
      }
      setState(() => _useCamera = camera);
      camera ? _scanner.start().catchError((_) {}) : _scanner.stop();
    },
  );

  Widget _camera() => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 320,
          width: double.infinity,
          child: MobileScanner(
            controller: _scanner,
            onDetect: (capture) {
              final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
              if (raw != null) _verify(qr: raw);
            },
            errorBuilder: (context, error) => Center(
              child: Text(
                error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? '카메라 권한을 허용해 주세요.'
                    : '카메라를 시작할 수 없습니다. 난수 입력을 이용해 주세요.',
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text('고객 앱의 수령 QR 코드를 화면 중앙에 맞춰주세요.', style: TextStyle(color: Colors.blueGrey)),
    ],
  );

  Widget _codeInput() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('카메라 인식이 안 되나요?', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('고객에게 전달받은 6자리 난수를 입력하세요.', style: TextStyle(color: Colors.blueGrey)),
      const SizedBox(height: 10),
      SizedBox(
        width: 260,
        child: TextField(
          controller: _code,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '예: 392184', border: OutlineInputBorder()),
        ),
      ),
      FilledButton(
        onPressed: _code.text.length == 6 && !_busy ? () => _verify(code: _code.text) : null,
        child: const Text('난수 확인'),
      ),
    ],
  );

  Widget _order(Map<String, dynamic> v) {
    final p = Map<String, dynamic>.from(v['purchase']);
    final already = v['already_picked_up'] == true;
    final label = _done != null ? '처리 완료' : (already ? '이미 수령됨' : '인증 완료');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_done == null && !already)
          Text('${p['customer_name']} 고객 인증이 완료되었습니다. 주문 정보를 확인하세요.',
              style: const TextStyle(color: Color(0xff168e5d), fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: storeBorder), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 32, color: storeGreen),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${p['p_name'] ?? p['p_code']}\n'
                  '상품코드 ${p['p_code']}  ·  사이즈 ${p['p_size'] ?? '-'}  ·  ${p['p_color'] ?? '-'}\n'
                  '고객 ${p['customer_name']} (${p['customer_id']})',
                  style: const TextStyle(height: 1.5),
                ),
              ),
              StoreChip(label, tone: _done != null ? StoreTone.good : (already ? StoreTone.warn : StoreTone.info)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            FilledButton(
              onPressed: _done != null || already || _busy ? null : _confirm,
              child: const Text('수령 처리 완료'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: _reset, child: Text(_done != null ? '다음 고객' : '다시 스캔')),
          ],
        ),
        if (_done != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'QR 인증 수령 완료 · 수령번호 ${_done!['pickup_id']}'
              '${_done!['stock_updated'] == true ? '' : '\n(재고 수량 자동 반영은 실패했습니다. 재고 관리에서 확인해 주세요.)'}',
              style: const TextStyle(color: Color(0xff168e5d)),
            ),
          ),
      ],
    );
  }
}
