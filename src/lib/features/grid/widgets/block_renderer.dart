import 'package:flutter/material.dart';
import '../models/time_block_style.dart';

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
    // All styles render as tintBar until issue #43 fills them in
    return _buildTintBar(context);
  }

  Widget _buildTintBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? color.withValues(alpha: 0.9)
        : HSLColor.fromColor(color)
            .withLightness(
              (HSLColor.fromColor(color).lightness * 0.6).clamp(0.0, 1.0),
            )
            .toColor();
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      padding: const EdgeInsets.only(left: 6, top: 2),
      child: height >= 20
          ? Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : const SizedBox.shrink(),
    );
  }
}
