import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ViewAllIconButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ViewAllIconButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFED3973),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
              color: Colors.white,
              size: 12, // Reduced icon size slightly to match 24x24
            ),
          ),
        ),
      ),
    );
  }
}
