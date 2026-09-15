import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/referral_service.dart';

class EditPromoteCodeDialog extends StatefulWidget {
  final String? initialCode;

  const EditPromoteCodeDialog({
    super.key,
    this.initialCode,
  });

  static Future<String?> show(BuildContext context, {String? initialCode}) {
    return showDialog<String?>(
      context: context,
      builder: (context) => EditPromoteCodeDialog(initialCode: initialCode),
    );
  }

  @override
  State<EditPromoteCodeDialog> createState() => _EditPromoteCodeDialogState();
}

class _EditPromoteCodeDialogState extends State<EditPromoteCodeDialog> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  bool _isChecking = false;
  String? _errorMessage;
  String? _successMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim().toUpperCase();

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (trimmed.isEmpty) {
      setState(() => _isChecking = false);
      return;
    }

    if (trimmed.length < 3) {
      setState(() {
        _errorMessage = 'Code must be at least 3 characters';
        _isChecking = false;
      });
      return;
    }

    if (!RegExp(r'^[A-Z0-9_-]+$').hasMatch(trimmed)) {
      setState(() {
        _errorMessage = 'Only letters, numbers, hyphens & underscores allowed';
        _isChecking = false;
      });
      return;
    }

    // If same as initial code, skip server check
    if (widget.initialCode != null &&
        trimmed == widget.initialCode!.toUpperCase()) {
      setState(() {
        _successMessage = 'Current code';
        _isChecking = false;
      });
      return;
    }

    setState(() => _isChecking = true);
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final result = await ReferralService.instance.checkAvailability(trimmed);
        if (!mounted) return;
        setState(() {
          _isChecking = false;
          if (result.isAvailable) {
            _successMessage = 'Code is available!';
            _errorMessage = null;
          } else {
            _errorMessage = result.reason ?? 'Code is already taken';
            _successMessage = null;
          }
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _isChecking = false);
      }
    });
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length < 3 || code.length > 20) {
      setState(() => _errorMessage = 'Code must be 3-20 characters long');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final saved = await ReferralService.instance.setMyCode(code);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(saved.code);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialCode != null && widget.initialCode!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIcons.sparkleFill,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEditing ? 'Edit Promote Code' : 'Create Promote Code',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              isEditing
                  ? 'Update your personal code. Friends who use this code will be linked to your account.'
                  : 'Choose a memorable code (e.g. ALEX88, CHINESENEWYEAR) to share with friends and earn rewards.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            // Text Input
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              maxLength: 20,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                UpperCaseTextFormatter(),
              ],
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                hintText: 'e.g. ALEX88',
                counterText: '',
                prefixIcon: const Icon(
                  PhosphorIcons.tag,
                  size: 20,
                  color: Colors.grey,
                ),
                suffixIcon: _isChecking
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(PhosphorIcons.warningCircleFill,
                      color: Colors.red, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ] else if (_successMessage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(PhosphorIcons.checkCircleFill,
                      color: Colors.green, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (_isLoading || _isChecking || _errorMessage != null)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Code',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
