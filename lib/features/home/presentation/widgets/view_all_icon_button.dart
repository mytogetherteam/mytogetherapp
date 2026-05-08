import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      ),
    );
  }
}
