import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../theme/athlos_spacing.dart';
import '../../theme/athlos_text_theme.dart';

/// Displayed while the app resolves initial async state (e.g. hasProfile).
///
/// No navigation logic here — GoRouter redirect handles routing
/// once the profile check resolves.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Athlos',
              style: AthlosTextTheme.brandDisplay(colorScheme.primary),
            ),
            const SizedBox(height: AthlosSpacing.xl),
            SizedBox(
              width: AthlosSpacing.lg,
              height: AthlosSpacing.lg,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
