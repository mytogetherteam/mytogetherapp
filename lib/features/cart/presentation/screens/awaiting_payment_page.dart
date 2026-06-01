import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/network/api_client.dart';
import '../../data/active_order_state.dart';
import '../../../../core/utils/navigation_controller.dart';
import 'order_status_page.dart';
import 'order_cancel_page.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/presentation/widgets/gradient_icon.dart';

class AwaitingPaymentPage extends StatefulWidget {
  static bool isCurrentlyVisible = false;
  final String? orderId;
  final double foodTotal;
  final double deliveryFee;

  const AwaitingPaymentPage({
    super.key,
    this.orderId,
    required this.foodTotal,
    required this.deliveryFee,
  });

  @override
  State<AwaitingPaymentPage> createState() => _AwaitingPaymentPageState();
}

class _AwaitingPaymentPageState extends State<AwaitingPaymentPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsAnimController;
  final GlobalKey _qrKey = GlobalKey();
  bool _showUploadSection = false;
  File? _receiptImage;
  bool _isUploading = false;
  bool _isCancelling = false;
  StreamSubscription? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _dotsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    // Prevent screenshots/screen recording on this sensitive payment page
    AwaitingPaymentPage.isCurrentlyVisible = true;
    if (Platform.isAndroid) {
      const MethodChannel('secure_screen').invokeMethod('enable');
    }

    // Always show Step 1 first, unconditionally
    _showUploadSection = false;

    // Ensure the global state is synced so it doesn't cause weird UI jumps
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ActiveOrderState.instance.setShowUploadSection(
        false,
        orderId: widget.orderId,
      );
    });

    // Fetch detailed payment method image if needed
    _fetchPaymentMethodDetails();

    // Listen to global state for real-time rebuilds (e.g., when QR URL arrives)
    ActiveOrderState.instance.addListener(_onStateUpdated);

    // Listen for WebSocket updates (Rider, Status, Fee)
    _orderSubscription = WebSocketService().orderUpdates.listen((update) {
      if (mounted) {
        final state = ActiveOrderState.instance;
        final order = state.getOrder(widget.orderId);
        if (order == null) return;

        // ... navigation logic using 'order' status
        if (order.orderStatus >= 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderStatusPage(
                foodTotal: widget.foodTotal,
                deliveryFee: order.deliveryFee ?? widget.deliveryFee,
              ),
            ),
          );
        }

        if (order.orderStatus == -1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderCancelPage(
                orderId: order.orderId,
                reason: order.cancelReason,
                shopId: order.shopId,
                shopName: order.shopName,
                shopNameMm: order.shopNameMm,
                shopLogo: order.shopLogo,
                shopImageUrl: order.shopImageUrl,
              ),
            ),
          );
        }

        // We intentionally do not override _showUploadSection here.
        // It will only change via user interaction on this page.
      }
    });
  }

  @override
  void dispose() {
    _dotsAnimController.dispose();
    ActiveOrderState.instance.removeListener(_onStateUpdated);
    AwaitingPaymentPage.isCurrentlyVisible = false;
    // Re-enable screenshots when leaving payment page
    if (Platform.isAndroid) {
      const MethodChannel('secure_screen').invokeMethod('disable');
    }
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _onStateUpdated() {
    if (mounted) {
      final order = ActiveOrderState.instance.getOrder(widget.orderId);
      setState(() {
        // We intentionally do not override _showUploadSection here anymore.
        // It will only change when the user clicks 'Save QR Code' or 'Yes, I have done Payment'.
      });
      if (order?.paymentMethodImageUrl == null) {
        _fetchPaymentMethodDetails();
      }
    }
  }

  Future<void> _fetchPaymentMethodDetails() async {
    final order = ActiveOrderState.instance.getOrder(widget.orderId);
    if (order == null || order.paymentMethodId == null) return;
    if (order.paymentMethodImageUrl != null) return;

    try {
      // Try multiple potential endpoints and fields for robustness
      Response? response;
      final id = order.paymentMethodId;

      // Attempt 1: profile/payment-types (matches backend controller)
      try {
        response = await ApiClient().dio.get(
          '${ApiClient.apiPrefix}/profile/payment-types/$id',
        );
      } catch (_) {
        // Attempt 2: payment-methods (user's suggested path)
        try {
          response = await ApiClient().dio.get(
            '${ApiClient.apiPrefix}/payment-methods/$id',
          );
        } catch (_) {}
      }

      if (response != null &&
          response.statusCode == 200 &&
          response.data != null) {
        final data = response.data;
        final paymentData = data['data'] ?? data;

        // Check for both possible field names: qrImageUrl (Prisma) and image (Legacy/Swagger)
        String? imageUrl = (paymentData['qrImageUrl'] ?? paymentData['image'])
            ?.toString();

        if (imageUrl != null && imageUrl.isNotEmpty) {
          imageUrl = imageUrl.replaceAll('\\', '/');
          if (imageUrl.startsWith('http://localhost') ||
              imageUrl.startsWith('http://10.0.2.2')) {
            imageUrl = imageUrl.replaceAll(
              RegExp(r'http://(localhost|10\.0\.2\.2)(:\d+)?'),
              ApiClient.baseUrl,
            );
          } else if (!imageUrl.startsWith('http')) {
            imageUrl = imageUrl.startsWith('/')
                ? '${ApiClient.baseUrl}$imageUrl'
                : '${ApiClient.baseUrl}/$imageUrl';
          }
          ActiveOrderState.instance.updatePaymentMethodImage(
            imageUrl,
            orderId: widget.orderId,
          );
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  void _goHome() {
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Save payment image to gallery using RepaintBoundary
  Future<void> _saveQrToGallery() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      await Gal.putImageBytes(
        Uint8List.fromList(pngBytes),
        album: 'MyTogether',
        name: 'qr_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        AppDialog.showToast(context, 'Payment image saved to gallery!');

        // Transition to upload section automatically
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && !_showUploadSection) {
            setState(() => _showUploadSection = true);
            ActiveOrderState.instance.setShowUploadSection(
              true,
              orderId: widget.orderId,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        AppDialog.showToast(
          context,
          'Failed to save image. Please try again.',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickReceiptImage() async {
    PermissionStatus status;
    if (await Permission.photos.isGranted ||
        await Permission.storage.isGranted) {
      status = PermissionStatus.granted;
    } else {
      final photosResult = await Permission.photos.request();
      if (photosResult.isGranted) {
        status = PermissionStatus.granted;
      } else {
        final storageResult = await Permission.storage.request();
        status = storageResult;
      }
    }

    if (!mounted) return;

    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        _showPermissionDialog();
      } else {
        AppDialog.showToast(
          context,
          'Gallery permission required to upload receipt.',
          isError: true,
        );
      }
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      final file = File(picked.path);
      final sizeInBytes = await file.length();
      final sizeInMb = sizeInBytes / (1024 * 1024);

      if (sizeInMb > 5.0) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Image Too Large',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'The selected image is ${sizeInMb.toStringAsFixed(1)}MB, which exceeds the 5MB limit. Please choose a smaller image or compress it.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: GradientText('OK', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          );
        }
        return;
      }
      setState(() => _receiptImage = file);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Gallery Permission',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Permission to access your gallery is permanently denied. Please enable it in your device settings.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          PrimaryGradientButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            height: 42,
            width: 150,
            borderRadius: BorderRadius.circular(8),
            child: Text(
              'Open Settings',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReceipt() async {
    if (_receiptImage == null || _isUploading) return;
    setState(() => _isUploading = true);

    final orderId = widget.orderId ?? ActiveOrderState.instance.orderId;
    if (orderId == null) {
      setState(() => _isUploading = false);
      AppDialog.showToast(
        context,
        'Order ID not found. Please try again.',
        isError: true,
      );
      return;
    }

    try {
      // 1. Convert image to Base64
      final bytes = await _receiptImage!.readAsBytes();
      final extension = _receiptImage!.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      final base64Image = 'data:$mimeType;base64,${base64.encode(bytes)}';

      // 2. Call API
      final intId = int.tryParse(orderId) ?? 0;
      final payload = {'orderId': intId, 'paymentSlipUrl': base64Image};

      await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/orders/uploadPaymentSlip',
        data: payload,
      );

      if (mounted) {
        // 3. Clear states and navigate
        final order = ActiveOrderState.instance.getOrder(widget.orderId);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderStatusPage(
              foodTotal: widget.foodTotal,
              deliveryFee: order?.deliveryFee ?? widget.deliveryFee,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to upload receipt. Please try again.';
        if (e is DioException) {
          errorMsg = e.response?.data?['message'] ?? e.message ?? errorMsg;
        }
        AppDialog.showToast(context, errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showCancelConfirmationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Cancel Order?',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to cancel this order?',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Keep Order',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryGradientButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelOrder();
                    },
                    child: Text(
                      'Cancel Order',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
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

  Future<void> _cancelOrder() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);

    try {
      final success = await ActiveOrderState.instance.cancelActiveOrder(
        orderId: widget.orderId,
      );
      if (success && mounted) {
        AppDialog.showToast(context, 'Order cancelled successfully.');
        _goHome();
      } else if (mounted) {
        AppDialog.showToast(
          context,
          'Failed to cancel order. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showToast(
          context,
          'Connection error. Could not cancel order.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Widget _buildPaymentImage() {
    final order = ActiveOrderState.instance.getOrder(widget.orderId);
    String? qrUrl = order?.shopPaymentQrUrl ?? order?.paymentMethodImageUrl;

    if (qrUrl != null && qrUrl.isNotEmpty) {
      qrUrl = qrUrl.replaceAll('\\', '/');
      if (qrUrl.startsWith('http://localhost') ||
          qrUrl.startsWith('http://10.0.2.2')) {
        qrUrl = qrUrl.replaceAll(
          RegExp(r'http://(localhost|10\.0\.2\.2)(:\d+)?'),
          ApiClient.baseUrl,
        );
      } else if (!qrUrl.startsWith('http')) {
        qrUrl = qrUrl.startsWith('/')
            ? '${ApiClient.baseUrl}$qrUrl'
            : '${ApiClient.baseUrl}/$qrUrl';
      }
    }

    if (qrUrl == null || qrUrl.isEmpty) {
      return const Center(child: CustomLoadingIndicator(size: 40));
    }

    return CachedNetworkImage(
      imageUrl: qrUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) =>
          const Center(child: CustomLoadingIndicator(size: 24)),
      errorWidget: (context, url, error) =>
          _buildNoImageState(isError: true, failedUrl: url),
    );
  }

  Widget _buildNoImageState({bool isError = false, String? failedUrl}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              isError
                  ? 'Error loading payment image'
                  : 'Awaiting payment image...',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const CustomLoadingIndicator(size: 40),
          const SizedBox(height: 24),
          Text(
            'Verifying Payment',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We are currently verifying your payment receipt. This usually takes a few minutes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '(ငွေလွှဲဖြတ်ပိုင်းကို စစ်ဆေးနေပါသည်။ ခေတ္တစောင့်ဆိုင်းပေးပါ။)',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_CameraUploadIcon(), SizedBox(height: 16), _UploadText()],
      ),
    );
  }

  Widget _buildReceiptPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            _receiptImage!,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        // Remove / re-pick button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _pickReceiptImage,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _receiptImage != null;
    final order = ActiveOrderState.instance.getOrder(widget.orderId);
    final bool isVerifying = order?.isPaymentChecking == true;
    final bool isReupload = order?.isSlipRequested == true;
    final String pageTitle = isReupload
        ? 'Awaiting Payment'
        : (isVerifying ? 'Verifying Payment' : 'Confirm Payment');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 20,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        title: Text(
          pageTitle,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: _goHome,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // ── Payment Summary Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PAYMENT SUMMARY',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _summaryRow(
                      'Food Price',
                      order?.displayFoodPrice ??
                          '฿ ${widget.foodTotal.toStringAsFixed(0)}',
                      isValue: false,
                    ),
                    const SizedBox(height: 10),
                    _summaryRow(
                      order?.deliveryType == 'NORMAL'
                          ? 'Est. Delivery Fee'
                          : 'Delivery Fee',
                      '',
                      customValue:
                          (order?.deliveryFee != null &&
                              order!.deliveryFee! > 0)
                          ? (order.deliveryType == 'NORMAL'
                                ? GradientText(
                                    '฿ ${order.deliveryFee!.toInt()}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : Text(
                                    '฿ ${order.deliveryFee!.toInt()}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ))
                          : (order?.deliveryType == 'NORMAL')
                          ? Text(
                              'Calculate Later',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            )
                          : AnimatedBuilder(
                              animation: _dotsAnimController,
                              builder: (context, _) {
                                final dots =
                                    '.' *
                                    ((_dotsAnimController.value * 4).floor() %
                                        4);
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Calculating',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 15,
                                      child: Text(
                                        dots,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                      isValue: false,
                    ),
                    if (order?.deliveryType != 'NORMAL') ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: _DottedDivider(color: Color(0xFFCCCCCC)),
                      ),
                      _summaryRow(
                        'Total',
                        '฿ ${(widget.foodTotal + (order?.deliveryFee ?? widget.deliveryFee)).toStringAsFixed(0)}',
                        isValue: true,
                      ),
                    ],
                    if (order?.estimatedTime != null &&
                        order!.estimatedTime!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _summaryRow(
                        'Estimated Waiting Time',
                        order.estimatedTime!,
                        isValue: false,
                      ),
                    ],
                  ],
                ),
              ),
              if (order?.deliveryType == 'NORMAL') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GradientIcon(
                        icon: PhosphorIconsFill.info,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GradientText(
                          'The shop will arrange a separate delivery service for you. Please pay for the food now; the delivery fee will be paid directly to the rider later.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── Rider Info (if available) ──
              if (order?.riderName != null &&
                  order!.riderName!.trim().isNotEmpty) ...[
                _buildRiderInfoCard(),
                const SizedBox(height: 20),
              ],

              // ── VERIFYING STATE ──
              if (isVerifying) ...[
                _buildVerifyingSection(),
                const SizedBox(height: 24),
              ] else ...[
                if (!_showUploadSection) ...[
                  // ── STEP 1: Payment QR Image ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Timer dummy for now
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIcons.clock(),
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              GradientText(
                                (order?.estimatedTime != null &&
                                        order!.estimatedTime!.isNotEmpty)
                                    ? order.estimatedTime!
                                    : '05:00',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Payment image
                        RepaintBoundary(
                          key: _qrKey,
                          child: Container(
                            width: double.infinity,
                            height: 280,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _buildPaymentImage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // ── STEP 2: Upload Receipt ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '2',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Upload Receipt',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            // Back Button to return to Step 1
                            if (!isReupload)
                              GestureDetector(
                                onTap: () {
                                  setState(() => _showUploadSection = false);
                                  ActiveOrderState.instance
                                      .setShowUploadSection(
                                        false,
                                        orderId: widget.orderId,
                                      );
                                },
                                child: GradientText(
                                  'Back',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 38),
                          child: Text(
                            'Upload a screenshot of your payment confirmation.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Upload box
                        GestureDetector(
                          onTap: _pickReceiptImage,
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 160),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            child: _receiptImage == null
                                ? _buildUploadPlaceholder()
                                : _buildReceiptPreview(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              PhosphorIcons.info(),
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GradientText(
                                isReupload
                                    ? 'The restaurant requested a new receipt. Please upload clearly.'
                                    : 'Ensure the transaction date, amount and time are clearly visible.',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: (isVerifying || order == null)
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_showUploadSection) ...[
                    PrimaryGradientButton(
                      onPressed: _saveQrToGallery,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIcons.downloadSimple(),
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Save QR Code',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _showUploadSection = true);
                          ActiveOrderState.instance.setShowUploadSection(
                            true,
                            orderId: widget.orderId,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Yes, I have done Payment',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    PrimaryGradientButton(
                      onPressed: (canSubmit && !_isUploading)
                          ? _submitReceipt
                          : null,
                      isLoading: _isUploading,
                      child: Text(
                        'Submit Receipt',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: _isCancelling
                          ? null
                          : _showCancelConfirmationSheet,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: Text(
                        'Cancel Order',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    required bool isValue,
    Widget? customValue,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: isValue ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (customValue != null)
          customValue
        else if (isValue)
          GradientText(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.normal,
            ),
          ),
      ],
    );
  }

  Widget _buildRiderInfoCard() {
    final order = ActiveOrderState.instance.getOrder(widget.orderId);
    final name = order?.riderName ?? 'Unknown Rider';
    final phone = order?.riderPhone ?? 'No Phone';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const GradientIcon(icon: PhosphorIconsFill.moped, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  phone,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                if (order?.riderVehicleNumber != null &&
                    order!.riderVehicleNumber!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: GradientText(
                      'Vehicle No: ${order.riderVehicleNumber!}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              // Call rider logic if needed
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                PhosphorIconsFill.phoneCall,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _CameraUploadIcon extends StatelessWidget {
  const _CameraUploadIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: GradientIcon(icon: PhosphorIcons.cameraPlus(), size: 28),
    );
  }
}

class _UploadText extends StatelessWidget {
  const _UploadText();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Tap to upload',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'or take a photo of your receipt',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

class _DottedDivider extends StatelessWidget {
  final Color color;

  const _DottedDivider({this.color = Colors.grey});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const dashWidth = 4.0;
        final dashCount = (constraints.constrainWidth() / (2 * dashWidth))
            .floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            );
          }),
        );
      },
    );
  }
}
