import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import '../../data/models/currency_rate_model.dart';
import '../../data/repositories/currency_exchange_repository.dart';

class CurrencyDetailPage extends StatefulWidget {
  final CurrencyRateModel currencyRate;

  const CurrencyDetailPage({super.key, required this.currencyRate});

  @override
  State<CurrencyDetailPage> createState() => _CurrencyDetailPageState();
}

class _CurrencyDetailPageState extends State<CurrencyDetailPage> {
  static const Color _bgColor = Color(0xFFF8FAFC);
  static const Color _cardWhite = Colors.white;
  static const Color _inkDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderLight = Color(0xFFE2E8F0);

  // Time Range for Chart
  String _timeRange = 'Week'; // 'Day', 'Week', 'Month'
  final List<String> _timeRanges = ['Day', 'Week', 'Month'];

  // Historical data
  List<_ChartPoint> _historyData = [];
  int? _activeChartIndex;
  bool _isLoadingChart = false;

  // Converter state
  bool _isForeignToMmk = true;
  final TextEditingController _foreignController = TextEditingController();
  final TextEditingController _mmkController = TextEditingController();
  final NumberFormat _amountFormat = NumberFormat('#,##0.##', 'en_US');

  // Quick Conversion Matrix Segment
  int _matrixTabIndex = 0; // 0: Foreign -> MMK, 1: MMK -> Foreign

  @override
  void initState() {
    super.initState();
    _isLoadingChart = true;
    _foreignController.text = '1';
    _recalculateForeignToMMK();
    _fetchHistory(isInitial: true);
  }

  @override
  void dispose() {
    _foreignController.dispose();
    _mmkController.dispose();
    super.dispose();
  }

  String _l(String en, String mm, String th) {
    return context.localized(en: en, mm: mm, th: th);
  }

  String _timeRangeLabel(String range) {
    switch (range) {
      case 'Day':
        return _l('1D', '၁ ရက်', '1 วัน');
      case 'Month':
        return _l('1M', '၁ လ', '1 เดือน');
      case 'Week':
      default:
        return _l('7D', '၇ ရက်', '7 วัน');
    }
  }

  Future<void> _fetchHistory({bool isInitial = false}) async {
    if (!isInitial && mounted) {
      setState(() {
        _isLoadingChart = true;
        _historyData = [];
        _activeChartIndex = null;
      });
    }

    try {
      final targetCode = widget.currencyRate.currency;
      final baseRate = widget.currencyRate.sell > 0
          ? widget.currencyRate.sell
          : (widget.currencyRate.buy > 0 ? widget.currencyRate.buy : 1.0);

      final rawPoints =
          await CurrencyExchangeRepository.instance.fetchHistoricalSeries(
        currency: targetCode,
        currentRate: baseRate,
        timeRange: _timeRange,
      );

      if (!mounted) return;
      final points = rawPoints
          .map(
            (p) => _ChartPoint(
              value: p.value,
              label: p.label,
              fullDate: p.fullDate,
            ),
          )
          .toList();

      setState(() {
        _isLoadingChart = false;
        _historyData = points;
        _activeChartIndex = points.isNotEmpty ? points.length - 1 : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingChart = false;
        });
      }
    }
  }

  void _recalculateForeignToMMK() {
    final rawForeign = _foreignController.text.trim().replaceAll(',', '');
    final foreignAmount = double.tryParse(rawForeign);
    if (foreignAmount == null || foreignAmount <= 0) {
      _mmkController.text = '';
      return;
    }
    final rate = widget.currencyRate.buy > 0
        ? widget.currencyRate.buy
        : widget.currencyRate.sell;
    final mmkAmount = foreignAmount * rate;
    _mmkController.text = _formatValue(mmkAmount);
  }

  void _recalculateMMKToForeign() {
    final rawMMK = _mmkController.text.trim().replaceAll(',', '');
    final mmkAmount = double.tryParse(rawMMK);
    if (mmkAmount == null || mmkAmount <= 0) {
      _foreignController.text = '';
      return;
    }
    final rate = widget.currencyRate.sell > 0
        ? widget.currencyRate.sell
        : widget.currencyRate.buy;
    if (rate <= 0) return;
    final foreignAmount = mmkAmount / rate;
    _foreignController.text = _formatValue(foreignAmount);
  }

  void _toggleDirection() {
    HapticFeedback.lightImpact();
    setState(() {
      _isForeignToMmk = !_isForeignToMmk;
    });
    if (_isForeignToMmk) {
      _recalculateForeignToMMK();
    } else {
      _recalculateMMKToForeign();
    }
  }

  void _applyPresetAmount(double amount) {
    HapticFeedback.selectionClick();
    if (_isForeignToMmk) {
      _foreignController.text = _amountFormat.format(amount);
      _recalculateForeignToMMK();
    } else {
      _mmkController.text = _amountFormat.format(amount);
      _recalculateMMKToForeign();
    }
    setState(() {});
  }

  String _formatRate(double value) {
    if (value < 1.0) {
      return NumberFormat('#,##0.####', 'en_US').format(value);
    } else if (value < 10.0) {
      return NumberFormat('#,##0.###', 'en_US').format(value);
    } else if (value < 100.0) {
      return NumberFormat('#,##0.##', 'en_US').format(value);
    } else {
      return NumberFormat('#,##0.##', 'en_US').format(value);
    }
  }

  String _formatValue(double value) {
    if (value < 1.0) {
      return NumberFormat('#,##0.####', 'en_US').format(value);
    } else if (value < 100.0) {
      return NumberFormat('#,##0.##', 'en_US').format(value);
    } else {
      return NumberFormat('#,##0.##', 'en_US').format(value);
    }
  }

  void _handleChartTouch(Offset pos, double totalWidth) {
    if (_historyData.length < 2) return;
    const leftMargin = 38.0;
    const rightMargin = 12.0;
    final chartWidth = totalWidth - leftMargin - rightMargin;
    final x = (pos.dx - leftMargin).clamp(0.0, chartWidth);
    final step = chartWidth / (_historyData.length - 1);
    final index = (x / step).round().clamp(0, _historyData.length - 1);

    if (index != _activeChartIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _activeChartIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.currencyRate;
    final buy = currency.buy;
    final sell = currency.sell;
    final spread = (sell - buy).abs();
    final spreadPercent = buy > 0 ? (spread / buy) * 100 : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
          ),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currency.flagEmoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 8),
              Text(
                '${currency.currency} / MMK',
                style: AppFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
              onPressed: () {
                HapticFeedback.lightImpact();
                _fetchHistory();
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _fetchHistory,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero Currency Info Header Card
                _safeCard('Hero Header', () => _buildHeroHeaderCard(currency, spread, spreadPercent)),

                const SizedBox(height: 14),

                // 2. Buy & Sell Market Rates Card
                _safeCard('Market Rates', () => _buildMarketRatesCard(currency, spread, spreadPercent)),

                const SizedBox(height: 14),

                // 3. Interactive History Rate Chart (Matching Calculation Tab)
                _safeCard('Chart', () => _buildInteractiveChartCard(currency)),

                const SizedBox(height: 14),

                // 4. Essential Professional Market Stats
                _safeCard('Stats Grid', () => _buildMarketStatsGrid(currency, spread, spreadPercent)),

                const SizedBox(height: 14),

                // 5. Quick Conversion Matrix / Cheatsheet Table
                _safeCard('Quick Table', () => _buildQuickConversionTable(currency)),

                const SizedBox(height: 14),

                // 6. Interactive Live Converter Card
                _safeCard('Converter', () => _buildConverterCard(currency)),

                const SizedBox(height: 14),

                // 7. Rates Disclaimer Banner (Primary Gradient Theme)
                _safeCard('Disclaimer', () => _buildDisclaimerBanner()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _safeCard(String name, Widget Function() builder) {
    try {
      return builder();
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(
          'Error loading ' + name + ': ' + e.toString(),
          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
        ),
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. Hero Currency Overview Card
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHeroHeaderCard(
    CurrencyRateModel currency,
    double spread,
    double spreadPercent,
  ) {
    final activeRate = currency.sell > 0 ? currency.sell : currency.buy;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  currency.flagEmoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency.currency,
                      style: AppFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _inkDark,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      currency.currencyName,
                      style: AppFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Live Pulsing Dot Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _LivePulsingDot(),
                    const SizedBox(width: 6),
                    Text(
                      _l('Live Market', 'တိုက်ရိုက်ပေါက်ဈေး', 'ตลาดสด'),
                      style: AppFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Primary Big Rate Display
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '1 ${currency.currency} = ',
                style: AppFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                ),
              ),
              Expanded(
                child: Text(
                  '${_formatRate(activeRate)} MMK',
                  style: AppFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _inkDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _l(
              'Real-time P2P Market Median & Cross-Rate Spot',
              'ပြင်ပပေါက်ဈေးနှင့် ကမ္ဘာ့ဗဟိုဘဏ်များ အကိုးအကားနှုန်း',
              'อัตราอ้างอิง P2P เรียลไทม์และตลาดสากล',
            ),
            style: AppFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Buy & Sell Rates Card (with Spread)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMarketRatesCard(
    CurrencyRateModel currency,
    double spread,
    double spreadPercent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Buy Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB), // Soft warm amber
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD97706),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _l('Buy Rate', 'ဝယ်ယူမည့်ဈေး', 'ราคารับซื้อ'),
                            style: AppFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatRate(currency.buy),
                        style: AppFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${currency.currency} → MMK',
                        style: AppFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Sell Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5), // Soft fresh emerald
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF059669),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _l('Sell Rate', 'ရောင်းချမည့်ဈေး', 'ราคาขายออก'),
                            style: AppFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatRate(currency.sell),
                        style: AppFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'MMK → ${currency.currency}',
                        style: AppFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Spread Margin Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.balance_rounded,
                      size: 16,
                      color: _textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _l('Market Spread', 'ဈေးကွာဟချက် (Spread)', 'ส่วนต่างราคา'),
                      style: AppFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_formatRate(spread)} MMK (${spreadPercent.toStringAsFixed(2)}%)',
                  style: AppFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _inkDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Feature #2: Smart Remittance Advisor ("Best Time to Remit" Indicator)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildRemittanceAdvisorCard(CurrencyRateModel currency) {
    final currentRate = currency.sell > 0 ? currency.sell : currency.buy;
    double avgRate = currentRate;
    double maxRate = currentRate;
    double minRate = currentRate;
    double diffPercent = 0.0;

    if (_historyData.isNotEmpty) {
      final values = _historyData.map((e) => e.value).toList();
      maxRate = values.reduce(max);
      minRate = values.reduce(min);
      avgRate = values.reduce((a, b) => a + b) / values.length;
      if (avgRate > 0) {
        diffPercent = ((currentRate - avgRate) / avgRate) * 100;
      }
    }

    final bool isGreat = diffPercent >= 0.35;
    final bool isLow = diffPercent <= -0.35;

    final String statusTitle;
    final String statusDesc;
    final Color statusColor;
    final Color statusBg;
    final Color statusBorder;
    final IconData statusIcon;

    if (isGreat) {
      statusTitle = _l('Great Time to Remit!', 'ငွေလွှဲရန် အချိန်ကောင်းဖြစ်ပါသည်!', 'เป็นเวลาที่ดีในการโอนเงิน!');
      statusDesc = _l(
        'Current rate is ${diffPercent.abs().toStringAsFixed(1)}% higher than 7-day average. Your recipient receives maximum MMK.',
        'ယခုပေါက်ဈေးသည် ၇ ရက်တာ ပျမ်းမျှထက် ${diffPercent.abs().toStringAsFixed(1)}% ပိုမိုမြင့်တက်နေသဖြင့် မိသားစုထံသို့ ပိုများသော ကျပ်ငွေရောက်ရှိပါမည်။',
        'อัตราปัจจุบันสูงกว่าค่าเฉลี่ย 7 วัน ${diffPercent.abs().toStringAsFixed(1)}% ครอบครัวจะได้รับเงินมากขึ้น',
      );
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
      statusIcon = Icons.trending_up_rounded;
    } else if (isLow) {
      statusTitle = _l('Rate is Low (Consider Waiting)', 'ပေါက်ဈေး အနည်းငယ်ကျနေပါသည်', 'อัตราแลกเปลี่ยนค่อนข้างต่ำ');
      statusDesc = _l(
        'Current rate is ${diffPercent.abs().toStringAsFixed(1)}% below 7-day average. Better to wait if not urgent.',
        'ယခုပေါက်ဈေးသည် ၇ ရက်တာ ပျမ်းမျှထက် ${diffPercent.abs().toStringAsFixed(1)}% လျော့နည်းနေသဖြင့် အလျင်မလိုပါက ဈေးတက်သည်အထိ စောင့်ဆိုင်းသင့်ပါသည်။',
        'อัตราปัจจุบันต่ำกว่าค่าเฉลี่ย 7 วัน ${diffPercent.abs().toStringAsFixed(1)}% แนะนำให้รอก่อนหากไม่รีบ',
      );
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
      statusBorder = const Color(0xFFFDE68A);
      statusIcon = Icons.schedule_rounded;
    } else {
      statusTitle = _l('Stable Fair Market Rate', 'ပေါက်ဈေး တည်ငြိမ်နေပါသည်', 'อัตราแลกเปลี่ยนมีเสถียรภาพ');
      statusDesc = _l(
        'Rate is trading steadily near the 7-day average without steep fluctuations.',
        'ပေါက်ဈေးသည် ၇ ရက်တာ ပျမ်းမျှအဆင့်တွင် အတက်အကျမကြမ်းဘဲ ပုံမှန်အတိုင်း တည်ငြိမ်နေပါသည်။',
        'อัตราแลกเปลี่ยนเคลื่อนไหวใกล้เคียงค่าเฉลี่ย 7 วันอย่างคงที่',
      );
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFEFF6FF);
      statusBorder = const Color(0xFFBFDBFE);
      statusIcon = Icons.tune_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusBorder),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _l('Remittance Advisor', 'ငွေလွှဲ အကြံပြုချက်', 'คำแนะนำการโอนเงิน'),
                      style: AppFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _inkDark,
                      ),
                    ),
                    Text(
                      '${currency.currency} / MMK Analysis',
                      style: AppFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isGreat
                          ? _l('Good to Send', 'အချိန်ကောင်း', 'ช่วงเวลาดี')
                          : (isLow
                              ? _l('Consider Waiting', 'စောင့်ဆိုင်းသင့်', 'ควรรอ')
                              : _l('Fair Rate', 'ပုံမှန်ပေါက်ဈေး', 'ราคาปกติ')),
                      style: AppFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Detail Advice
          Text(
            statusDesc,
            style: AppFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _inkDark,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          // 3 Mini Stats: 7d High, 7d Average, 7d Low
          Row(
            children: [
              Expanded(
                child: _buildAdvisorStatPill(
                  label: _l('7d High', '၇ ရက် အမြင့်ဆုံး', 'สูงสุด 7 วัน'),
                  value: _formatRate(maxRate),
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAdvisorStatPill(
                  label: _l('7d Average', '၇ ရက် ပျမ်းမျှ', 'เฉลี่ย 7 วัน'),
                  value: _formatRate(avgRate),
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAdvisorStatPill(
                  label: _l('7d Low', '၇ ရက် အနိမ့်ဆုံး', 'ต่ำสุด 7 วัน'),
                  value: _formatRate(minRate),
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisorStatPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Interactive History Rate Chart (Matching Calculation Tab)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildInteractiveChartCard(CurrencyRateModel currency) {
    // Determine active point values
    final activePoint = (_activeChartIndex != null &&
            _activeChartIndex! >= 0 &&
            _activeChartIndex! < _historyData.length)
        ? _historyData[_activeChartIndex!]
        : (_historyData.isNotEmpty ? _historyData.last : null);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chart Header & Range Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.show_chart_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _l('Rate Trend', 'ပေါက်ဈေးပြောင်းလဲမှု', 'แนวโน้มราคา'),
                        style: AppFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _inkDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Segmented Range Buttons (Day, Week, Month)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (final range in _timeRanges)
                      GestureDetector(
                        onTap: () {
                          if (_timeRange != range) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _timeRange = range;
                            });
                            _fetchHistory();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _timeRange == range
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: _timeRange == range
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            _timeRangeLabel(range),
                            style: AppFonts.poppins(
                              fontSize: 11,
                              fontWeight: _timeRange == range
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _timeRange == range
                                  ? AppColors.primary
                                  : _textMuted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Active Scrubber Value Indicator
          if (activePoint != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    activePoint.fullDate,
                    style: AppFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _textMuted,
                    ),
                  ),
                  Text(
                    '${_formatRate(activePoint.value)} MMK',
                    style: AppFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // Chart Canvas
          SizedBox(
            height: 190,
            child: _isLoadingChart
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  )
                : _historyData.isEmpty
                    ? Center(
                        child: Text(
                          _l('No history data', 'မှတ်တမ်း အချက်အလက်မရှိပါ', 'ไม่มีข้อมูลประวัติ'),
                          style: AppFonts.poppins(
                            fontSize: 13,
                            color: _textMuted,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onPanDown: (details) => _handleChartTouch(
                              details.localPosition,
                              constraints.maxWidth,
                            ),
                            onPanUpdate: (details) => _handleChartTouch(
                              details.localPosition,
                              constraints.maxWidth,
                            ),
                            child: CustomPaint(
                              size: Size(constraints.maxWidth, 190),
                              painter: _ModernRateChartPainter(
                                data: _historyData,
                                activeIndex: _activeChartIndex,
                                lineColor: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. Essential Professional Market Stats Grid
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMarketStatsGrid(
    CurrencyRateModel currency,
    double spread,
    double spreadPercent,
  ) {
    double highVal = currency.sell;
    double lowVal = currency.buy;
    double medianVal = (currency.buy + currency.sell) / 2;

    if (_historyData.isNotEmpty) {
      final values = _historyData.map((e) => e.value).toList();
      highVal = values.reduce(max);
      lowVal = values.reduce(min);
      medianVal = values.reduce((a, b) => a + b) / values.length;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                _l('Key Market Statistics', 'အဓိက စျေးကွက်စာရင်းအင်းများ', 'สถิติตลาดสำคัญ'),
                style: AppFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _inkDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Mini Statistic Blocks in 2x2 Grid
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: _l('24h High', '၂၄ နာရီ အမြင့်ဆုံး', 'สูงสุด 24 ชม.'),
                  value: '${_formatRate(highVal)} MMK',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  label: _l('24h Low', '၂၄ နာရီ အနိမ့်ဆုံး', 'ต่ำสุด 24 ชม.'),
                  value: '${_formatRate(lowVal)} MMK',
                  icon: Icons.trending_down_rounded,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: _l('Average Rate', 'ပျမ်းမျှ ပေါက်ဈေး', 'ราคาเฉลี่ย'),
                  value: '${_formatRate(medianVal)} MMK',
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  label: _l('Spread Margin', 'အရောင်းအဝယ် ကွာဟချက်', 'มาร์จิ้นส่วนต่าง'),
                  value: '${spreadPercent.toStringAsFixed(2)}%',
                  icon: Icons.balance_rounded,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _inkDark,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. Quick Conversion Matrix / Cheatsheet Table
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildQuickConversionTable(CurrencyRateModel currency) {
    final foreignUnits = [1, 5, 10, 50, 100, 500, 1000];
    final mmkUnits = [10000, 50000, 100000, 500000, 1000000];

    final rateForeignToMmk = currency.buy > 0 ? currency.buy : currency.sell;
    final rateMmkToForeign = currency.sell > 0 ? currency.sell : currency.buy;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.table_chart_rounded,
                color: AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                _l('Quick Conversion Table', 'လျင်မြန်စွာ ကြည့်ရှုရန် ဇယား', 'ตารางแปลงค่าด่วน'),
                style: AppFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _inkDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Tab Switcher for Quick Table
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _matrixTabIndex = 0;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _matrixTabIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _matrixTabIndex == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${currency.currency} → MMK',
                          style: AppFonts.poppins(
                            fontSize: 12,
                            fontWeight: _matrixTabIndex == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _matrixTabIndex == 0
                                ? AppColors.primary
                                : _textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _matrixTabIndex = 1;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _matrixTabIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _matrixTabIndex == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'MMK → ${currency.currency}',
                          style: AppFonts.poppins(
                            fontSize: 12,
                            fontWeight: _matrixTabIndex == 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _matrixTabIndex == 1
                                ? AppColors.primary
                                : _textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Table Rows
          if (_matrixTabIndex == 0)
            ...foreignUnits.map((unit) {
              final mmkVal = unit * rateForeignToMmk;
              return _buildMatrixRow(
                from: '$unit ${currency.currency}',
                to: '${_formatValue(mmkVal)} MMK',
              );
            })
          else
            ...mmkUnits.map((mmk) {
              final foreignVal = rateMmkToForeign > 0 ? (mmk / rateMmkToForeign) : 0.0;
              return _buildMatrixRow(
                from: '${_amountFormat.format(mmk)} MMK',
                to: '${_formatValue(foreignVal)} ${currency.currency}',
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMatrixRow({required String from, required String to}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            from,
            style: AppFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _inkDark,
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: _textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                to,
                style: AppFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. Interactive Live Converter Card
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildConverterCard(CurrencyRateModel currency) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calculate_rounded,
                    color: AppColors.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _l('Quick Calculator', 'ငွေလဲလှယ်တွက်ချက်ရန်', 'เครื่องคำนวณ'),
                    style: AppFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _inkDark,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _toggleDirection,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.swap_vert_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _l('Swap', 'ပြောင်းလဲ', 'สลับ'),
                        style: AppFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // From Field
          _buildInputBox(
            label: _isForeignToMmk ? currency.currency : 'MMK',
            flag: _isForeignToMmk ? currency.flagEmoji : '🇲🇲',
            controller: _isForeignToMmk ? _foreignController : _mmkController,
            isTop: true,
            onChanged: (v) {
              if (_isForeignToMmk) {
                _recalculateForeignToMMK();
              } else {
                _recalculateMMKToForeign();
              }
            },
          ),

          // Central Swap Button
          Center(
            child: GestureDetector(
              onTap: _toggleDirection,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.swap_vert_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),

          // To Field
          _buildInputBox(
            label: _isForeignToMmk ? 'MMK' : currency.currency,
            flag: _isForeignToMmk ? '🇲🇲' : currency.flagEmoji,
            controller: _isForeignToMmk ? _mmkController : _foreignController,
            isTop: false,
            onChanged: (v) {
              if (_isForeignToMmk) {
                _recalculateMMKToForeign();
              } else {
                _recalculateForeignToMMK();
              }
            },
          ),

          const SizedBox(height: 14),

          // Preset Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: (_isForeignToMmk
                    ? [10.0, 50.0, 100.0, 500.0, 1000.0]
                    : [10000.0, 50000.0, 100000.0, 500000.0, 1000000.0])
                .map((amount) {
              return ActionChip(
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                label: Text(
                  '+${_amountFormat.format(amount)}',
                  style: AppFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _inkDark,
                  ),
                ),
                onPressed: () => _applyPresetAmount(amount),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBox({
    required String label,
    required String flag,
    required TextEditingController controller,
    required bool isTop,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _inkDark,
            ),
          ),
          Container(
            height: 24,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: _borderLight,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              cursorColor: AppColors.primary,
              style: AppFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _inkDark,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '0',
                hintStyle: AppFonts.poppins(
                  fontSize: 17,
                  color: _textMuted.withValues(alpha: 0.5),
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 7. Rates Disclaimer Banner (Primary Gradient Theme)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _l(
                'These rates are estimated based on real-time market trading.',
                'ဤနှုန်းထားများသည် အနီးစပ်ဆုံး ခန့်မှန်းဈေးဖြစ်ပါသည်။',
                'อัตราเหล่านี้เป็นราคาโดยประมาณตามการซื้อขายจริงในตลาด',
              ),
              style: AppFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chart Point Model
// ─────────────────────────────────────────────────────────────────────────────

class _ChartPoint {
  final double value;
  final String label;
  final String fullDate;

  _ChartPoint({
    required this.value,
    required this.label,
    required this.fullDate,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Custom Chart Painter (White Card + Primary Gradient)
// ─────────────────────────────────────────────────────────────────────────────

class _ModernRateChartPainter extends CustomPainter {
  final List<_ChartPoint> data;
  final int? activeIndex;
  final Color lineColor;

  _ModernRateChartPainter({
    required this.data,
    required this.activeIndex,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    const leftMargin = 38.0;
    const rightMargin = 12.0;
    const bottomMargin = 26.0;
    const topMargin = 40.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    double maxVal = data.first.value;
    double minVal = data.first.value;
    for (final p in data) {
      if (p.value > maxVal) maxVal = p.value;
      if (p.value < minVal) minVal = p.value;
    }

    final double padding = (maxVal - minVal) * 0.15;
    final effectiveMin = (minVal - padding).clamp(0.0, double.infinity);
    final effectiveMax = maxVal + padding;
    final range =
        (effectiveMax - effectiveMin) == 0 ? 1.0 : (effectiveMax - effectiveMin);

    // 1. Draw horizontal dotted/dashed grid lines & Y labels
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    const int ySegments = 3;
    for (int i = 0; i <= ySegments; i++) {
      final y = topMargin + (chartHeight / ySegments) * i;
      final val = effectiveMax - (range / ySegments) * i;

      // Draw subtle dashed line
      _drawDashedLine(
        canvas,
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        gridPaint,
      );

      // Y-axis text
      final labelStr = val >= 100
          ? val.toStringAsFixed(0)
          : (val < 1.0
              ? val.toStringAsFixed(3)
              : (val < 10.0
                  ? val.toStringAsFixed(2)
                  : val.toStringAsFixed(1)));
      textPainter.text = TextSpan(
        text: labelStr,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(2, y - 6));
    }

    // 2. Compute points for the curve
    final step = chartWidth / (data.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      final x = leftMargin + i * step;
      final normY = (data[i].value - effectiveMin) / range;
      final y = topMargin + chartHeight - (normY * chartHeight);
      points.add(Offset(x, y));
    }

    // 3. Highlighted vertical beam & active column if activeIndex is valid
    if (activeIndex != null &&
        activeIndex! >= 0 &&
        activeIndex! < points.length) {
      final activePoint = points[activeIndex!];

      // Vertical beam background
      final beamRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(activePoint.dx, topMargin + chartHeight / 2),
          width: 38,
          height: chartHeight + 10,
        ),
        const Radius.circular(8),
      );

      final beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.12),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(beamRect.outerRect);

      canvas.drawRRect(beamRect, beamPaint);
    }

    // 4. Draw smooth bezier curve with Primary Gradient
    final linePath = Path();
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        linePath.moveTo(points[0].dx, points[0].dy);
      } else {
        final p0 = points[i - 1];
        final p1 = points[i];
        final midX = (p0.dx + p1.dx) / 2;
        linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }
    }

    // Line Paint with Primary Gradient
    final linePaint = Paint()
      ..shader = AppColors.primaryGradient.createShader(
        Rect.fromLTWH(leftMargin, topMargin, chartWidth, chartHeight),
      )
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // 5. Fill gradient underneath the curve
    final fillPath = Path.from(linePath);
    fillPath.lineTo(points.last.dx, topMargin + chartHeight);
    fillPath.lineTo(points.first.dx, topMargin + chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, topMargin, size.width, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 6. Draw X-axis day labels on bottom
    for (int i = 0; i < data.length; i++) {
      final x = points[i].dx;
      final isCurrent = i == activeIndex;

      textPainter.text = TextSpan(
        text: data[i].label,
        style: TextStyle(
          color: isCurrent ? lineColor : const Color(0xFF64748B),
          fontSize: 10,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - (textPainter.width / 2), size.height - 18),
      );
    }

    // 7. Active Tooltip & Glowing Ring
    if (activeIndex != null &&
        activeIndex! >= 0 &&
        activeIndex! < points.length) {
      final activePoint = points[activeIndex!];
      final activeItem = data[activeIndex!];

      // Outer glow circle
      canvas.drawCircle(
        activePoint,
        8,
        Paint()..color = lineColor.withValues(alpha: 0.2),
      );
      canvas.drawCircle(
        activePoint,
        5.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        activePoint,
        4,
        Paint()..color = lineColor,
      );

      // Tooltip pill box at top with Primary Gradient
      final valStr = activeItem.value >= 100
          ? activeItem.value.toStringAsFixed(2)
          : (activeItem.value < 1.0
              ? activeItem.value.toStringAsFixed(4)
              : (activeItem.value < 10.0
                  ? activeItem.value.toStringAsFixed(3)
                  : activeItem.value.toStringAsFixed(2)));
      final dateStr = activeItem.fullDate;

      final tpVal = TextPainter(
        text: TextSpan(
          text: valStr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final tpDate = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final boxWidth = max(tpVal.width, tpDate.width) + 20;
      const boxHeight = 36.0;
      final boxLeft = (activePoint.dx - boxWidth / 2)
          .clamp(leftMargin, max(leftMargin, size.width - rightMargin - boxWidth))
          .toDouble();
      const boxTop = 0.0;

      final tipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
        const Radius.circular(10),
      );

      // Tooltip background & shadow
      final tipPath = Path()..addRRect(tipRect);
      canvas.drawShadow(
        tipPath,
        lineColor.withValues(alpha: 0.35),
        6,
        false,
      );
      canvas.drawRRect(
        tipRect,
        Paint()
          ..shader = AppColors.primaryGradient.createShader(tipRect.outerRect),
      );

      tpVal.paint(
        canvas,
        Offset(boxLeft + (boxWidth - tpVal.width) / 2, boxTop + 4),
      );
      tpDate.paint(
        canvas,
        Offset(boxLeft + (boxWidth - tpDate.width) / 2, boxTop + 19),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = p1.dx;
    while (startX < p2.dx) {
      canvas.drawLine(
        Offset(startX, p1.dy),
        Offset(min(startX + dashWidth, p2.dx), p1.dy),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _ModernRateChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.lineColor != lineColor;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Pulsing Dot with Primary Gradient Color & Animation
// ─────────────────────────────────────────────────────────────────────────────

class _LivePulsingDot extends StatefulWidget {
  const _LivePulsingDot();

  @override
  State<_LivePulsingDot> createState() => _LivePulsingDotState();
}

class _LivePulsingDotState extends State<_LivePulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );

    _opacityAnimation = Tween<double>(begin: 0.65, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radiating Pulse Ring in Primary Theme
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary
                        .withValues(alpha: _opacityAnimation.value.clamp(0.0, 1.0)),
                  ),
                ),
              );
            },
          ),
          // Core Glowing Solid Center Dot with Primary Gradient
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 3,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
