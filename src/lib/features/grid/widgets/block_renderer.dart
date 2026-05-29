import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/models/time_block_style.dart';
import '../../../core/theme/app_theme.dart';

class BlockRenderer extends StatelessWidget {
  final TimeBlockStyle style;
  final Color color;
  final String label;
  final double height;

  const BlockRenderer({
    super.key,
    required this.style,
    required this.color,
    required this.label,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case TimeBlockStyle.tintBar:
        return _buildTintBar(context);
      case TimeBlockStyle.card:
        return _buildCard();
      case TimeBlockStyle.roundedTint:
        return _buildRoundedTint(context);
      case TimeBlockStyle.liquidGlass:
        return _buildLiquidGlass(context);
    }
  }

  Widget _buildTintBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = _darkened(color, isDark);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      padding: const EdgeInsets.only(left: 6, top: 2),
      child: _label(label, textColor),
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.only(left: 6, top: 2),
      child: _label(label, Colors.white),
    );
  }

  Widget _buildRoundedTint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = _darkened(color, isDark);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.only(left: 6, top: 2),
      child: _label(label, textColor),
    );
  }

  Widget _buildLiquidGlass(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? Colors.white.withValues(alpha: 0.9) : _darkened(color, false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.compose(
          outer: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          inner: AppTheme.glassColorMatrix,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.only(left: 6, top: 2),
          child: _label(label, textColor),
        ),
      ),
    );
  }

  Widget _label(String text, Color textColor) {
    if (height < 20) return const SizedBox.shrink();
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Color _darkened(Color base, bool isDark) {
    if (isDark) return base.withValues(alpha: 0.9);
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();
  }
}
