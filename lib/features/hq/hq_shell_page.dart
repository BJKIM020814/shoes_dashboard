import 'package:flutter/material.dart';
import '../../../view/home.dart';

class HqShellPage extends StatelessWidget {
  const HqShellPage({
    super.key,
    required this.dark,
    required this.onThemeChanged,
  });
  final bool dark;
  final VoidCallback onThemeChanged;
  @override
  Widget build(BuildContext context) =>
      FitpickHome(dark: dark, onThemeChanged: onThemeChanged);
}
