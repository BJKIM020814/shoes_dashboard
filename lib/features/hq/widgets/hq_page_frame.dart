import 'package:flutter/material.dart';
import '../data/hq_api.dart';

const hqGreen = Color(0xff064d47);
const hqCanvas = Color(0xfff5f8f7);

class HqPageFrame extends StatelessWidget {
  const HqPageFrame({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.action,
    this.eyebrow = 'HEADQUARTERS · OPERATIONS CENTER',
  });
  final String title, description, eyebrow;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: hqCanvas,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.all(constraints.maxWidth < 600 ? 18 : 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: hqGreen.withValues(alpha: .72),
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            description,
                            style: TextStyle(color: Colors.blueGrey.shade600),
                          ),
                        ],
                      ),
                    ),
                    ?action,
                  ],
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class HqPanel extends StatelessWidget {
  const HqPanel({super.key, required this.child, this.title, this.trailing});
  final Widget child;
  final String? title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xffe2eae8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
        ],
        child,
      ],
    ),
  );
}

class HqNotice extends StatelessWidget {
  const HqNotice({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.warning = false,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final bool warning;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xffa56313) : hqGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HqEmpty extends StatelessWidget {
  const HqEmpty({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.blueGrey.shade300),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey.shade600),
          ),
        ],
      ),
    ),
  );
}

class HqLoadState extends StatelessWidget {
  const HqLoadState({
    super.key,
    required this.future,
    required this.builder,
    this.emptyTitle = '표시할 데이터가 없습니다.',
    this.emptyMessage = '연결된 실제 데이터가 없습니다.',
  });
  final Future<Map<String, dynamic>> future;
  final Widget Function(Map<String, dynamic>) builder;
  final String emptyTitle, emptyMessage;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(44),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        final error = snapshot.error;
        final status = error is HqApiException ? error.statusCode : null;
        final isForbidden = status == 401 || status == 403;
        return HqNotice(
          warning: true,
          icon: isForbidden ? Icons.lock_outline : Icons.cloud_off_outlined,
          title: isForbidden ? '본사 계정 연결 필요' : '데이터를 불러오지 못했습니다.',
          message: error.toString(),
        );
      }
      final data = snapshot.data ?? const {};
      final items = data['items'];
      if (items is List && items.isEmpty) {
        return HqEmpty(title: emptyTitle, message: emptyMessage);
      }
      return builder(data);
    },
  );
}

class HqMetricCard extends StatelessWidget {
  const HqMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
  });
  final String label, value;
  final IconData icon;
  final String? caption;
  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xffe2eae8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: hqGreen),
        const SizedBox(height: 14),
        Text(
          label,
          style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 11),
          ),
        ],
      ],
    ),
  );
}
