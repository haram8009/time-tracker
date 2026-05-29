import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/time_block_style.dart';
import '../../../core/services/appearance_service.dart';
import '../../../core/theme/app_theme.dart';

class GlassAmbientBackground extends ConsumerWidget {
  const GlassAmbientBackground({
    super.key,
    required this.brightness,
    required this.child,
  });

  final Brightness brightness;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockStyle = ref.watch(appearanceServiceProvider);
    if (blockStyle != TimeBlockStyle.liquidGlass) return child;

    final gradient = brightness == Brightness.dark
        ? AppTheme.ambientGradientDark
        : AppTheme.ambientGradientLight;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(gradient: gradient),
        ),
        child,
      ],
    );
  }
}
