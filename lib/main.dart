import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'core/scroll/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/root_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const SabuFlixApp());
}

class SabuFlixApp extends StatelessWidget {
  const SabuFlixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SabuFlix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      scrollBehavior: AppScrollBehavior(),
      home: const RootShell(),
    );
  }
}
