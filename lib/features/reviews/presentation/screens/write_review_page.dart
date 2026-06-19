import 'package:dio/dio.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/network/dio_error_message.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../data/repositories/order_review_repository.dart';
import '../../data/repositories/shop_review_repository.dart';
import '../../data/review_demo_data.dart';
import '../widgets/review_success_bottom_sheet.dart';

///   • Order review  — `POST /api/user/order-reviews` when [orderId] is set.
///   • Shop review   — `POST /api/user/reviews` when [shopId] is set alone,
///     or mirrored after a successful order review when [shopId] is also set.
class WriteReviewPage extends StatefulWidget {
  final int? orderId;
  final int? shopId;
  final String? shopName;
  final int initialRating;

  const WriteReviewPage({
    super.key,
    this.orderId,
    this.shopId,
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
    final shopId = widget.shopId;

    if (orderId != null) {
      await _submitOrderReview(orderId);
    } else if (shopId != null) {
      await _submitShopReview(shopId);
    } else {
      final result = await ReviewSuccessBottomSheet.show(context);
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _submitOrderReview(int orderId) async {
    setState(() => _submitting = true);

    final result = await OrderReviewRepository.instance.create(
      orderId: orderId,
      rating: _rating.toDouble(),
      comment: _composeComment(),
    );

    if (!mounted) return;

    if (result.success) {
      final shopId = widget.shopId;
      if (shopId != null) {
        try {
          await ShopReviewRepository.instance.createOrUpdate(
            shopId: shopId,
            rating: _rating.toDouble(),
            comment: _composeComment(),
          );
        } catch (_) {
          // Order review saved; shop mirror is best-effort for MyShop.
        }
      }

      setState(() => _submitting = false);

      final ok = await ReviewSuccessBottomSheet.show(context);
      if (ok == true && mounted) {
        Navigator.pop(context, true);
      }
      return;
    }

    setState(() => _submitting = false);

    AppDialog.showToast(
      context,
      result.errorMessage ?? context.tr('review.submit_failed'),
      isError: true,
    );
  }

  Future<void> _submitShopReview(int shopId) async {
    setState(() => _submitting = true);

    try {
      await ShopReviewRepository.instance.createOrUpdate(
        shopId: shopId,
        rating: _rating.toDouble(),
        comment: _composeComment(),
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      final ok = await ReviewSuccessBottomSheet.show(context);
      if (ok == true && mounted) {
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppDialog.showToast(
        context,
        dioErrorMessage(e, fallback: context.tr('review.submit_failed')),
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppDialog.showToast(
        context,
        context.tr('review.error_generic'),
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Widget _buildPermanentNotice() {
    const Color amber700 = Color(0xFFB45309);
    const Color amber50 = Color(0xFFFFFBEB);
    const Color amber200 = Color(0xFFFDE68A);

    final isPermanent = widget.orderId != null;
    final title = isPermanent
        ? context.tr('review.permanent_title')
        : context.tr('review.public_title');
    final body = isPermanent
        ? context.tr('review.permanent_body')
        : context.tr('review.public_body');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: amber50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: amber700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: amber700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    height: 1.45,
                    color: amber700.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          context.tr('review.write_title'),
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
                _buildPermanentNotice(),
                const SizedBox(height: 20),
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
                  context.tr('review.experience_prompt'),
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
                      hintText: context.tr('review.share_hint'),
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
                          context.tr('review.submit'),
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
