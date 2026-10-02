import 'package:flutter/material.dart';
import '../hq/hq_shell_page.dart';
import '../store/store_shell_page.dart';
import 'hq_login_dialog.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({
    super.key,
    required this.dark,
    required this.onThemeChanged,
  });

  final bool dark;
  final VoidCallback onThemeChanged;

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xff064d47);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: const Color(0xfff5f9f8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Column(
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 44),
                  const Text(
                    '관리자 시스템에 오신 것을 환영합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '로그인할 관리자 역할을 선택해 주세요.',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  isWide
                      ? Row(
                          children: [
                            Expanded(child: _roleCard(context, true)),
                            const SizedBox(width: 22),
                            Expanded(child: _roleCard(context, false)),
                          ],
                        )
                      : Column(
                          children: [
                            _roleCard(context, true),
                            const SizedBox(height: 18),
                            _roleCard(context, false),
                          ],
                        ),
                  const SizedBox(height: 36),
                  const Text(
                    'SHOEFIT  ·  STEP TO A BETTER DAY',
                    style: TextStyle(
                      color: brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleCard(BuildContext context, bool isHq) {
    const brand = Color(0xff064d47);
    final title = isHq ? '본사 관리자' : '대리점 관리자';
    final subtitle = isHq ? 'Head Office' : 'Franchise';
    final description = isHq ? '전국 매장과 상품을 통합 관리합니다.' : '우리 매장의 주문과 재고를 관리합니다.';
    final icon = isHq
        ? Icons.corporate_fare_outlined
        : Icons.storefront_outlined;

    return Semantics(
      button: true,
      label: '$title 화면으로 이동',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            if (isHq) {
              final accepted = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const HqLoginDialog(),
              );
              if (accepted != true || !context.mounted) return;
            }
            final page = isHq
                ? HqShellPage(dark: dark, onThemeChanged: onThemeChanged)
                : const StoreShellPage();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
          },
          child: Container(
            height: 310,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: brand.withValues(alpha: .14)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12063531),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: brand, size: 30),
                ),
                const Spacer(),
                Text(
                  subtitle.toUpperCase(),
                  style: const TextStyle(
                    color: brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  description,
                  style: TextStyle(color: Colors.blueGrey.shade600),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Text(
                      '관리 화면으로 이동',
                      style: TextStyle(
                        color: brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward, color: brand),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Text(
        'SHOEFIT',
        style: TextStyle(
          color: Color(0xff063f3b),
          fontSize: 38,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      SizedBox(height: 4),
      Text(
        'STEP TO A BETTER DAY',
        style: TextStyle(
          color: Color(0xff52716f),
          fontSize: 10,
          letterSpacing: 2.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
