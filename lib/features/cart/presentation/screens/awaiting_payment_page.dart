import 'dart:async';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../order/data/repositories/order_repository.dart';
import '../../data/active_order_state.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/utils/order_tax.dart';
import '../../../../core/utils/price_formatter.dart';
import 'order_status_page.dart';
import 'order_cancel_page.dart';
import 'revise_order_page.dart';
import '../widgets/revise_unavailable_items_section.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/presentation/widgets/gradient_icon.dart';
import '../../../chat/presentation/screens/chat_page.dart';
import '../../../chat/data/services/chat_unread_controller.dart';
import '../../../chat/presentation/widgets/chat_unread_badge.dart';
import '../../../reviews/presentation/widgets/image_upload_bottom_sheet.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _dotsAnimController;
  final GlobalKey _qrKey = GlobalKey();
  bool _showUploadSection = false;
  File? _receiptImage;
  bool _isUploading = false;
  bool _isCancelling = false;
  StreamSubscription? _orderSubscription;
  final ImagePicker _imagePicker = ImagePicker();

  /// Guards against pushing the next screen more than once when several
  /// status updates (WebSocket + backend reconcile) land close together.
  bool _hasNavigated = false;

  /// A payment-only revision: the shop sent the order back (status REVISED)
  /// without flagging any unavailable items, meaning the customer just needs to
  /// re-upload a correct payment slip. The new payment image is submitted to
  /// the respondRevise endpoint (`PATCH /user/orders/:id/items`).
  bool _isPaymentReviseOrder(ActiveOrderItem? order) =>
      order != null &&
      order.isRevised &&
      order.resolvedReviseInfo.items.isEmpty;

  /// Parsed integer id of this order, or null when unavailable.
  int? get _chatOrderId {
    final orderIdStr = (widget.orderId ?? ActiveOrderState.instance.orderId)
        ?.replaceAll('#', '');
    final orderId = int.tryParse(orderIdStr ?? '');
    return (orderId != null && orderId > 0) ? orderId : null;
  }

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

    // When the shop has explicitly requested a new payment slip (Revise
    // Payment), jump straight to the upload step so the user can re-upload a
    // correct/clearer slip. Otherwise show Step 1 (the QR) first.
    final initialOrder = ActiveOrderState.instance.getOrder(widget.orderId);
    final bool startOnUpload = initialOrder?.isSlipRequested == true ||
        _isPaymentReviseOrder(initialOrder);
    _showUploadSection = startOnUpload;

    // Ensure the global state is synced so it doesn't cause weird UI jumps
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ActiveOrderState.instance.setShowUploadSection(
        startOnUpload,
        orderId: widget.orderId,
      );
    });

    // Fetch detailed payment method image if needed
    _fetchPaymentMethodDetails();

    // Track unread chat messages for this order so the chat icon can badge them.
    ChatUnreadController.instance.start();
    final chatOrderId = _chatOrderId;
    if (chatOrderId != null) {
      ChatUnreadController.instance.refreshOrder(chatOrderId);
    }

    // Listen to global state for real-time rebuilds (e.g., when QR URL arrives)
    ActiveOrderState.instance.addListener(_onStateUpdated);

    // Reconcile with the backend on open and whenever the app returns to the
    // foreground. Live WebSocket order events can be missed (socket reconnect,
    // app backgrounded, events fired before this page subscribed), which would
    // otherwise leave the user stuck on "awaiting confirmation" long after the
    // shop has already advanced (or completed) the order.
    WidgetsBinding.instance.addObserver(this);
    _reconcileWithBackend();

    // Listen for WebSocket updates (Rider, Status, Fee)
    _orderSubscription = WebSocketService().orderUpdates.listen((update) {
      if (!mounted) return;
      // We intentionally do not override _showUploadSection here.
      // It will only change via user interaction on this page.
      _advanceForOrder(ActiveOrderState.instance.getOrder(widget.orderId));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconcileWithBackend();
    }
  }

  /// Pulls the authoritative order status from the backend, then advances the
  /// UI if the order has already moved past the awaiting-payment stage.
  Future<void> _reconcileWithBackend() async {
    await ActiveOrderState.instance.syncActiveOrder(orderId: widget.orderId);
    if (!mounted) return;
    _advanceForOrder(ActiveOrderState.instance.getOrder(widget.orderId));
  }

  /// Navigates off the awaiting-payment screen once the order has actually
  /// progressed: paid/cooking/on-the-way/delivered → status page, cancelled →
  /// cancel page. Guarded by [_hasNavigated] so it fires at most once.
  void _advanceForOrder(ActiveOrderItem? order) {
    if (!mounted || _hasNavigated || order == null) return;

    if (order.orderStatus >= 2) {
      _hasNavigated = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderStatusPage(
            foodTotal: widget.foodTotal,
            deliveryFee: order.deliveryFee ?? widget.deliveryFee,
          ),
        ),
      );
      return;
    }

    if (order.orderStatus == -1) {
      _hasNavigated = true;
      // [OrderActionPresenter] shows the shop-cancel page (pushReplacement).
      return;
    }
  }

  @override
  void dispose() {
    _dotsAnimController.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
        // It will only change when the user clicks context.tr('payment.save_qr') or context.tr('payment.done_payment').
      });
      if (order?.paymentMethodImageUrl == null) {
        _fetchPaymentMethodDetails();
      }
      // A status change applied to global state (e.g. from a backend sync or a
      // WebSocket frame handled elsewhere) should also move the user forward.
      _advanceForOrder(order);
    }
  }

  Future<void> _fetchPaymentMethodDetails() async {
    final order = ActiveOrderState.instance.getOrder(widget.orderId);
    if (order == null || order.paymentMethodId == null) return;
    if (order.paymentMethodImageUrl != null) return;

    try {
      Response? response;
      final id = order.paymentMethodId;

      // Primary: GET /api/user/orders/:orderId returns the order with its
      // paymentMethod (incl. qr/accountNumber) via findAwaitingPaymentInfo.
      final orderIdStr = widget.orderId?.replaceAll('#', '');
      if (orderIdStr != null && orderIdStr.isNotEmpty) {
        try {
          response = await ApiClient().dio.get(
            '${ApiClient.apiPrefix}/user/orders/$orderIdStr',
          );
        } catch (_) {}
      }

      // Fallback: list all active payment methods and pick the one matching
      // the order's paymentMethodId. Backend route: GET /api/payment-methods.
      if (response == null || response.statusCode != 200) {
        try {
          final listResp = await ApiClient().dio.get(
            '${ApiClient.apiPrefix}/payment-methods',
          );
          if (listResp.statusCode == 200 && listResp.data != null) {
            final list = listResp.data is Map
                ? listResp.data['data'] as List<dynamic>? ?? <dynamic>[]
                : listResp.data as List<dynamic>? ?? <dynamic>[];
            final match = list.firstWhere(
              (e) => e is Map && (e['id'] == id || e['id']?.toString() == id?.toString()),
              orElse: () => null,
            );
            if (match is Map) {
              response = Response(
                requestOptions: listResp.requestOptions,
                statusCode: 200,
                data: {'data': match},
              );
            }
          }
        } catch (_) {}
      }

      if (response != null &&
          response.statusCode == 200 &&
          response.data != null) {
        final data = response.data;
        // Unwrap envelope `{ data: { paymentMethod: {...} } }` (user/orders/:id)
        // or `{ data: {...} }` (payment-methods).
        Map<String, dynamic> paymentData;
        final inner = (data is Map ? data['data'] : null) ?? data;
        if (inner is Map && inner['paymentMethod'] is Map) {
          paymentData = Map<String, dynamic>.from(inner['paymentMethod'] as Map);
        } else if (inner is Map) {
          paymentData = Map<String, dynamic>.from(inner);
        } else {
          paymentData = <String, dynamic>{};
        }

        // Field name varies: `qr` (shop-payment-method), `qrImageUrl` (Prisma
        // PaymentMethod) or `image`/`iconUrl` (legacy).
        String? imageUrl = (paymentData['qr'] ??
                paymentData['qrImageUrl'] ??
                paymentData['iconUrl'] ??
                paymentData['image'])
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
        AppDialog.showToast(context, context.tr('payment.image_saved'));

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
          context.tr('payment.save_failed'),
          isError: true,
        );
      }
    }
  }

  Future<void> _pickReceiptImage() async {
    if (_isUploading) return;

    final action = await ImageUploadBottomSheet.show(
      context,
      showRemove: _receiptImage != null,
    );
    if (action == null || !mounted) return;

    if (action == ImageUploadAction.remove) {
      _removeReceiptImage();
      return;
    }

    final source = action == ImageUploadAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    // Camera needs explicit permission; gallery uses the system picker (incl.
    // iOS limited photo access) without a blocking pre-check.
    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      if (!mounted) return;
      if (!cameraStatus.isGranted) {
        if (cameraStatus.isPermanentlyDenied) {
          _showPermissionDialog();
        } else {
          AppDialog.showToast(
            context,
            context.tr('payment.gallery_required'),
            isError: true,
          );
        }
        return;
      }
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );

      if (picked == null || !mounted) return;

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
                context.tr('payment.image_too_large'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Text(
                context.trArgs('payment.image_too_large_msg', {
                  'size': sizeInMb.toStringAsFixed(1),
                }),
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: GradientText(
                    context.tr('common.confirm'),
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }
      setState(() => _receiptImage = file);
    } catch (_) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('auth.could_not_pick_image'),
          isError: true,
        );
      }
    }
  }

  /// Clears the picked payment slip so the user can start over after uploading
  /// the wrong image. Submission is disabled again until a new image is chosen.
  void _removeReceiptImage() {
    if (_isUploading) return;
    setState(() => _receiptImage = null);
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('payment.gallery_permission'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.tr('payment.gallery_denied'),
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel'), style: GoogleFonts.poppins()),
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
              context.tr('payment.open_settings'),
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
        context.tr('payment.order_id_not_found'),
        isError: true,
      );
      return;
    }

    try {
      final intId =
          int.tryParse(orderId.replaceAll('#', '')) ?? int.tryParse(orderId) ?? 0;

      // A payment-only revision is re-submitted through the respondRevise
      // endpoint (PATCH /user/orders/:id/items); a normal slip upload (first
      // time or shop-requested re-upload) goes to PATCH /user/orders/:id/payment.
      // Both move the order to AWAITING_APPROVAL on success.
      final order = ActiveOrderState.instance.getOrder(widget.orderId);
      if (_isPaymentReviseOrder(order)) {
        await OrderRepository().revisePaymentImage(
          orderId: intId,
          file: _receiptImage!,
        );
      } else {
        final extension = _receiptImage!.path.split('.').last.toLowerCase();
        final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
        final filename =
            'payment_${DateTime.now().millisecondsSinceEpoch}.$extension';

        final formData = FormData.fromMap({
          'paymentImage': await MultipartFile.fromFile(
            _receiptImage!.path,
            filename: filename,
            contentType: DioMediaType.parse(mimeType),
          ),
        });

        await ApiClient().dio.patch(
          '${ApiClient.apiPrefix}/user/orders/$intId/payment',
          data: formData,
        );
      }

      if (mounted) {
        // Clear states and navigate
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
        String errorMsg = context.tr('payment.upload_failed');
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
              context.tr('order_tracking.cancel_title'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('order_tracking.cancel_confirm'),
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
                      context.tr('order_tracking.keep_order'),
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
                      context.tr('order_tracking.cancel_order'),
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

    // Snapshot the shop/order details before cancelling. cancelActiveOrder()
    // clears the order from state on success, so we must capture it first for
    // the cancellation screen to have data to show.
    final order = ActiveOrderState.instance.getOrder(widget.orderId);

    try {
      final success = await ActiveOrderState.instance.cancelActiveOrder(
        orderId: widget.orderId,
      );
      if (success && mounted) {
        AppDialog.showToast(context, context.tr('payment.cancel_success'));
        _hasNavigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderCancelPage(
              orderId: order?.orderId ?? widget.orderId ?? '',
              reason: order?.cancelReason,
              shopId: order?.shopId,
              shopName: order?.shopNameEn ??
                  order?.shopName ??
                  order?.restaurantName ??
                  order?.storeName,
              shopNameMm: order?.shopNameMm,
              shopNameTh: order?.shopNameTh,
              shopLogo: order?.shopLogo ?? order?.logoPath,
              shopImageUrl: order?.shopImageUrl,
              cancelledByUser: true,
            ),
          ),
        );
      } else if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('payment.cancel_failed'),
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('payment.connection_error'),
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

    return CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
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
                  ? context.tr('payment.error_loading_image')
                  : context.tr('payment.awaiting_image'),
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
            context.tr('payment.verifying'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('payment.verifying_desc'),
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
        // Change (re-pick) and remove actions so the user can fix a wrongly
        // selected slip before submitting.
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _previewActionButton(
                icon: Icons.refresh_rounded,
                tooltip: context.tr('payment.change_image'),
                onTap: _isUploading ? null : _pickReceiptImage,
              ),
              const SizedBox(width: 8),
              _previewActionButton(
                icon: Icons.close_rounded,
                tooltip: context.tr('payment.remove_image'),
                iconColor: Colors.red,
                onTap: _isUploading ? null : _removeReceiptImage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    Color iconColor = Colors.black87,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? Colors.grey : iconColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _receiptImage != null;
    final order = ActiveOrderState.instance.getOrder(widget.orderId);
    final bool isVerifying = order?.isPaymentChecking == true;
    final bool isPaymentRevise = _isPaymentReviseOrder(order);
    // An item revision (unavailable items) still needs the "review items" flow;
    // a payment-only revision behaves like a slip re-upload request.
    final bool isItemRevise = order?.isRevised == true && !isPaymentRevise;
    final bool isReupload = order?.isSlipRequested == true || isPaymentRevise;
    final String pageTitle = isReupload
        ? context.tr('payment.awaiting_title')
        : (isVerifying
            ? context.tr('payment.verifying')
            : context.tr('payment.confirm_title'));

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

              if (isItemRevise) ...[
                _buildReviseBanner(order),
                const SizedBox(height: 14),
              ] else if (isReupload) ...[
                _buildSlipRequestBanner(order?.reviseReason),
                const SizedBox(height: 14),
              ],

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
                          context.tr('payment.summary'),
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
                      context.tr('payment.food_price'),
                      order?.displayFoodPrice ??
                          '฿ ${widget.foodTotal.toStringAsFixed(0)}',
                      isValue: false,
                    ),
                    const SizedBox(height: 10),
                    _summaryRow(
                      context.tr('order_status.tax'),
                      order?.displayTaxAmount ??
                          (order?.taxAmount ??
                                  OrderTax.calculateTax(widget.foodTotal))
                              .toFormattedPrice(),
                      isValue: false,
                    ),
                    const SizedBox(height: 10),
                    if (order?.isPickupFulfillment != true) ...[
                      _summaryRow(
                        order?.deliveryType == 'NORMAL'
                            ? context.tr('payment.est_delivery_fee')
                            : context.tr('order_status.delivery_fee'),
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
                                context.tr('payment.calculate_later'),
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
                                        context.tr('order_tracking.calculating'),
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
                    ],
                    if (order?.isPickupFulfillment == true ||
                        order?.deliveryType != 'NORMAL') ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: _DottedDivider(color: Color(0xFFCCCCCC)),
                      ),
                      _summaryRow(
                        context.tr('cart.total'),
                        order?.displayTotalAmount ??
                            (order?.isPickupFulfillment == true
                                ? OrderTax.calculateTotal(
                                    itemSubtotal: widget.foodTotal,
                                  ).toFormattedPrice()
                                : OrderTax.calculateTotal(
                                    itemSubtotal: widget.foodTotal,
                                    deliveryFee:
                                        order?.deliveryFee ?? widget.deliveryFee,
                                  ).toFormattedPrice()),
                        isValue: true,
                      ),
                    ],
                    if (order?.estimatedTime != null &&
                        order!.estimatedTime!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _summaryRow(
                        context.tr('payment.est_waiting_time'),
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
                          context.tr('payment.separate_delivery_note'),
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
                                PhosphorIcons.clock,
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
                                  context.tr('payment.upload_receipt'),
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
                                  context.tr('payment.back'),
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
                            context.tr('payment.upload_hint'),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Upload box
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _isUploading ? null : _pickReceiptImage,
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
                              PhosphorIcons.info,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GradientText(
                                isReupload
                                    ? context.tr('payment.receipt_requested')
                                    : context.tr('payment.receipt_visible_hint'),
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
                            PhosphorIcons.downloadSimple,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr('payment.save_qr'),
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
                          context.tr('payment.done_payment'),
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
                        context.tr('payment.submit_receipt'),
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
                        context.tr('order_tracking.cancel_order'),
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

  Future<void> _openReviseOrder() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviseOrderPage(orderId: widget.orderId ?? ''),
      ),
    );
    // State refreshes via the ActiveOrderState listener after re-submit.
    if (mounted) setState(() {});
  }

  /// Shown when the shop sent the order back asking for a new payment slip.
  /// Surfaces the shop's reason so the user understands what to fix before
  /// re-uploading.
  Widget _buildSlipRequestBanner(String? reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.warningCircle,
                  color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('payment.reupload_reason_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (reason != null && reason.trim().isNotEmpty)
                ? reason
                : context.tr('payment.receipt_requested'),
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildReviseBanner(ActiveOrderItem? order) {
    final resolved = order?.resolvedReviseInfo ??
        (items: const <String>[], reason: '');
    final reasonText = resolved.reason.isNotEmpty
        ? resolved.reason
        : context.tr('revise.banner_message');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.warningCircle,
                  color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                context.tr('revise.banner_title'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (resolved.items.isNotEmpty) ...[
            ReviseUnavailableItemsSection(items: resolved.items),
            const SizedBox(height: 8),
            Text(
              context.tr('revise.reason_title'),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade900,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            reasonText,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryGradientButton(
              onPressed: _openReviseOrder,
              child: Text(
                context.tr('revise.review_button'),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderInfoCard() {
    final order = ActiveOrderState.instance.getOrder(widget.orderId);
    final name = order?.riderName ?? context.tr('payment.unknown_rider');
    final phone = order?.riderPhone ?? context.tr('payment.no_phone');

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
                      context.trArgs('payment.vehicle_no', {'number': order.riderVehicleNumber!}),
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
          const SizedBox(width: 10),
          ChatUnreadBadge(
            orderId: _chatOrderId,
            child: GestureDetector(
              onTap: () async {
                final orderId = _chatOrderId;
                if (orderId == null) {
                  AppDialog.showToast(
                    context,
                    context.tr('chat.order_unavailable'),
                    isError: true,
                  );
                  return;
                }
                ChatUnreadController.instance.clear(orderId);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      orderId: orderId,
                      peerName: order?.riderName ??
                          context.tr('order_status.delivery_rider'),
                      peerSubtitle: context.tr('order_status.delivery_rider'),
                      fallbackIcon: Icons.delivery_dining_rounded,
                    ),
                  ),
                );
                if (!mounted) return;
                await ChatUnreadController.instance.refreshOrder(orderId);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const GradientIcon(
                  icon: PhosphorIconsFill.chatCircleText,
                  size: 22,
                ),
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
      child: GradientIcon(icon: PhosphorIcons.cameraPlus, size: 28),
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
          context.tr('payment.tap_to_upload'),
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('payment.or_take_photo'),
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

