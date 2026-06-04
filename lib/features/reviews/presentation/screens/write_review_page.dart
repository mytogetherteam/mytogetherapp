import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../data/repositories/order_review_repository.dart';
import '../../data/review_demo_data.dart';
import '../widgets/review_success_bottom_sheet.dart';

/// Lets a user rate a delivered order via the new backend endpoint
/// `POST /api/user/order-reviews`. The local tags are kept as a UI
/// affordance — tags are prepended to the `comment` field so they aren't
/// lost server-side. Image upload is intentionally omitted for now.
class WriteReviewPage extends StatefulWidget {
  final int? orderId;
  final String? shopName;
  final int initialRating;

  const WriteReviewPage({
    super.key,
    this.orderId,
    this.shopName,
    this.initialRating = 0,
  });

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage> {
  late int _rating;
  final Set<String> _selectedTags = {};

  final TextEditingController _reviewController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(0, 5);
  }

  /// Builds the comment payload by prefixing selected tags so they aren't
  /// lost: e.g. "[Taste, Customer Service] Great food, fast delivery."
  String? _composeComment() {
    final body = _reviewController.text.trim();
    final tagsLine =
        _selectedTags.isNotEmpty ? '[${_selectedTags.join(', ')}]' : '';

    if (tagsLine.isEmpty && body.isEmpty) return null;
    if (tagsLine.isEmpty) return body;
    if (body.isEmpty) return tagsLine;
    return '$tagsLine $body';
  }

  Future<void> _submitReview() async {
    if (_submitting) return;
    if (_rating <= 0) return;

    final orderId = widget.orderId;
    if (orderId == null) {
      // Demo mode (no order context) — keep the legacy success flow.
      final result = await ReviewSuccessBottomSheet.show(context);
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
      return;
    }

    setState(() => _submitting = true);

    final result = await OrderReviewRepository.instance.create(
      orderId: orderId,
      rating: _rating.toDouble(),
      comment: _composeComment(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      final ok = await ReviewSuccessBottomSheet.show(context);
      if (ok == true && mounted) {
        Navigator.pop(context, true);
      }
      return;
    }

    AppDialog.showToast(
      context,
      result.errorMessage ?? 'Could not submit review.',
      isError: true,
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Write a Review',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.shopName != null && widget.shopName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: Text(
                        widget.shopName!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _rating = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          _rating > index
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: _rating > index
                              ? const Color(0xFFFFC107)
                              : Colors.grey[300],
                          size: 48,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 32),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ReviewDemoData.writeReviewTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppColors.primaryGradient : null,
                          color: isSelected ? null : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight:
                                isSelected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                Text(
                  'How was your experience? Tell us what you liked and what could be improved.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _reviewController,
                    maxLines: 5,
                    maxLength: 500,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share your experience',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                child: PrimaryGradientButton(
                  onPressed: (_rating > 0 && !_submitting) ? _submitReview : null,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Submit Review',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
