import 'package:flutter/material.dart';

class ViewAllIconButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ViewAllIconButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFFED3973),
            Color(0xFFEFA240),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: const Icon(
            Icons.arrow_forward,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }
}
