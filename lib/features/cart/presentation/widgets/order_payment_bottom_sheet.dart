import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/file_url_util.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/media/picked_image.dart';
import '../../../../core/media/image_crop_helper.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../reviews/presentation/widgets/image_upload_bottom_sheet.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../data/active_order_state.dart';
import 'omise_payment_section.dart';

/// Grab-style Payment Bottom Sheet Modal
/// Displays PromptPay QR / TrueMoney for orders >= ฿20
/// and automatically switches to Bank Slip upload for orders < ฿20 (Option 2)
/// or upon manual request.
class OrderPaymentBottomSheet extends StatefulWidget {
  final ActiveOrderItem order;
  final int orderId;
  final double foodTotal;
  final double deliveryFee;
  final VoidCallback onPaymentCompleted;

  const OrderPaymentBottomSheet({
    super.key,
    required this.order,
    required this.orderId,
    required this.foodTotal,
    required this.deliveryFee,
    required this.onPaymentCompleted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ActiveOrderItem order,
    required int orderId,
    required double foodTotal,
    required double deliveryFee,
    required VoidCallback onPaymentCompleted,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (ctx) => OrderPaymentBottomSheet(
        order: order,
        orderId: orderId,
        foodTotal: foodTotal,
        deliveryFee: deliveryFee,
        onPaymentCompleted: onPaymentCompleted,
      ),
    );
  }

  @override
  State<OrderPaymentBottomSheet> createState() =>
      _OrderPaymentBottomSheetState();
}

class _OrderPaymentBottomSheetState extends State<OrderPaymentBottomSheet> {
  bool _forceSlip = false;
  PickedImage? _receiptImage;
  bool _isUploadingSlip = false;
  bool _isLoadingBankDetails = false;
  bool _paymentSucceeded = false;
  StreamSubscription? _orderSub;

  final ImagePicker _imagePicker = ImagePicker();

  double get _payableTotal {
    final stateTotal = widget.order.totalAmount;
    if (stateTotal != null && stateTotal > 0) return stateTotal;
    final food = widget.order.itemPrice ?? widget.foodTotal;
    final fee = widget.order.deliveryFee ?? widget.deliveryFee;
    return food + fee;
  }

  bool get _isUnderMinimum => _payableTotal > 0 && _payableTotal < 20.0;

  @override
  void initState() {
    super.initState();
    // Option 2: Orders under ฿20 cannot use Omise, default to slip transfer
    if (_isUnderMinimum || widget.order.isSlipRequested) {
      _forceSlip = true;
    }
    _fetchBankDetailsIfNeeded();

    // Listen to WebSocket order updates while modal is open
    _orderSub = WebSocketService().orderUpdates.listen((update) {
      if (!mounted) return;
      final state = ActiveOrderState.instance;
      if (state.orderStatus >= 2 ||
          ActiveOrderState.isCookingTransitionStatus(state.backendStatus ?? '')) {
        _triggerSuccessCelebration();
      }
    });
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchBankDetailsIfNeeded() async {
    if (widget.order.paymentAccountNumber != null &&
        widget.order.paymentAccountNumber!.trim().isNotEmpty) {
      return;
    }

    if (mounted) setState(() => _isLoadingBankDetails = true);
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/orders/${widget.orderId}',
      );
      if (!mounted) return;
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final inner = (data is Map ? data['data'] : null) ?? data;
        Map<String, dynamic> paymentMethod = {};
        if (inner is Map && inner['paymentMethod'] is Map) {
          paymentMethod = Map<String, dynamic>.from(inner['paymentMethod'] as Map);
        } else if (inner is Map) {
          paymentMethod = Map<String, dynamic>.from(inner);
        }
        final accNumber = (paymentMethod['accountNumber'] ??
                paymentMethod['account'])
            ?.toString();
        final accName = (paymentMethod['accountName'] ??
                paymentMethod['name'] ??
                paymentMethod['accountHolderName'])
            ?.toString();
        final qrUrl = (paymentMethod['qr'] ??
                paymentMethod['qrImageUrl'] ??
                paymentMethod['iconUrl'] ??
                paymentMethod['image'])
            ?.toString();

        ActiveOrderState.instance.updatePaymentMethodDetails(
          accountNumber: accNumber,
          accountName: accName,
          imageUrl: qrUrl != null ? FileUrlUtil.resolve(qrUrl) : null,
          orderId: widget.order.orderId,
        );
      }
    } catch (_) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isLoadingBankDetails = false);
    }
  }

  void _triggerSuccessCelebration() {
    if (_paymentSucceeded || !mounted) return;
    setState(() => _paymentSucceeded = true);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      widget.onPaymentCompleted();
      Navigator.of(context).pop(true);
    });
  }

  Future<void> _pickReceiptImage() async {
    if (_isUploadingSlip) return;
    final action = await ImageUploadBottomSheet.show(
      context,
      showRemove: _receiptImage != null,
    );
    if (action == null || !mounted) return;

    if (action == ImageUploadAction.remove) {
      setState(() => _receiptImage = null);
      return;
    }

    final source = action == ImageUploadAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (picked == null || !mounted) return;

      final cropped = await ImageCropHelper.crop(picked);
      if (cropped == null || !mounted) return;

      final image = await PickedImage.fromXFile(cropped);
      if (!mounted) return;
      setState(() => _receiptImage = image);
    } catch (e) {
      if (!mounted) return;
      AppDialog.showToast(context, 'Failed to pick image: $e', isError: true);
    }
  }

  Future<void> _submitSlip() async {
    if (_receiptImage == null || _isUploadingSlip) return;
    setState(() => _isUploadingSlip = true);

    try {
      final formData = FormData.fromMap({
        'paymentImage': _receiptImage!.toMultipartFile(),
      });

      await ApiClient().dio.patch(
        '${ApiClient.apiPrefix}/user/orders/${widget.orderId}/payment',
        data: formData,
      );

      if (!mounted) return;
      AppDialog.showToast(
        context,
        _t(
          en: 'Slip uploaded! Shop is verifying.',
          mm: 'စလစ်တင်ပြီးပါပြီ။ ဆိုင်မှ စစ်ဆေးနေပါသည်',
          th: 'ส่งสลิปแล้ว! ร้านค้ากำลังตรวจสอบ',
        ),
      );
      final order = ActiveOrderState.instance.getOrder(widget.order.orderId);
      if (order != null) {
        order.isPaymentChecking = true;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      String errorMsg = _t(
        en: 'Failed to upload payment slip',
        mm: 'ငွေလွှဲစလစ် တင်ခြင်း မအောင်မြင်ပါ',
        th: 'ไม่สามารถอัปโหลดสลิปได้',
      );
      if (e is DioException) {
        errorMsg = e.response?.data?['message']?.toString() ?? errorMsg;
      }
      AppDialog.showToast(context, errorMsg, isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingSlip = false);
    }
  }

  String _t({required String en, required String mm, required String th}) {
    return LocaleController.instance.localized(en: en, mm: mm, th: th);
  }

  bool get _isVerifiedShop {
    return widget.order.isVerified ||
        ActiveOrderState.instance.isVerified ||
        (widget.order.paymentChannel?.toUpperCase() == 'OMISE');
  }

  @override
  Widget build(BuildContext context) {
    final double maxSheetHeight = MediaQuery.of(context).size.height * 0.90;

    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return Container(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grab drag handle
                _buildTopBar(),

                // Success celebration overlay or main content
                if (_paymentSucceeded)
                  _buildSuccessState()
                else
                  Flexible(
                    child: _forceSlip
                        ? _buildManualSlipView()
                        : OmisePaymentSection(
                            order: widget.order,
                            orderId: widget.orderId,
                            initialMethod:
                                widget.order.preferredOmiseMethod ?? 'PROMPTPAY',
                            onPaymentCompleted: _triggerSuccessCelebration,
                            onFallbackToSlip: _isVerifiedShop
                                ? null
                                : () {
                                    setState(() => _forceSlip = true);
                                  },
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Center(
        child: Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                PhosphorIconsFill.checkCircle,
                color: Color(0xFF10B981),
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _t(
              en: 'Payment Successful!',
              mm: 'ငွေပေးချေမှု အောင်မြင်ပါသည်!',
              th: 'ชำระเงินสำเร็จ!',
            ),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              en: 'Payment Confirmed • Shop is preparing your order',
              mm: 'ငွေပေးချေမှု အတည်ပြုပြီးပါပြီ • ဆိုင်မှ စတင်ချက်ပြုတ်နေပါပြီ',
              th: 'ยืนยันการชำระเงินแล้ว • ร้านค้ากำลังเตรียมอาหาร',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSlipView() {
    final order = widget.order;
    final accNumber = order.paymentAccountNumber;
    final accName = order.paymentAccountName;
    final qrUrl = order.shopPaymentQrUrl ?? order.paymentMethodImageUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Amount banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        en: 'TOTAL AMOUNT TO PAY',
                        mm: 'ပေးချေရမည့် စုစုပေါင်းငွေ',
                        th: 'ยอดรวมที่ต้องชำระ',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.primaryGradient.createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      ),
                      child: Text(
                        _payableTotal.toFormattedPrice(),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_isUnderMinimum)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _forceSlip = false),
                    icon: const Icon(PhosphorIconsBold.qrCode, size: 14),
                    label: Text(
                      _t(
                        en: 'Use PromptPay',
                        mm: 'PromptPay သုံးမည်',
                        th: 'ใช้ PromptPay',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Under ฿20 Warning notice
          if (_isUnderMinimum) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    PhosphorIconsFill.info,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t(
                        en: 'Order total (${_payableTotal.toFormattedPrice()}) is under ฿20. PromptPay cannot be processed directly. Please transfer to the bank account and upload the slip.\n(Omise requires minimum ฿20 for online payment)',
                        mm: 'ငွေပေးချေမှုပမာဏ (${_payableTotal.toFormattedPrice()}) သည် ฿20 အောက်ဖြစ်ပါသဖြင့် PromptPay တိုက်ရိုက်ပေးချေမှု မရနိုင်ပါ။ ဘဏ်အကောင့်သို့ လွှဲပြောင်းပြီး စလစ်တင်၍ ပေးချေပေးပါရန်။\n(အွန်လိုင်းငွေပေးချေမှုအတွက် အနည်းဆုံး ฿20 လိုအပ်ပါသည်)',
                        th: 'ยอดชำระ (${_payableTotal.toFormattedPrice()}) ต่ำกว่า ฿20 ไม่สามารถใช้ PromptPay ได้โดยตรง กรุณาโอนเงินเข้าบัญชีธนาคารและแนบสลิป\n(การชำระเงินออนไลน์ต้องมียอดขั้นต่ำ ฿20)',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: const Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Bank Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(PhosphorIconsBold.bank,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _t(
                        en: 'Shop Bank Account Details',
                        mm: 'ဆိုင်၏ ဘဏ်အကောင့် အချက်အလက်',
                        th: 'ข้อมูลบัญชีธนาคารของร้าน',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                if (_isLoadingBankDetails)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CustomLoadingIndicator(size: 24)),
                  )
                else ...[
                  if (accNumber != null && accNumber.trim().isNotEmpty) ...[
                    Text(
                      _t(
                        en: 'Account Number:',
                        mm: 'ဘဏ်အကောင့်နံပါတ်:',
                        th: 'เลขที่บัญชี:',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          accNumber,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: accNumber));
                            AppDialog.showToast(
                              context,
                              _t(
                                en: 'Account number copied!',
                                mm: 'အကောင့်နံပါတ် ကူးယူပြီးပါပြီ!',
                                th: 'คัดลอกเลขบัญชีแล้ว!',
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(PhosphorIconsRegular.copy, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  _t(
                                    en: 'Copy',
                                    mm: 'ကူးယူရန်',
                                    th: 'คัดลอก',
                                  ),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (accName != null && accName.trim().isNotEmpty) ...[
                    Text(
                      _t(
                        en: 'Account Name:',
                        mm: 'အကောင့်ပိုင်ရှင်အမည်:',
                        th: 'ชื่อบัญชี:',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accName,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],

                  if (qrUrl != null && qrUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        height: 140,
                        width: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: CachedNetworkImage(
                          imageUrl: qrUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) => const Icon(
                            PhosphorIconsFill.qrCode,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Upload Slip Section
          Text(
            _t(
              en: 'Upload Payment Slip',
              mm: 'ငွေလွှဲစလစ် တင်ရန်',
              th: 'แนบสลิปการโอนเงิน',
            ),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),

          GestureDetector(
            onTap: _pickReceiptImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _receiptImage != null
                      ? AppColors.primary
                      : const Color(0xFFCBD5E1),
                  style: BorderStyle.solid,
                  width: _receiptImage != null ? 1.5 : 1,
                ),
              ),
              child: _receiptImage != null
                  ? Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _receiptImage!.bytes,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(
                                  en: 'Receipt slip selected',
                                  mm: 'စလစ် ပုံရိပ် ရွေးချယ်ပြီးပါပြီ',
                                  th: 'เลือกรูปสลิปแล้ว',
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                _t(
                                  en: 'Tap to change photo',
                                  mm: 'ဓာတ်ပုံ ပြန်ပြောင်းရန် နှိပ်ပါ',
                                  th: 'แตะเพื่อเปลี่ยนรูป',
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(PhosphorIconsRegular.trash,
                              color: Colors.red),
                          onPressed: () =>
                              setState(() => _receiptImage = null),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const Icon(
                          PhosphorIconsBold.cameraPlus,
                          size: 32,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t(
                            en: 'Tap to select payment slip',
                            mm: 'စလစ်ဓာတ်ပုံ ရွေးချယ်ရန် နှိပ်ပါ',
                            th: 'แตะเพื่อเลือกรูปสลิป',
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          _t(
                            en: 'Choose from gallery or take a photo',
                            mm: 'ဖုန်းထဲမှ ပုံရွေးချယ်ပါ သို့မဟုတ် ဓာတ်ပုံရိုက်ပါ',
                            th: 'เลือกจากแกลเลอรีหรือถ่ายภาพ',
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          PrimaryGradientButton(
            height: 48,
            isLoading: _isUploadingSlip,
            onPressed: _receiptImage != null && !_isUploadingSlip
                ? _submitSlip
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsBold.uploadSimple,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  _t(
                    en: 'Submit Slip & Confirm',
                    mm: 'စလစ်တင်ပြီး အတည်ပြုမည်',
                    th: 'ส่งสลิปและยืนยัน',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
