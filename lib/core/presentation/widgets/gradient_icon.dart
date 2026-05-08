import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final LinearGradient? gradient;

  const GradientIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => (gradient ?? AppColors.primaryGradient).createShader(bounds),
      child: Icon(
        icon,
        size: size,
        color: Colors.white,
      ),
    );
  }
}
