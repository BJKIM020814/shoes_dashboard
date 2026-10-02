import 'package:flutter/material.dart';
import '../../../core/api/store_api.dart';

/// 가맹점 화면 공통 UI. 기존 StoreShellPage 와 같은 색/카드 모양을 쓴다.
const storeGreen = Color(0xff064d47);
const storeBorder = Color(0xffe4ebea);

class StoreHeader extends StatelessWidget {
  const StoreHeader(this.title, this.sub, {super.key});
  final String title, sub;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(sub, style: TextStyle(color: Colors.blueGrey.shade600)),
      ],
    ),
  );
}

class StoreCard extends StatelessWidget {
  const StoreCard({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: storeBorder),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class StoreMetric extends StatelessWidget {
  const StoreMetric(this.label, this.value, this.icon, {super.key, this.hint, this.warn = false});
  final String label, value;
  final String? hint;
  final IconData icon;
  final bool warn;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 188,
    child: Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: storeBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: storeGreen),
          const SizedBox(height: 14),
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          if (hint != null) ...[
            const SizedBox(height: 5),
            Text(
              hint!,
              style: TextStyle(
                color: warn ? const Color(0xffc0392b) : const Color(0xff168e5d),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class StoreChip extends StatelessWidget {
  const StoreChip(this.label, {super.key, this.tone = StoreTone.info});
  final String label;
  final StoreTone tone;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StoreTone.good => (const Color(0xffe3f4ea), const Color(0xff168e5d)),
      StoreTone.warn => (const Color(0xffffeed8), const Color(0xffb36b00)),
      StoreTone.bad => (const Color(0xffffe3e0), const Color(0xffc0392b)),
      StoreTone.info => (const Color(0xffe6eef8), const Color(0xff31598c)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

enum StoreTone { good, warn, bad, info }

/// API 결과를 불러오는 동안 로딩/오류(다시 시도)/완료를 처리한다.
class AsyncBody<T> extends StatefulWidget {
  const AsyncBody({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  @override
  State<AsyncBody<T>> createState() => _AsyncBodyState<T>();
}

class _AsyncBodyState<T> extends State<AsyncBody<T>> {
  late Future<T> _future = widget.load();

  Future<void> _reload() async {
    final next = widget.load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snap.hasError) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Text('${snap.error}', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _reload, child: const Text('다시 시도')),
              ],
            ),
          ),
        );
      }
      return widget.builder(context, snap.data as T, _reload);
    },
  );
}

/// 처리자(직원 ID)가 아직 없으면 한 번 물어본다. 취소하면 null.
Future<String?> ensureStaffId(BuildContext context) async {
  final api = StoreApi.instance;
  if (api.staffId.isNotEmpty) return api.staffId;
  final controller = TextEditingController();
  final id = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('처리자 직원 ID'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 45,
        decoration: const InputDecoration(hintText: '직원 ID를 입력하세요'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  if (id == null || id.isEmpty) return null;
  api.staffId = id;
  return id;
}

void showStoreMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String won(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '₩$buf';
}

/// ISO 문자열/Null 을 'yyyy.MM.dd HH:mm' 로.
String shortDate(dynamic v, {bool time = true}) {
  final d = v == null ? null : DateTime.tryParse('$v');
  if (d == null) return '-';
  final l = d.toLocal();
  String t(int n) => n.toString().padLeft(2, '0');
  final day = '${l.year}.${t(l.month)}.${t(l.day)}';
  return time ? '$day ${t(l.hour)}:${t(l.minute)}' : day;
}
