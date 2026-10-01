import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/hq/hq_shell_page.dart';

class FitpickApp extends StatefulWidget {
  const FitpickApp({super.key});
  @override
  State<FitpickApp> createState() => _FitpickAppState();
}

class _FitpickAppState extends State<FitpickApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'FITPICK 관리자',
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: HqShellPage(
      dark: dark,
      onThemeChanged: () => setState(() => dark = !dark),
    ),
  );
}
