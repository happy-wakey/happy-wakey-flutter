import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_controller.dart';
import 'core/app_state.dart';
import 'ui/app_shell.dart';
import 'ui/onboarding_screen.dart';
import 'ui/theme.dart';

class HappyWakeyApp extends StatelessWidget {
  const HappyWakeyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Happy Wakey',
    debugShowCheckedModeBanner: false,
    theme: buildHappyWakeyTheme(Brightness.light),
    darkTheme: buildHappyWakeyTheme(Brightness.dark),
    themeMode: ThemeMode.system,
    home: Consumer<AppController>(
      builder: (context, controller, _) =>
          controller.machine.onboarding == OnboardingStep.complete
          ? const AppShell()
          : const OnboardingScreen(),
    ),
  );
}
