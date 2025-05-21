import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'pages/home_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const ProviderScope(child: TamashiiApp()));
}

class TamashiiApp extends StatelessWidget {
  const TamashiiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Tamashii', theme: ThemeData(), home: const HomePage());
  }
}
