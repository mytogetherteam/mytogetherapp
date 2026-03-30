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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/network/api_client.dart';
import '../../data/active_order_state.dart';
import '../../../../core/utils/navigation_controller.dart';
import 'order_status_page.dart';
import 'order_cancel_page.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/utils/price_formatter.dart';

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

class _AwaitingPaymentPageState extends State<AwaitingPaymentPage> {
  final GlobalKey _qrKey = GlobalKey();
  bool _showUploadSection = false;
  File? _receiptImage;
  bool _isUploading = false;
  bool _isCancelling = false;
  StreamSubscription? _orderSubscription;

  @override
  void initState() {
    super.initState();
    AwaitingPaymentPage.isCurrentlyVisible = true;
    // Prevent screenshots/screen recording on this sensitive payment page
    if (Platform.isAndroid) {
      const MethodChannel('secure_screen').invokeMethod('enable');
    }
    // Load persisted state if needed
    final order = ActiveOrderState.instance.getOrder(widget.orderId);
    _showUploadSection = order?.showUploadSection ?? false;

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
                orderId: widget.orderId,
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

        setState(() {
          _showUploadSection = order.showUploadSection;
        });
      }
    });
  }

  @override
  void dispose() {
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
        if (order != null) {
          _showUploadSection = order.showUploadSection;
        }
      });
    }
  }


  void _goHome() {
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showSlipRequestedToast() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill), color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'New payment slip requested by restaurant',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFED3973),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Save QR to gallery
  Future<void> _saveQrToGallery() async {
    // Save QR in the background
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('QR Code saved to gallery!',
                  style: GoogleFonts.poppins(fontSize: 13)),
              backgroundColor: const Color(0xFFED3973),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );

          // Transition to upload section
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && !_showUploadSection) {
              setState(() => _showUploadSection = true);
              ActiveOrderState.instance.setShowUploadSection(true, orderId: widget.orderId);
            }
          });
        }
      } catch (_) {
        // Silent fail — gallery save is best-effort
      }
    }

  Future<void> _pickReceiptImage() async {
    PermissionStatus status;
    if (await Permission.photos.isGranted || await Permission.storage.isGranted) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gallery permission required to upload receipt.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
          ),
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

      if (sizeInMb > 1.0) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Image Too Large', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Text(
                'The selected image is ${sizeInMb.toStringAsFixed(1)}MB, which exceeds the 1MB limit. Please choose a smaller image or compress it.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK', style: GoogleFonts.poppins(color: const Color(0xFFED3973))),
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
        title: Text('Gallery Permission',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Permission to access your gallery is permanently denied. Please enable it in your device settings.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFED3973),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Open Settings', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReceipt() async {
    if (_receiptImage == null || _isUploading) return;
    setState(() => _isUploading = true);

    final currentOrderId = widget.orderId ?? ActiveOrderState.instance.orderId;
    if (currentOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order ID not found. Please try again.', style: GoogleFonts.poppins())),
      );
      return;
    }

    try {
      // Simulate fake upload delay
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // 3. Clear states and navigate
        final order = ActiveOrderState.instance.getOrder(currentOrderId);
        
        // Mock updating local state to "verifying" visually or directly go to status
        // order status usually stays at 1 (PAYMENT CHECKING)
        ActiveOrderState.instance.setPaymentChecking(true, orderId: currentOrderId);

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
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
              ),
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
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelOrder();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFED3973),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Cancel Order',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
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
      final success = await ActiveOrderState.instance.cancelActiveOrder(orderId: widget.orderId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order cancelled successfully.', 
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
            backgroundColor: const Color(0xFFED3973),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _goHome();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order. Please try again.', 
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error. Could not cancel order.', 
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }








  Widget _buildQrSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
          const SizedBox(height: 10),
          // Payment Image (replaces static QR)
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildPaymentImage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentImage() {
    // GENERATE QR LOCALLY: No more network loading or blank screens
    // This uses the qr_flutter package to render a mock PromptPay code instantly
    return Center(
      child: QrImageView(
        data: '00020101021129370016A000000677010111011300669112233445802TH5303764540510.005802TH62070703***6304',
        version: QrVersions.auto,
        size: 260.0,
        gapless: false,
        embeddedImageStyle: const QrEmbeddedImageStyle(
          size: Size(40, 40),
        ),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildNoImageState({bool isError = false}) {
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
          Text(
            isError ? 'Error loading payment image' : 'Awaiting payment image...',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
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
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFED3973),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadReceiptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_showUploadSection && !ActiveOrderState.instance.isSlipRequested)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showUploadSection = false);
                    ActiveOrderState.instance.setShowUploadSection(false, orderId: widget.orderId);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: const Icon(Icons.arrow_back, size: 20, color: Colors.black87),
                  ),
                ),
              ),
            Text(
              ActiveOrderState.instance.getOrder(widget.orderId)?.isSlipRequested == true ? 'Re-upload Receipt' : 'Upload Receipt',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Upload box
        GestureDetector(
          onTap: _receiptImage == null ? _pickReceiptImage : null,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFED3973),
                width: 2,
                // Dashed border via custom painter
              ),
            ),
            child: _receiptImage == null
                ? _buildUploadPlaceholder()
                : _buildReceiptPreview(),
          ),
        ),

        const SizedBox(height: 12),

        // Info hint
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(PhosphorIcons.info(),
                size: 16, color: const Color(0xFFED3973)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ActiveOrderState.instance.getOrder(widget.orderId)?.isSlipRequested == true
                    ? 'The restaurant has requested a new receipt. (ဆိုင်မှ ဖြတ်ပိုင်းအသစ် ပြန်တင်ခိုင်းထားပါသည်။) Please ensure the transaction details are clearly visible.'
                    : 'Please ensure the transaction date, time, and amount are clearly visible in the photo.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFED3973),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadPlaceholder() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CameraUploadIcon(),
          SizedBox(height: 16),
          _UploadText(),
        ],
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
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 6)
                ],
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 20, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _receiptImage != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with title and X button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ActiveOrderState.instance.getOrder(widget.orderId)?.isSlipRequested == true
                        ? 'Re-upload Receipt'
                        : (ActiveOrderState.instance.getOrder(widget.orderId)?.isPaymentChecking == true
                            ? 'Verifying Payment' 
                            : (_showUploadSection ? 'Confirm payment' : 'Awaiting Payment')),
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                  GestureDetector(
                    onTap: _goHome,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6)
                        ],
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Payment Summary Card
              Container(
                padding: const EdgeInsets.all(25),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (widget.orderId != null)
                          Text(
                            '#${widget.orderId!}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _summaryRow('Food Price',
                        (ActiveOrderState.instance.getOrder(widget.orderId)?.displayFoodPrice ?? widget.foodTotal.toStringAsFixed(0)).toFormattedPrice(),
                        isValue: false),
                    const SizedBox(height: 16),
                    _summaryRow('Delivery Fee',
                        // --- MOCK SAFEGUARD --- 
                        // Force fee to 30 if old cached distance is wildly out of bounds
                        ((ActiveOrderState.instance.getOrder(widget.orderId)?.deliveryFee ?? widget.deliveryFee) > 1000 ? '30' : (ActiveOrderState.instance.getOrder(widget.orderId)?.displayDeliveryFee ?? (ActiveOrderState.instance.getOrder(widget.orderId)?.deliveryFee ?? widget.deliveryFee).toStringAsFixed(0))).toFormattedPrice(),
                        isValue: false),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: _DottedDivider(color: Color(0xFFCCCCCC)),
                    ),
                    _summaryRow('Total',
                        // --- MOCK SAFEGUARD ---
                        // Force recalculation if fee was clamped
                        (((ActiveOrderState.instance.getOrder(widget.orderId)?.deliveryFee ?? widget.deliveryFee) > 1000) 
                          ? (widget.foodTotal + 30).toStringAsFixed(0) 
                          : (ActiveOrderState.instance.getOrder(widget.orderId)?.displayTotalAmount ?? (widget.foodTotal + (ActiveOrderState.instance.getOrder(widget.orderId)?.deliveryFee ?? widget.deliveryFee)).toStringAsFixed(0))
                        ).toFormattedPrice(),
                        isValue: true),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Rider Info Section (If available)
              if (ActiveOrderState.instance.getOrder(widget.orderId)?.riderName != null) ...[
                _buildRiderInfoCard(),
                const SizedBox(height: 20),
              ],

              // Conditional: QR section OR Upload Receipt section OR Verifying state
              if (ActiveOrderState.instance.getOrder(widget.orderId)?.isPaymentChecking == true)
                _buildVerifyingSection()
              else ...[
                if (!_showUploadSection) _buildQrSection(),
                if (_showUploadSection) _buildUploadReceiptSection(),
              ],

              const SizedBox(height: 28),

            // --- BUTTONS ---
            if (ActiveOrderState.instance.getOrder(widget.orderId)?.isPaymentChecking != true) ...[
              if (!_showUploadSection) ...[
                // Save QR Code -> switches to upload section
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveQrToGallery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFED3973),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFED3973).withValues(alpha: 0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.downloadSimple(), size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Save Payment Image',
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Yes, I have done payment
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _showUploadSection = true);
                      ActiveOrderState.instance.setShowUploadSection(true, orderId: widget.orderId);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'I have already paid',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87),
                    ),
                  ),
                ),
              ] else ...[
                // Submit receipt (enabled only when image is selected)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (canSubmit && !_isUploading) ? _submitReceipt : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFED3973),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFFED3973).withValues(alpha: 0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isUploading 
                        ? const CustomLoadingIndicator(size: 24, color: Colors.white)
                        : Text(
                            'Submit receipt',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Cancel Order Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: _isCancelling ? null : _showCancelConfirmationSheet,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFED3973),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Cancel Order',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _summaryRow(String label, String value, {required bool isValue}) {
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
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isValue ? FontWeight.bold : FontWeight.normal,
            color: isValue ? const Color(0xFFED3973) : Colors.black87,
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
              color: const Color(0xFFFFE8EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(PhosphorIconsFill.moped,
                color: Color(0xFFED3973), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DELIVERY RIDER',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.8,
                  ),
                ),
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
                color: const Color(0xFFED3973),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(PhosphorIconsFill.phoneCall,
                  color: Colors.white, size: 22),
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
      child: Icon(
        PhosphorIcons.cameraPlus(),
        size: 28,
        color: const Color(0xFFED3973),
      ),
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
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[500],
          ),
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
        final dashCount =
            (constraints.constrainWidth() / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}
