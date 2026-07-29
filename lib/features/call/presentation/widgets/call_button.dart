import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../screens/call_screen.dart';
import '../../data/call_session.dart';

/// A reusable "Call Shop" button to place on any page.
/// Shows a brief status feedback while the call connects.
class CallButton extends StatefulWidget {
  final int shopId;
  final String shopName;
  final String? shopImageUrl;
  final bool compact;

  const CallButton({
    super.key,
    required this.shopId,
    required this.shopName,
    this.shopImageUrl,
    this.compact = false,
  });

  @override
  State<CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<CallButton> {
  bool _loading = false;

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);

    final ok = await CallSession().initiateCall(
      shopId: widget.shopId,
      shopName: widget.shopName,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start call. Please try again.',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          shopName: widget.shopName,
          shopImageUrl: widget.shopImageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _loading
          ? const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              onPressed: _onTap,
              icon: Icon(PhosphorIcons.phone, color: AppColors.primary),
              tooltip: 'Call ${widget.shopName}',
            );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _onTap,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(PhosphorIcons.phone, color: AppColors.primary, size: 18),
        label: Text(
          _loading ? 'Calling...' : 'Call Shop',
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
