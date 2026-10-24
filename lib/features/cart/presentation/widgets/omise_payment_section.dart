import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/media/image_bytes_saver.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../order/data/repositories/order_repository.dart';
import '../../data/active_order_state.dart';

class OmisePromptPaySession {
  final String? chargeId;
  final String? qrImageUrl;
  final Uint8List? qrBytes;
  final Uint8List? qrLogoBytes;
  final DateTime expiresAt;
  final String? authorizeUri;

  OmisePromptPaySession({
    this.chargeId,
    this.qrImageUrl,
    this.qrBytes,
    this.qrLogoBytes,
    required this.expiresAt,
    this.authorizeUri,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  OmisePromptPaySession copyWith({
    String? chargeId,
    String? qrImageUrl,
    Uint8List? qrBytes,
    Uint8List? qrLogoBytes,
    DateTime? expiresAt,
    String? authorizeUri,
  }) {
    return OmisePromptPaySession(
      chargeId: chargeId ?? this.chargeId,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
      qrBytes: qrBytes ?? this.qrBytes,
      qrLogoBytes: qrLogoBytes ?? this.qrLogoBytes,
      expiresAt: expiresAt ?? this.expiresAt,
      authorizeUri: authorizeUri ?? this.authorizeUri,
    );
  }
}

class OmisePaymentSection extends StatefulWidget {
  final ActiveOrderItem order;
  final int orderId;
  final String? initialMethod;
  final VoidCallback onPaymentCompleted;
  final VoidCallback? onFallbackToSlip;

  static final Map<int, OmisePromptPaySession> _sessionCache = {};

  static void clearSession(int orderId) {
    _sessionCache.remove(orderId);
  }

  static OmisePromptPaySession? getSession(int orderId) => _sessionCache[orderId];

  const OmisePaymentSection({
    super.key,
    required this.order,
    required this.orderId,
    this.initialMethod,
    required this.onPaymentCompleted,
    this.onFallbackToSlip,
  });

  @override
  State<OmisePaymentSection> createState() => _OmisePaymentSectionState();
}

class _OmisePaymentSectionState extends State<OmisePaymentSection>
    with SingleTickerProviderStateMixin {
  // Method: 'PROMPTPAY' or 'TRUEMONEY'
  String _selectedMethod = 'PROMPTPAY';
  bool _isLoading = false;
  bool _isCheckingStatus = false;
  String? _qrImageUrl;
  Uint8List? _qrBytes;
  Uint8List? _qrLogoBytes;
  bool _isLoadingQrImage = false;
  String? _authorizeUri;
  String? _errorMessage;
  bool _hasLaunchedTrueMoney = false;

  Timer? _pollTimer;
  Timer? _qrCountdownTimer;
  int _qrRemainingSeconds = 1200; // 20:00 minutes standard (matches 20-min backend timeout)

  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey _qrBoundaryKey = GlobalKey();

  late AnimationController _pulseAnimController;

  @override
  void initState() {
    super.initState();
    _selectedMethod = (widget.initialMethod == 'TRUEMONEY') ? 'TRUEMONEY' : 'PROMPTPAY';
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    if (_selectedMethod == 'PROMPTPAY') {
      final cached = OmisePaymentSection._sessionCache[widget.orderId];
      final orderExpiresAt = widget.order.omiseExpiresAt;

      if (cached != null && !cached.isExpired) {
        // 1. Instant restore from static memory cache (no reload, no spinner, continuous timer)
        _qrImageUrl = cached.qrImageUrl;
        _qrBytes = cached.qrBytes;
        _qrLogoBytes = cached.qrLogoBytes;
        _authorizeUri = cached.authorizeUri;
        _isLoading = false;
        _isLoadingQrImage = false;
        _startCountdown(cached.expiresAt);
        _startPolling();
        if (_qrBytes == null && _qrImageUrl != null) {
          _fetchAndProcessQrImage(_qrImageUrl);
        }
      } else if (orderExpiresAt != null &&
          orderExpiresAt.isAfter(DateTime.now()) &&
          (widget.order.omiseQrBytes != null || widget.order.omiseQrImageUrl != null)) {
        // 2. Restore from active order object
        _qrImageUrl = widget.order.omiseQrImageUrl;
        _qrBytes = widget.order.omiseQrBytes;
        _qrLogoBytes = widget.order.omiseQrLogoBytes;
        _authorizeUri = widget.order.omiseAuthorizeUri;
        _isLoading = false;
        _isLoadingQrImage = false;
        _startCountdown(orderExpiresAt);

        OmisePaymentSection._sessionCache[widget.orderId] = OmisePromptPaySession(
          chargeId: widget.order.omiseChargeId,
          qrImageUrl: _qrImageUrl,
          qrBytes: _qrBytes,
          qrLogoBytes: _qrLogoBytes,
          expiresAt: orderExpiresAt,
          authorizeUri: _authorizeUri,
        );

        _startPolling();
        if (_qrBytes == null && _qrImageUrl != null) {
          _fetchAndProcessQrImage(_qrImageUrl);
        }
      } else {
        // 3. Initiate payment when no valid unexpired session exists
        _initiatePayment(_selectedMethod);
        _startPolling();
      }
    } else {
      _initiatePayment(_selectedMethod);
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _qrCountdownTimer?.cancel();
    _pulseAnimController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startCountdown(DateTime expiresAt) {
    _qrCountdownTimer?.cancel();
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    // Cap session countdown to 20 minutes max (1200 seconds)
    final clampedDiff = (diff > 1200 || diff <= 0) ? 1200 : diff;
    _qrRemainingSeconds = clampedDiff;

    final targetEndTime = DateTime.now().add(Duration(seconds: clampedDiff));

    _qrCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final remaining = targetEndTime.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        setState(() => _qrRemainingSeconds = remaining);
      } else {
        setState(() => _qrRemainingSeconds = 0);
        timer.cancel();
      }
    });
  }

  String _t({required String en, required String mm, required String th}) {
    return LocaleController.instance.localized(en: en, mm: mm, th: th);
  }

  bool get _isVerifiedShop =>
      widget.order.isVerified ||
      ActiveOrderState.instance.isVerified ||
      (widget.order.paymentChannel?.toUpperCase() == 'OMISE');

  bool get _showFallbackToSlip =>
      widget.onFallbackToSlip != null && !_isVerifiedShop;

  String get _countdownDisplay {
    if (_qrRemainingSeconds <= 0) return _t(en: 'Expired', mm: 'သက်တမ်းကုန်ပါပြီ', th: 'หมดอายุแล้ว');
    final minutes = (_qrRemainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_qrRemainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollStatusSilent();
    });
  }

  Future<void> _initiatePayment(String method, {bool forceNew = false}) async {
    if (!mounted) return;

    if (widget.orderId <= 0) {
      setState(() {
        _errorMessage = 'Invalid order ID. Please refresh and try again.';
        _isLoading = false;
      });
      return;
    }

    final payableTotal = widget.order.totalAmount ?? 0.0;
    if (payableTotal > 0 && payableTotal < 20.0) {
      setState(() {
        _selectedMethod = method;
        _errorMessage =
            'ငွေပေးချေမှုပမာဏသည် ฿20 အောက်ဖြစ်ပါသဖြင့် PromptPay / TrueMoney ဖြင့် ပေးချေ၍ မရပါ။ ဘဏ်စလစ်ဖြင့် ပေးချေပေးပါရန်။\n(Order total must be at least ฿20 to pay via Omise)';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _selectedMethod = method;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = method == 'TRUEMONEY' ? _phoneController.text.trim() : null;
      if (method == 'TRUEMONEY' && (phone == null || phone.isEmpty)) {
        setState(() {
          _errorMessage = 'Please enter your TrueMoney phone number.';
          _isLoading = false;
        });
        return;
      }

      final data = await OrderRepository().initiateOmisePayment(
        widget.orderId,
        method: method,
        phoneNumber: phone,
        forceNew: forceNew,
      );

      if (!mounted) return;
      if (data != null) {
        final rawExpiresAt = data['expiresAt']?.toString();
        DateTime expiresAt;
        if (rawExpiresAt != null && rawExpiresAt.isNotEmpty) {
          expiresAt = DateTime.tryParse(rawExpiresAt)?.toLocal() ??
              DateTime.now().add(const Duration(minutes: 20));
        } else {
          expiresAt = DateTime.now().add(const Duration(minutes: 20));
        }

        final qrUrl = data['qrImageUrl']?.toString();
        final authUri = data['authorizeUri']?.toString();
        final chargeId = data['chargeId']?.toString();

        setState(() {
          _qrImageUrl = qrUrl;
          _authorizeUri = authUri;
          _isLoading = false;
        });

        if (method == 'PROMPTPAY') {
          _startCountdown(expiresAt);

          OmisePaymentSection._sessionCache[widget.orderId] = OmisePromptPaySession(
            chargeId: chargeId,
            qrImageUrl: qrUrl,
            qrBytes: _qrBytes,
            qrLogoBytes: _qrLogoBytes,
            expiresAt: expiresAt,
            authorizeUri: authUri,
          );

          widget.order.omiseExpiresAt = expiresAt;
          widget.order.omiseQrImageUrl = qrUrl;
          widget.order.omiseChargeId = chargeId;
          widget.order.omiseAuthorizeUri = authUri;

          _fetchAndProcessQrImage(qrUrl);
        }

        if (method == 'TRUEMONEY' && _authorizeUri != null) {
          await _launchTrueMoneyUri();
        }
      } else {
        setState(() {
          _errorMessage = 'Could not generate payment. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is DioException && e.response?.data?['message'] != null
            ? e.response!.data['message'].toString()
            : 'Payment initialization failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAndProcessQrImage(String? url) async {
    String? targetUrl = url;
    if (targetUrl == null || targetUrl.isEmpty) {
      targetUrl = widget.order.shopPaymentQrUrl ?? widget.order.paymentMethodImageUrl;
    }
    if (targetUrl == null || targetUrl.isEmpty) {
      if (mounted) setState(() => _isLoadingQrImage = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingQrImage = true);

    try {
      // 1. Fetch raw text content to check for Omise SVG
      final response = await Dio().get<dynamic>(
        targetUrl,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final rawContent = response.data?.toString() ?? '';

      if (rawContent.contains('<svg') || rawContent.contains('<?xml')) {
        final matches = RegExp(r"""data:image/(?:png|jpeg|jpg);base64,([^"'\s>]+)""")
            .allMatches(rawContent);

        Uint8List? qrBytes;
        Uint8List? logoBytes;

        for (final m in matches) {
          final b64String = m.group(1)!
              .replaceAll('&#43;', '+')
              .replaceAll('&amp;', '&')
              .replaceAll(RegExp(r'\s+'), '');
          final pad = b64String.length % 4;
          final cleanB64 = pad > 0 ? b64String + ('=' * (4 - pad)) : b64String;
          final decoded = base64Decode(cleanB64);

          // Omise PromptPay SVG format:
          // - 360x360 1-bit QR code PNG is < 2000 bytes
          // - PromptPay central bird logo PNG is between 2000 and 20000 bytes
          if (decoded.length < 2000) {
            qrBytes = decoded;
          } else if (decoded.length >= 2000 && decoded.length < 20000) {
            logoBytes = decoded;
          }
        }

        if (qrBytes != null) {
          if (!mounted) return;
          setState(() {
            _qrBytes = qrBytes;
            _qrLogoBytes = logoBytes;
            _isLoadingQrImage = false;
          });
          final existing = OmisePaymentSection._sessionCache[widget.orderId];
          if (existing != null) {
            OmisePaymentSection._sessionCache[widget.orderId] = existing.copyWith(
              qrBytes: qrBytes,
              qrLogoBytes: logoBytes,
            );
          }
          widget.order.omiseQrBytes = qrBytes;
          widget.order.omiseQrLogoBytes = logoBytes;
          return;
        }
      }

      // 2. Direct binary bytes (if already PNG/JPEG)
      final bytesResponse = await Dio().get<List<int>>(
        targetUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (bytesResponse.data != null && bytesResponse.data!.isNotEmpty) {
        if (!mounted) return;
        final directBytes = Uint8List.fromList(bytesResponse.data!);
        setState(() {
          _qrBytes = directBytes;
          _qrLogoBytes = null;
          _isLoadingQrImage = false;
        });
        final existing = OmisePaymentSection._sessionCache[widget.orderId];
        if (existing != null) {
          OmisePaymentSection._sessionCache[widget.orderId] = existing.copyWith(
            qrBytes: directBytes,
            qrLogoBytes: null,
          );
        }
        widget.order.omiseQrBytes = directBytes;
        widget.order.omiseQrLogoBytes = null;
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading QR image: $e');
    }

    // 3. Fallback to order's shop payment QR URL if primary failed
    final fallback = widget.order.shopPaymentQrUrl ?? widget.order.paymentMethodImageUrl;
    if (fallback != null && fallback != targetUrl) {
      try {
        final res = await Dio().get<List<int>>(
          fallback,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null && res.data!.isNotEmpty) {
          if (!mounted) return;
          final fallbackBytes = Uint8List.fromList(res.data!);
          setState(() {
            _qrBytes = fallbackBytes;
            _qrLogoBytes = null;
            _isLoadingQrImage = false;
          });
          final existing = OmisePaymentSection._sessionCache[widget.orderId];
          if (existing != null) {
            OmisePaymentSection._sessionCache[widget.orderId] = existing.copyWith(
              qrBytes: fallbackBytes,
              qrLogoBytes: null,
            );
          }
          widget.order.omiseQrBytes = fallbackBytes;
          widget.order.omiseQrLogoBytes = null;
          return;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isLoadingQrImage = false);
  }

  Future<void> _pollStatusSilent() async {
    if (!mounted || widget.orderId <= 0) return;
    try {
      final data = await OrderRepository().getOmisePaymentStatus(widget.orderId);
      if (!mounted) return;
      if (data != null) {
        final orderStatus = data['orderStatus']?.toString().toUpperCase();
        final payment = data['payment'];
        final paymentStatus = payment != null
            ? payment['status']?.toString().toUpperCase()
            : null;

        if (orderStatus == 'PAYMENT_VERIFIED' ||
            paymentStatus == 'SUCCESSFUL' ||
            orderStatus == 'COOKING' ||
            orderStatus == 'READY_FOR_PICKUP' ||
            orderStatus == 'ON_THE_WAY') {
          _pollTimer?.cancel();
          _qrCountdownTimer?.cancel();
          OmisePaymentSection.clearSession(widget.orderId);
          widget.onPaymentCompleted();
        }
      }
    } catch (_) {}
  }

  Future<void> _manualCheckStatus() async {
    if (_isCheckingStatus || !mounted || widget.orderId <= 0) return;
    setState(() => _isCheckingStatus = true);
    try {
      final data = await OrderRepository().getOmisePaymentStatus(widget.orderId);
      if (!mounted) return;
      if (data != null) {
        final orderStatus = data['orderStatus']?.toString().toUpperCase();
        final payment = data['payment'];
        final paymentStatus = payment != null
            ? payment['status']?.toString().toUpperCase()
            : null;

        if (orderStatus == 'PAYMENT_VERIFIED' ||
            paymentStatus == 'SUCCESSFUL' ||
            orderStatus == 'COOKING' ||
            orderStatus == 'READY_FOR_PICKUP' ||
            orderStatus == 'ON_THE_WAY') {
          _pollTimer?.cancel();
          _qrCountdownTimer?.cancel();
          OmisePaymentSection.clearSession(widget.orderId);
          if (mounted) {
            AppDialog.showToast(context, 'Payment confirmed! ✓');
            widget.onPaymentCompleted();
          }
          return;
        }
      }
      if (mounted) {
        AppDialog.showToast(context, 'Waiting for payment confirmation...');
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showToast(context, 'Could not check status', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _launchTrueMoneyUri() async {
    if (_authorizeUri == null) {
      _handleTrueMoneyPay();
      return;
    }
    final uri = Uri.parse(_authorizeUri!);
    setState(() => _hasLaunchedTrueMoney = true);
    try {
      bool launched = false;
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!launched && mounted) {
        AppDialog.showToast(context, 'Cannot open TrueMoney wallet link', isError: true);
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showToast(context, 'Error opening wallet', isError: true);
      }
    }
  }

  void _handleTrueMoneyPay() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      AppDialog.showToast(
        context,
        _t(
          en: 'Please enter your 10-digit TrueMoney phone number',
          mm: 'TrueMoney ဖုန်းနံပါတ် (၁၀ လုံး) ရိုက်ထည့်ပေးပါ',
          th: 'กรุณากรอกเบอร์ TrueMoney 10 หลัก',
        ),
        isError: true,
      );
      return;
    }
    if (phone.length < 9) {
      AppDialog.showToast(
        context,
        _t(
          en: 'Please enter a valid phone number (e.g. 08xxxxxxxx)',
          mm: 'မှန်ကန်သော ဖုန်းနံပါတ် ရိုက်ထည့်ပေးပါ (ဥပမာ- 08xxxxxxxx)',
          th: 'กรุณากรอกเบอร์โทรศัพท์ที่ถูกต้อง (เช่น 08xxxxxxxx)',
        ),
        isError: true,
      );
      return;
    }
    _initiatePayment('TRUEMONEY');
  }

  Future<void> _saveQrImage({bool silent = false}) async {
    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      Uint8List? pngBytes;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          pngBytes = byteData.buffer.asUint8List();
        }
      }

      pngBytes ??= _qrBytes;

      if (pngBytes != null) {
        await saveImageBytes(
          pngBytes,
          name: 'promptpay_qr_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        if (mounted) {
          if (!silent) {
            AppDialog.showToast(
              context,
              _t(
                en: 'QR Code saved to Photos 📸',
                mm: 'QR ပုံကို Photos ထဲ သိမ်းဆည်းပြီးပါပြီ 📸✨',
                th: 'บันทึก QR ลงแกลเลอรีแล้ว 📸',
              ),
            );
          }
        }
        return;
      }

      if (_qrImageUrl != null) {
        final res = await Dio().get<List<int>>(
          _qrImageUrl!,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null) {
          await saveImageBytes(
            Uint8List.fromList(res.data!),
            name: 'promptpay_qr_${widget.orderId}.png',
          );
          if (mounted) {
            if (!silent) {
              AppDialog.showToast(
                context,
                _t(
                  en: 'QR Code saved to Photos 📸',
                  mm: 'QR ပုံကို Photos ထဲ သိမ်းဆည်းပြီးပါပြီ 📸✨',
                  th: 'บันทึก QR ลงแกลเลอรีแล้ว 📸',
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        AppDialog.showToast(
          context,
          _t(
            en: 'Failed to save QR code',
            mm: 'QR ပုံသိမ်းဆည်း၍ မရပါ',
            th: 'บันทึก QR ไม่สำเร็จ',
          ),
          isError: true,
        );
      }
    }
  }

  Future<void> _launchBankApp(String scheme, String bankName) async {
    final uri = Uri.parse(scheme);
    bool launched = false;
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // Fallback: try launching directly if canLaunchUrl returned false due to queries/visibility restrictions
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    if (!launched && mounted) {
      AppDialog.showToast(
        context,
        _t(
          en: 'Please open $bankName from home screen to scan the saved QR.',
          mm: 'သိမ်းဆည်းထားသော QR ဖြင့် ပေးချေရန် $bankName App ကိုဖွင့်ပါ',
          th: 'กรุณาเปิดแอป $bankName เพื่อสแกน QR ที่บันทึกไว้',
        ),
      );
    }
  }

  Future<void> _saveAndLaunchBankApp(String scheme, String bankName) async {
    await _saveQrImage(silent: true);
    if (mounted) {
      AppDialog.showToast(
        context,
        _t(
          en: 'QR code saved! Opening $bankName...',
          mm: 'QR သိမ်းဆည်းပြီးပါပြီ! $bankName ဖွင့်နေပါသည်... 🚀',
          th: 'บันทึก QR แล้ว! กำลังเปิด $bankName...',
        ),
      );
    }
    await _launchBankApp(scheme, bankName);
  }



  @override
  Widget build(BuildContext context) {
    final double payableTotal = widget.order.totalAmount ?? 0.0;

    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Grab Total Amount & Live Status Hero Card ──
                    _buildAmountHeroCard(payableTotal),
                    const SizedBox(height: 12),

                    // ── Compact Horizontal Pill Switcher ──
                    _buildMethodPillSwitcher(),
                    const SizedBox(height: 14),

                    // ── Main Payment View ──
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CustomLoadingIndicator(size: 36)),
                      )
                    else if (_errorMessage != null)
                      _buildErrorView()
                    else if (_selectedMethod == 'PROMPTPAY')
                      _buildPromptPayView(payableTotal)
                    else
                      _buildTrueMoneyView(payableTotal),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Grab Sticky Floating Bottom Action Bar ──
            if (_errorMessage == null && !_isLoading)
              _buildStickyBottomBar(payableTotal),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GRAB TOTAL AMOUNT & LIVE STATUS HERO CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildAmountHeroCard(double payableTotal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: Text(
                  '฿ ${payableTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          Builder(
            builder: (context) {
              final isExpired = _qrRemainingSeconds <= 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: isExpired ? null : AppColors.primaryGradient,
                  color: isExpired ? const Color(0xFFFEF2F2) : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isExpired
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                  border: isExpired
                      ? Border.all(color: const Color(0xFFFCA5A5), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpired
                          ? PhosphorIconsRegular.timer
                          : PhosphorIconsRegular.clockCountdown,
                      size: 13,
                      color: isExpired ? const Color(0xFFDC2626) : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _countdownDisplay,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isExpired ? const Color(0xFFDC2626) : Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COMPACT HORIZONTAL PILL SWITCHER (GRAB STYLE)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMethodPillSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPillItem(
              method: 'PROMPTPAY',
              title: 'PromptPay',
              icon: PhosphorIconsFill.qrCode,
              assetLogo: 'assets/images/banks/PromptPay.png',
              activeColor: const Color(0xFF003D6B),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildPillItem(
              method: 'TRUEMONEY',
              title: 'TrueMoney',
              icon: PhosphorIconsFill.wallet,
              assetLogo: 'assets/images/banks/TrueMoney.png',
              activeColor: const Color(0xFFFF8200),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillItem({
    required String method,
    required String title,
    required IconData icon,
    required Color activeColor,
    String? assetLogo,
    String? badgeText,
  }) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () {
        if (_selectedMethod != method) {
          setState(() {
            _selectedMethod = method;
            _errorMessage = null;
          });
          if (method == 'PROMPTPAY') {
            final cached = OmisePaymentSection._sessionCache[widget.orderId];
            if (cached != null && !cached.isExpired && cached.qrBytes != null) {
              setState(() {
                _qrBytes = cached.qrBytes;
                _qrLogoBytes = cached.qrLogoBytes;
                _qrImageUrl = cached.qrImageUrl;
                _authorizeUri = cached.authorizeUri;
              });
              _startCountdown(cached.expiresAt);
            } else if (_qrBytes == null) {
              _initiatePayment('PROMPTPAY');
            }
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (assetLogo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(
                  assetLogo,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    icon,
                    size: 15,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              )
            else
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            const SizedBox(width: 5),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: isSelected ? activeColor : Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  // ─────────────────────────────────────────────────────────────
  // 1. PROMPTPAY VIEW (TICKET VOUCHER STYLE)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPromptPayView(double payableTotal) {
    return Column(
      children: [
        // Ticket-Style PromptPay QR Voucher
        RepaintBoundary(
          key: _qrBoundaryKey,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF003D6B).withValues(alpha: 0.2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF003D6B).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Thai QR Official Navy Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: const BoxDecoration(
                    color: Color(0xFF003D6B),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(17),
                      topRight: Radius.circular(17),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          PhosphorIconsFill.qrCode,
                          size: 16,
                          color: Color(0xFF003D6B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THAI QR PAYMENT',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'พร้อมเพย์ • PromptPay',
                            style: GoogleFonts.notoSansThai(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Center QR Code Canvas
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: (_isLoadingQrImage && _qrBytes == null)
                      ? Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CustomLoadingIndicator(size: 32),
                                const SizedBox(height: 10),
                                Text(
                                  _t(
                                    en: 'Generating PromptPay QR...',
                                    mm: 'PromptPay QR ဖန်တီးနေပါသည်...',
                                    th: 'กำลังสร้าง PromptPay QR...',
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _qrRemainingSeconds <= 0
                          ? Container(
                              width: 220,
                              height: 220,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFEE2E2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      PhosphorIconsRegular.clockAfternoon,
                                      color: Color(0xFFDC2626),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _t(
                                      en: 'QR Code Expired',
                                      mm: 'QR အချိန်ပြည့်သွားပါပြီ ⏰',
                                      th: 'QR Code หมดอายุแล้ว',
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _t(
                                      en: 'This QR has reached its time limit. Tap below to refresh.',
                                      mm: 'QR သက်တမ်း ကုန်သွားပါပြီ။ အသစ်ပြန်ထုတ်ပြီး ဆက်ရှင်းလို့ရပါတယ်နော် ✨',
                                      th: 'QR นี้หมดเวลาแล้ว แตะด้านล่างเพื่อโหลดใหม่',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      color: const Color(0xFF7F1D1D),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () {
                                      OmisePaymentSection.clearSession(widget.orderId);
                                      _initiatePayment('PROMPTPAY', forceNew: true);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            PhosphorIconsRegular.arrowClockwise,
                                            color: Colors.white,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _t(
                                              en: 'Generate New QR',
                                              mm: 'QR အသစ်ပြန်ထုတ်မယ် 🔄',
                                              th: 'สร้าง QR ใหม่',
                                            ),
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _qrBytes != null
                          ? Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.memory(
                                      _qrBytes!,
                                      width: 210,
                                      height: 210,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.none,
                                    ),
                                  ),
                                  if (_qrLogoBytes != null)
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 3,
                                          ),
                                        ],
                                      ),
                                      child: Image.memory(
                                        _qrLogoBytes!,
                                        width: 32,
                                        height: 24,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(PhosphorIconsRegular.warningCircle, color: Colors.amber, size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                    _t(
                                      en: 'QR code loading...',
                                      mm: 'QR ကုဒ် ဖွင့်နေပါသည်...',
                                      th: 'กำลังโหลด QR...',
                                    ),
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () => _fetchAndProcessQrImage(_qrImageUrl),
                                    icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 14),
                                    label: Text(
                                      _t(
                                        en: 'Reload QR',
                                        mm: 'QR ပြန်ဖွင့်မည်',
                                        th: 'โหลด QR ใหม่',
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Quick Bank Launchers (1-Tap Auto-Save + App Launch)
        _buildBankLaunchersSection(),
        const SizedBox(height: 14),

        // 3-Step Instruction Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    PhosphorIconsFill.info,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _t(
                      en: 'How to pay with PromptPay:',
                      mm: 'PromptPay နဲ့ လွယ်လွယ်လေး ရှင်းမယ် ✨',
                      th: 'วิธีชำระเงินด้วย PromptPay:',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStepRow(
                '1',
                _t(
                  en: 'Tap "Save QR to Photos" or tap your bank app above.',
                  mm: '"QR ပုံသိမ်းမည်" နှိပ်ပြီး ပုံသိမ်းပါ (ဒါမှမဟုတ် အပေါ်က ဘော်ဒါရဲ့ ဘဏ် App လေးကို တိုက်ရိုက်နှိပ်ပါ) 📲',
                  th: 'แตะ "บันทึก QR ลงเครื่อง" หรือแตะเปิดแอปธนาคารด้านบน',
                ),
              ),
              const SizedBox(height: 10),
              _buildStepRow(
                '2',
                _t(
                  en: 'Open your bank app (K+, SCB, Krungthai, Bualuang, etc.).',
                  mm: 'ဘော်ဒါ သုံးနေကျ ဘဏ် App (K+, SCB, Krungthai စတဲ့ ကြိုက်တဲ့ဘဏ်) ထဲ ဝင်လိုက်ပါ 🏦',
                  th: 'เปิดแอปธนาคารของคุณ (K+, SCB, Krungthai, Bualuang ฯลฯ)',
                ),
              ),
              const SizedBox(height: 10),
              _buildStepRow(
                '3',
                _t(
                  en: 'Select "Scan QR" > choose from Photos to pay. Verifies automatically!',
                  mm: '"Scan QR" ထဲကနေ သိမ်းထားတဲ့ QR ပုံလေးရွေးပြီး ငွေရှင်းလိုက်ပါ! အလိုအလျောက် ချက်ချင်း အတည်ပြုပေးပါမယ် 🎉',
                  th: 'เลือก "สแกน QR" > เลือกรูปจากแกลเลอรีเพื่อชำระเงิน ตรวจสอบอัตโนมัติ!',
                ),
              ),
            ],
          ),
        ),

        if (_showFallbackToSlip) ...[
          const SizedBox(height: 14),
          Center(
            child: InkWell(
              onTap: widget.onFallbackToSlip,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsRegular.receipt, size: 15, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      _t(
                        en: 'Having trouble? Pay with Bank Slip transfer',
                        mm: 'ဘဏ်စလစ် တိုက်ရိုက်လွှဲပြီး ပေးချေချင်ပါသလား? 🧾',
                        th: 'ต้องการโอนเงินและแนบสลิปธนาคาร?',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GRAB STICKY FLOATING BOTTOM ACTION BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildStickyBottomBar(double payableTotal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _selectedMethod == 'PROMPTPAY'
            ? Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _qrRemainingSeconds <= 0
                              ? null
                              : AppColors.primaryGradient,
                          color: _qrRemainingSeconds <= 0
                              ? const Color(0xFFDC2626)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _qrRemainingSeconds <= 0
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _qrRemainingSeconds <= 0
                              ? () {
                                  OmisePaymentSection.clearSession(widget.orderId);
                                  _initiatePayment('PROMPTPAY', forceNew: true);
                                }
                              : _saveQrImage,
                          icon: Icon(
                            _qrRemainingSeconds <= 0
                                ? PhosphorIconsRegular.arrowClockwise
                                : PhosphorIconsRegular.downloadSimple,
                            size: 17,
                            color: Colors.white,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _qrRemainingSeconds <= 0
                                  ? _t(en: 'Refresh QR', mm: 'QR အသစ်ပြန်ဖွင့်မယ်', th: 'โหลด QR ใหม่')
                                  : _t(en: 'Save QR to Photos', mm: 'QR ပုံသိမ်းမယ်', th: 'บันทึก QR ลงเครื่อง'),
                              maxLines: 1,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isCheckingStatus ? null : _manualCheckStatus,
                        icon: _isCheckingStatus
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(
                                PhosphorIconsBold.checkCircle,
                                size: 16,
                                color: AppColors.primary,
                              ),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isCheckingStatus
                                ? _t(en: 'Checking...', mm: 'စစ်ဆေးနေဆဲ...', th: 'กำลังตรวจสอบ...')
                                : _t(en: 'I Have Paid', mm: 'ငွေရှင်းပြီးပြီ', th: 'ชำระเงินแล้ว'),
                            maxLines: 1,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.25), width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : (_hasLaunchedTrueMoney && _authorizeUri != null)
                ? Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8200), Color(0xFFFF5000)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8200).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _launchTrueMoneyUri,
                              icon: const Icon(PhosphorIconsBold.arrowSquareOut, color: Colors.white, size: 16),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _t(en: 'Re-open TrueMoney', mm: 'TrueMoney ပြန်ဖွင့်မယ်', th: 'เปิด TrueMoney อีกครั้ง'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isCheckingStatus ? null : _manualCheckStatus,
                            icon: _isCheckingStatus
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8200)),
                                  )
                                : const Icon(PhosphorIconsRegular.arrowsClockwise, size: 16, color: Color(0xFFFF8200)),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _isCheckingStatus
                                    ? _t(en: 'Checking...', mm: 'စစ်ဆေးနေပါသည်...', th: 'กำลังตรวจสอบ...')
                                    : _t(en: 'Check Status', mm: 'အခြေအနေစစ်မယ်', th: 'เช็คสถานะ'),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFF8200),
                                ),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF7ED),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              side: const BorderSide(color: Color(0xFFFF8200), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8200), Color(0xFFFF5000)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8200).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleTrueMoneyPay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const Center(
                                child: CustomLoadingIndicator(size: 20, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.asset(
                                      'assets/images/banks/TrueMoney.png',
                                      width: 20,
                                      height: 20,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_t(en: 'Pay with TrueMoney', mm: 'TrueMoney ဖြင့် ပေးချေမည်', th: 'ชำระด้วย TrueMoney')} ฿${payableTotal.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. TRUEMONEY VIEW (WALLET)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTrueMoneyView(double payableTotal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TrueMoney Header with official branding
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF8200).withValues(alpha: 0.3), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8200).withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/images/banks/TrueMoney.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      PhosphorIconsFill.wallet,
                      color: Color(0xFFFF8200),
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'TrueMoney Wallet',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8200),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'DIRECT APP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _t(
                        en: 'Official Direct E-Wallet Payment',
                        mm: 'TrueMoney Wallet တိုက်ရိုက် ငွေပေးချေမှုစနစ်',
                        th: 'ชำระเงินโดยตรงผ่าน TrueMoney Wallet',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Amount Card with TrueMoney vibe
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        en: 'TOTAL TO PAY',
                        mm: 'ပေးချေရမည့် ငွေပမာဏ',
                        th: 'ยอดเงินที่ต้องชำระ',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC2410C),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '฿ ${payableTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD8A8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIconsFill.shieldCheck, color: Color(0xFFEA580C), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Instant Auth',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFC2410C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // TrueMoney Mobile Number Input
          Text(
            _t(
              en: 'TrueMoney Registered Mobile (10 digits)',
              mm: 'TrueMoney အကောင့်ဖွင့်ထားသော ဖုန်းနံပါတ် (၁၀ လုံး)',
              th: 'เบอร์โทรศัพท์ที่ลงทะเบียน TrueMoney (10 หลัก)',
            ),
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              hintText: '08xxxxxxxx',
              counterText: '',
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇹🇭', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      '+66',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(height: 18, width: 1, color: const Color(0xFFCBD5E1)),
                  ],
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF8200), width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3-Step Guide for TrueMoney Payment
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(PhosphorIconsFill.info, size: 14, color: Color(0xFFFF8200)),
                    const SizedBox(width: 6),
                    Text(
                      _t(
                        en: 'How to pay with TrueMoney:',
                        mm: 'TrueMoney ဖြင့် ပေးချေနည်း လမ်းညွှန် ✨',
                        th: 'วิธีชำระด้วย TrueMoney:',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildStepRow(
                  '1',
                  _t(
                    en: 'Enter your 10-digit TrueMoney number & tap Pay below.',
                    mm: 'TrueMoney ဖုန်းနံပါတ် ရိုက်ပြီး အောက်ခြေရှိ "TrueMoney ဖြင့် ပေးချေမည်" ကို နှိပ်ပါ 📲',
                    th: 'กรอกเบอร์ TrueMoney 10 หลัก แล้วแตะชำระเงินด้านล่าง',
                  ),
                ),
                const SizedBox(height: 8),
                _buildStepRow(
                  '2',
                  _t(
                    en: 'TrueMoney App opens automatically. Verify with OTP/PIN.',
                    mm: 'TrueMoney Wallet App အလိုအလျောက် ပွင့်လာပါက OTP / PIN ရိုက်၍ အတည်ပြုပေးပါ 🔐',
                    th: 'แอป TrueMoney จะเปิดขึ้นมาอัตโนมัติ ยืนยันด้วย OTP/PIN',
                  ),
                ),
                const SizedBox(height: 8),
                _buildStepRow(
                  '3',
                  _t(
                    en: 'Return to Together app. Payment verifies instantly!',
                    mm: 'ငွေရှင်းပြီးသည်နှင့် MyTogether App ထဲတွင် အော်ဒါချက်ချင်း အတည်ပြုပြီးသား ဖြစ်သွားပါမည် 🎉',
                    th: 'กลับมาที่แอป Together ระบบจะยืนยันการชำระเงินทันที!',
                  ),
                ),
              ],
            ),
          ),

          if (_hasLaunchedTrueMoney) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                children: [
                  const CustomLoadingIndicator(size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _t(
                        en: 'Authorizing in TrueMoney... Return here once approved.',
                        mm: 'TrueMoney ထဲတွင် အတည်ပြုနေပါသည်... အတည်ပြုပြီးပါက ဤနေရာသို့ ပြန်လာပေးပါနော် ✨',
                        th: 'กำลังรอการอนุมัติใน TrueMoney... กรุณากลับมาที่นี่เมื่อเสร็จสิ้น',
                      ),
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF9A3412), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

        if (_showFallbackToSlip) ...[
          const SizedBox(height: 14),
          Center(
            child: InkWell(
              onTap: widget.onFallbackToSlip,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsRegular.receipt, size: 15, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'ဘဏ်စလစ်ဖြင့် ပေးချေလိုပါသလား?',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ),
    );
  }



  // ─────────────────────────────────────────────────────────────
  // 4. ERROR VIEW WITH AUTO-FALLBACK
  // ─────────────────────────────────────────────────────────────
  Widget _buildErrorView() {
    final bool isDirectPaymentUnavailable = _errorMessage != null &&
        (_errorMessage!.toLowerCase().contains('does not use omise') ||
            _errorMessage!.toLowerCase().contains('direct payment') ||
            _errorMessage!.toLowerCase().contains('not configured'));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFEE2E2), width: 2),
          ),
          child: const Center(
            child: Icon(
              PhosphorIconsFill.warningCircle,
              color: Color(0xFFEF4444),
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isDirectPaymentUnavailable
              ? 'တိုက်ရိုက်ငွေပေးချေမှု မရရှိနိုင်သေးပါ'
              : 'ငွေပေးချေမှု မအောင်မြင်ပါ',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            isDirectPaymentUnavailable
                ? 'ဤအော်ဒါအတွက် တိုက်ရိုက်ငွေပေးချေမှု မရရှိသေးပါသဖြင့် ဘဏ်အကောင့်သို့ လွှဲပြောင်းပြီး စလစ်တင်၍ ဆက်လက်ပေးချေနိုင်ပါသည်။'
                : (_errorMessage ?? 'Payment initialization failed. Please try again.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_showFallbackToSlip) ...[
          SizedBox(
            width: double.infinity,
            child: PrimaryGradientButton(
              height: 48,
              onPressed: widget.onFallbackToSlip,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsBold.receipt, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ဘဏ်စလစ်ဖြင့် ပေးချေမည် (Pay with Slip)',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  if (_selectedMethod == 'TRUEMONEY' &&
                      _phoneController.text.trim().isEmpty) {
                    setState(() => _errorMessage = null);
                  } else {
                    _initiatePayment(_selectedMethod);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Try Again',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _errorMessage = null);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    );
  }

  static const List<_ThaiBankApp> _supportedThaiBanks = [
    _ThaiBankApp(
      name: 'K PLUS',
      shortName: 'K PLUS',
      iconSymbol: 'KBANK',
      brandColor: Color(0xFF00A950),
      scheme: 'kplus://',
    ),
    _ThaiBankApp(
      name: 'SCB EASY',
      shortName: 'SCB EASY',
      iconSymbol: 'SCB',
      brandColor: Color(0xFF4E2A84),
      scheme: 'scbeasy://',
    ),
    _ThaiBankApp(
      name: 'Krungthai NEXT',
      shortName: 'Krungthai',
      iconSymbol: 'KTB',
      brandColor: Color(0xFF1BA6E5),
      scheme: 'ktbnext://',
    ),
    _ThaiBankApp(
      name: 'Bualuang mBanking',
      shortName: 'Bangkok Bank',
      iconSymbol: 'BBL',
      brandColor: Color(0xFF1E3A8A),
      scheme: 'bualuangmbanking://',
    ),
    _ThaiBankApp(
      name: 'Krungsri KMA',
      shortName: 'Krungsri',
      iconSymbol: 'BAY',
      brandColor: Color(0xFFFEC400),
      scheme: 'kma://',
    ),
    _ThaiBankApp(
      name: 'ttb touch',
      shortName: 'ttb touch',
      iconSymbol: 'TTB',
      brandColor: Color(0xFF002D62),
      scheme: 'ttbtouch://',
    ),
    _ThaiBankApp(
      name: 'GSB MyMo',
      shortName: 'MyMo GSB',
      iconSymbol: 'GSB',
      brandColor: Color(0xFFEB008B),
      scheme: 'mymo://',
    ),
    _ThaiBankApp(
      name: 'GHB ALL',
      shortName: 'GHB ALL',
      iconSymbol: 'GHB',
      brandColor: Color(0xFFF37021),
      scheme: 'ghball://',
    ),
    _ThaiBankApp(
      name: 'UOB TMRW',
      shortName: 'UOB TMRW',
      iconSymbol: 'UOB',
      brandColor: Color(0xFF0B3979),
      scheme: 'uobtmrw://',
    ),
    _ThaiBankApp(
      name: 'KKP Mobile',
      shortName: 'KKP Mobile',
      iconSymbol: 'KKP',
      brandColor: Color(0xFF642878),
      scheme: 'kkpmobile://',
    ),
    _ThaiBankApp(
      name: 'CIMB THAI',
      shortName: 'CIMB THAI',
      iconSymbol: 'CIMB',
      brandColor: Color(0xFF7D0000),
      scheme: 'cimbthai://',
    ),
    _ThaiBankApp(
      name: 'BAAC Mobile',
      shortName: 'BAAC',
      iconSymbol: 'BAAC',
      brandColor: Color(0xFF4B9B1D),
      scheme: 'baacmobile://',
    ),
    _ThaiBankApp(
      name: 'TrueMoney Wallet',
      shortName: 'TrueMoney',
      iconSymbol: 'TrueMoney',
      brandColor: Color(0xFFFF8200),
      scheme: 'truemoney://',
    ),
    _ThaiBankApp(
      name: 'TISCO My Car',
      shortName: 'TISCO',
      iconSymbol: 'TISCO',
      brandColor: Color(0xFF12549F),
      scheme: 'tisco://',
    ),
    _ThaiBankApp(
      name: 'LHB You',
      shortName: 'LHB You',
      iconSymbol: 'LHB',
      brandColor: Color(0xFF6D6E71),
      scheme: 'lhbyou://',
    ),
  ];

  Widget _buildBankLaunchersSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsRegular.bank, size: 14, color: Color(0xFF475569)),
              const SizedBox(width: 6),
              Text(
                _t(en: 'Open Bank App to Pay', mm: 'ဘဏ် App ဖွင့်ပြီး ပေးချေမယ်', th: 'เปิดแอปธนาคารเพื่อชำระเงิน'),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _t(en: 'Swipe for more', mm: 'ဘေးသို့ဆွဲပါ', th: 'เลื่อนดูเพิ่มเติม'),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(PhosphorIconsBold.caretRight, size: 10, color: Color(0xFF94A3B8)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < _supportedThaiBanks.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _buildBankTileItem(_supportedThaiBanks[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankLogo(_ThaiBankApp bank) {
    const double iconSize = 30.0;
    final cdnUrl =
        'https://cdn.jsdelivr.net/gh/casperstack/thai-banks-logo@master/icons/${bank.iconSymbol}.png';
    final localAsset = 'assets/images/banks/${bank.iconSymbol}.png';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: cdnUrl,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: bank.brandColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              bank.shortName.substring(0, 1),
              style: TextStyle(
                color: bank.brandColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Image.asset(
          localAsset,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: bank.brandColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                bank.shortName.substring(0, 1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankTileItem(_ThaiBankApp bank) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _saveAndLaunchBankApp(bank.scheme, bank.name),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: bank.brandColor.withValues(alpha: 0.22),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: bank.brandColor.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBankLogo(bank),
              const SizedBox(height: 6),
              Text(
                bank.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 3, right: 10),
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: const Color(0xFF334155),
              height: 1.68,
              letterSpacing: 0.25,
            ),
          ),
        ),
      ],
    );
  }
}



class _ThaiBankApp {
  final String name;
  final String shortName;
  final String iconSymbol;
  final Color brandColor;
  final String scheme;

  const _ThaiBankApp({
    required this.name,
    required this.shortName,
    required this.iconSymbol,
    required this.brandColor,
    required this.scheme,
  });
}
