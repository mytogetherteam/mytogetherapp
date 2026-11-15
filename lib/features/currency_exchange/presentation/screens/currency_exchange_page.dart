import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/location/nominatim_geocoder.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../data/models/currency_rate_model.dart';
import '../../data/repositories/currency_exchange_repository.dart';
import 'currency_detail_page.dart';

class CurrencyExchangePage extends StatefulWidget {
  const CurrencyExchangePage({super.key});

  @override
  State<CurrencyExchangePage> createState() => _CurrencyExchangePageState();
}

class _CurrencyExchangePageState extends State<CurrencyExchangePage>
    with SingleTickerProviderStateMixin {
  // ───────────────────────────────────────────────────────────────────────────
  // Theme Palette (White-based + Primary Gradient Theme)
  // ───────────────────────────────────────────────────────────────────────────
  static const Color _bgLight = Color(0xFFF8F9FB);
  static const Color _cardWhite = Colors.white;
  static const Color _surfaceSoft = Color(0xFFF1F5F9);
  static const Color _sendCardBg = Color(0xFFFFF5F7); // Soft primary rose tint
  static const Color _receiveCardBg = Color(0xFFFFF8F1); // Soft warm coral/orange tint
  static const Color _inkDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderLight = Color(0xFFE2E8F0);

  static const double _maxContentWidth = 620;

  static const CurrencyRateModel _mmkCurrency = CurrencyRateModel(
    currency: 'MMK',
    buy: 1.0,
    sell: 1.0,
  );

  List<CurrencyRateModel> _rates = [];
  List<CurrencyRateModel> _filteredRates = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  String _timestamp = '';

  // Default: Send = Myanmar (MMK), Receive = THB. Both can be changed via dropdown.
  CurrencyRateModel _fromCurrency = _mmkCurrency;
  CurrencyRateModel? _toCurrency;
  bool _lastEditedSend = true;

  int _selectedTab = 0; // 0 = Calculator, 1 = Rates & Info, 2 = Money Changers & ATMs

  String _selectedCategory = 'all'; // 'all', 'exchange', 'bank', 'atm'
  int _selectedChangerFilter = 0; // 0 = All, 1 = Nearest, 2 = Best Rate, 3 = Open Now, 4 = BTS/MRT
  int _selectedRadiusKm = 10; // 0 = All, 5 = 5km, 10 = 10km, 25 = 25km
  bool _isMapView = true; // Dedicated Map View
  Position? _userPosition;
  String? _userAreaName;
  bool _isLocatingUser = false;
  String? _locationError;
  GoogleMapController? _mapController;
  String? _selectedCounterId;
  Set<Marker> _mapMarkers = {};
  final Map<String, BitmapDescriptor> _customMarkerCache = {};
  final Map<String, ui.Image> _assetImageCache = {};
  int _markerUpdateToken = 0;
  List<_MoneyChangerCounter> _osmNearbyCounters = [];
  bool _isFetchingOsm = false;
  Position? _lastOsmFetchedPosition;
  int _lastOsmFetchedRadius = -1;

  String _timeRange = 'Week'; // 'Day', 'Week', 'Month'
  final List<String> _timeRanges = ['Day', 'Week', 'Month'];
  List<_ChartPoint> _historyData = [];
  int? _activeChartIndex;

  final TextEditingController _sendController = TextEditingController();
  final TextEditingController _receiveController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  List<CurrencyRateModel> get _allCurrencies => [_mmkCurrency, ..._rates];

  final NumberFormat _amountFormat = NumberFormat('#,##0.##', 'en_US');

  late AnimationController _swapAnimController;
  Timer? _autoRefreshTimer;
  List<_MoneyChangerCounter>? _cachedAllCounters;
  Position? _lastCachedUserPosition;
  String? _lastCachedAreaName;
  List<_MoneyChangerCounter>? _memoizedCuratedFlagships;

  @override
  void initState() {
    super.initState();
    _swapAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchController.addListener(_onSearchChanged);
    _fetchRates();
    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _fetchRates(forceRefresh: true, silent: true),
    );
    _getUserLocation(requestIfDenied: false);
    _preloadMarkerAssets();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();
    _swapAnimController.dispose();
    _sendController.dispose();
    _receiveController.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredRates = List.from(_rates);
      } else {
        _filteredRates = _rates.where((rate) {
          final code = rate.currency.toLowerCase();
          final name = rate.currencyName.toLowerCase();
          return code.contains(query) || name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchRates({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        if (forceRefresh) {
          _isRefreshing = true;
        } else {
          _isLoading = true;
        }
        _error = null;
      });
    }

    try {
      final result = await CurrencyExchangeRepository.instance.fetchRates(
        forceRefresh: forceRefresh,
      );

      const priority = ['THB', 'USD', 'SGD', 'MYR', 'VND', 'JPY', 'GBP'];
      result.rates.sort((a, b) {
        final indexA = priority.indexOf(a.currency);
        final indexB = priority.indexOf(b.currency);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return a.currency.compareTo(b.currency);
      });

      if (!mounted) return;
      setState(() {
        _rates = result.rates;
        _timestamp = result.timestamp;
        _isLoading = false;
        _isRefreshing = false;

        final defaultTo = _rates.isNotEmpty
            ? _rates.firstWhere(
                (r) => r.currency == 'THB',
                orElse: () => _rates.first,
              )
            : _mmkCurrency;

        if (_toCurrency == null) {
          _toCurrency = defaultTo;
        } else if (_toCurrency!.currency != 'MMK') {
          _toCurrency = _rates.firstWhere(
            (r) => r.currency == _toCurrency!.currency,
            orElse: () => defaultTo,
          );
        }

        if (_fromCurrency.currency != 'MMK') {
          _fromCurrency = _rates.firstWhere(
            (r) => r.currency == _fromCurrency.currency,
            orElse: () => _mmkCurrency,
          );
        }

        _onSearchChanged();
        _recalculateCurrentDirection();
      });
      await _generateChartData();
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = context.tr('currency.load_failed');
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  /// Converts [amount] of [from] currency into [to] currency:
  /// - MMK -> Foreign: user buys Foreign at dealer `sell` rate (`amount / to.sell`)
  /// - Foreign -> MMK: user sells Foreign at dealer `buy` rate (`amount * from.buy`)
  /// - Foreign -> Foreign: cross-rate (`amount * (from.midRate / to.midRate)`)
  double _convertAmount(
    double amount,
    CurrencyRateModel from,
    CurrencyRateModel to,
  ) {
    if (from.currency == to.currency) return amount;
    if (from.currency == 'MMK') {
      return to.sell > 0 ? amount / to.sell : 0.0;
    }
    if (to.currency == 'MMK') {
      return amount * from.buy;
    }
    return to.midRate > 0 ? amount * (from.midRate / to.midRate) : 0.0;
  }

  void _recalculateSendToReceive() {
    _lastEditedSend = true;
    final to = _toCurrency;
    final rawSend = _sendController.text.trim().replaceAll(',', '');
    final sendAmount = double.tryParse(rawSend);
    if (sendAmount == null || to == null) {
      _receiveController.text = '';
      return;
    }
    final receiveAmount = _convertAmount(sendAmount, _fromCurrency, to);
    _receiveController.text = _amountFormat.format(receiveAmount);
  }

  void _recalculateReceiveToSend() {
    _lastEditedSend = false;
    final to = _toCurrency;
    final rawReceive = _receiveController.text.trim().replaceAll(',', '');
    final receiveAmount = double.tryParse(rawReceive);
    if (receiveAmount == null || to == null) {
      _sendController.text = '';
      return;
    }
    final sendAmount = _convertAmount(receiveAmount, to, _fromCurrency);
    _sendController.text = _amountFormat.format(sendAmount);
  }

  void _recalculateCurrentDirection() {
    if (_lastEditedSend && _sendController.text.trim().isNotEmpty) {
      _recalculateSendToReceive();
    } else if (!_lastEditedSend && _receiveController.text.trim().isNotEmpty) {
      _recalculateReceiveToSend();
    } else if (_sendController.text.trim().isNotEmpty) {
      _recalculateSendToReceive();
    } else if (_receiveController.text.trim().isNotEmpty) {
      _recalculateReceiveToSend();
    }
  }

  void _toggleSwap() {
    HapticFeedback.mediumImpact();
    _swapAnimController.forward(from: 0.0);
    setState(() {
      final currentTo =
          _toCurrency ?? (_rates.isNotEmpty ? _rates.first : _mmkCurrency);
      final temp = _fromCurrency;
      _fromCurrency = currentTo;
      _toCurrency = temp;

      if (_sendController.text.trim().isNotEmpty) {
        _recalculateSendToReceive();
      } else if (_receiveController.text.trim().isNotEmpty) {
        _recalculateReceiveToSend();
      }
    });
    _generateChartData();
  }

  void _onSelectFromCurrency(CurrencyRateModel newFrom) {
    HapticFeedback.selectionClick();
    setState(() {
      final currentTo =
          _toCurrency ?? (_rates.isNotEmpty ? _rates.first : _mmkCurrency);
      if (newFrom.currency == currentTo.currency) {
        _toCurrency = _fromCurrency;
      }
      _fromCurrency = newFrom;
      _recalculateCurrentDirection();
    });
    _generateChartData();
  }

  void _onSelectToCurrency(CurrencyRateModel newTo) {
    HapticFeedback.selectionClick();
    setState(() {
      if (newTo.currency == _fromCurrency.currency) {
        _fromCurrency =
            _toCurrency ?? (_rates.isNotEmpty ? _rates.first : _mmkCurrency);
      }
      _toCurrency = newTo;
      _recalculateCurrentDirection();
    });
    _generateChartData();
  }

  Future<void> _generateChartData() async {
    final to =
        _toCurrency ?? (_rates.isNotEmpty ? _rates.first : _mmkCurrency);
    final range = _timeRange;

    // Determine which foreign currency and reference rate to plot on the chart:
    late final String chartCurrency;
    late final double chartBaseRate;
    if (_fromCurrency.currency == 'MMK' && to.currency != 'MMK') {
      chartCurrency = to.currency;
      chartBaseRate = to.sell;
    } else if (to.currency == 'MMK' && _fromCurrency.currency != 'MMK') {
      chartCurrency = _fromCurrency.currency;
      chartBaseRate = _fromCurrency.buy;
    } else if (_fromCurrency.currency != 'MMK' && to.currency != 'MMK') {
      chartCurrency = _fromCurrency.currency;
      chartBaseRate = _convertAmount(1.0, _fromCurrency, to);
    } else {
      chartCurrency = 'THB';
      chartBaseRate = 124.0;
    }

    final rawPoints =
        await CurrencyExchangeRepository.instance.fetchHistoricalSeries(
      currency: chartCurrency,
      currentRate: chartBaseRate,
      timeRange: range,
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
      _historyData = points;
      _activeChartIndex = points.isNotEmpty ? points.length - 1 : null;
    });
  }

  String _formatRate(double value) {
    if (value < 1.0) {
      return NumberFormat('#,##0.####', 'en_US').format(value);
    } else if (value < 10.0) {
      return NumberFormat('#,##0.###', 'en_US').format(value);
    }
    return NumberFormat('#,##0.##', 'en_US').format(value);
  }

  String _l(String en, String mm, String th) {
    return context.localized(en: en, mm: mm, th: th);
  }

  String _timeRangeLabel(String range) {
    switch (range) {
      case 'Day':
        return context.tr('currency.range_day');
      case 'Week':
        return context.tr('currency.range_week');
      case 'Month':
        return context.tr('currency.range_month');
      default:
        return range;
    }
  }

  void _openDetail(CurrencyRateModel rate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CurrencyDetailPage(currencyRate: rate),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Main Build
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (_isScrolled
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light)
          .copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _selectedTab == 2 ? Brightness.dark : (_isScrolled ? Brightness.dark : Brightness.light),
        statusBarBrightness:
            _selectedTab == 2 ? Brightness.light : (_isScrolled ? Brightness.light : Brightness.dark),
      ),
      child: Scaffold(
        backgroundColor: _bgLight,
        bottomNavigationBar: _buildBottomTabBar(),
        body: _selectedTab == 2
            ? _buildFullScreenMapTab()
            : Stack(
                children: [
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: (notification) {
                      final scrolled = notification.metrics.pixels > 105;
                      if (scrolled != _isScrolled) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && scrolled != _isScrolled) {
                            setState(() => _isScrolled = scrolled);
                          }
                        });
                      }
                      return false;
                    },
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: _cardWhite,
                      edgeOffset: MediaQuery.of(context).padding.top + 40,
                      onRefresh: () => _fetchRates(forceRefresh: true),
                      child: ListView(
                        controller: _scrollController,
                        cacheExtent: 250,
                        padding: EdgeInsets.zero,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          // Header Banner with Bottom White Fade (Reduced Height)
                          _buildHeader(),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _isLoading
                                ? KeyedSubtree(
                                    key: ValueKey('skeleton_$_selectedTab'),
                                    child: _buildSkeletonLoading(),
                                  )
                                : _error != null
                                    ? KeyedSubtree(
                                        key: const ValueKey('error_state'),
                                        child: _buildErrorState(),
                                      )
                                    : KeyedSubtree(
                                        key: ValueKey('content_$_selectedTab'),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            4,
                                            16,
                                            36,
                                          ),
                                          child: Align(
                                            alignment: Alignment.topCenter,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: _maxContentWidth,
                                              ),
                                              child: _selectedTab == 0
                                                  ? _buildCalculatorTabContent()
                                                  : _buildInfoTabContent(),
                                            ),
                                          ),
                                        ),
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sticky Top Bar (Transparent when at top, White when scrolled)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildFloatingTopBar(),
                  ),
                ],
              ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 0: Currency Calculator (Converter + Rate Pattern)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildCalculatorTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Send & Receive Conversion Cards
        _buildSendReceiveSection(),

        const SizedBox(height: 10),

        // Rates Disclaimer Banner
        _buildRatesDisclaimerBanner(),

        const SizedBox(height: 14),

        // 2. Rate Pattern with Interactive Graph
        _buildRatePatternCard(),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 1: Rates Directory & Market Info Guide
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildInfoTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Latest Rates Directory with Search and Live Prices
        _buildLatestRatesDirectory(),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Bottom Tab Bar (Home & Visa page style)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildBottomTabBar() {
    final inactiveColor = Colors.grey.shade400;
    final bottomInset = Theme.of(context).platform == TargetPlatform.iOS
        ? MediaQuery.of(context).padding.bottom * 0.5
        : MediaQuery.of(context).padding.bottom;
    const barBodyHeight = 64.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: barBodyHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _tabButton(
                    index: 0,
                    icon: PhosphorIconsRegular.calculator,
                    activeIcon: PhosphorIconsFill.calculator,
                    title: context.tr('currency.tab_calculator'),
                    inactiveColor: inactiveColor,
                    height: barBodyHeight,
                  ),
                  _tabButton(
                    index: 1,
                    icon: PhosphorIconsRegular.currencyCircleDollar,
                    activeIcon: PhosphorIconsFill.currencyCircleDollar,
                    title: context.tr('currency.tab_info'),
                    inactiveColor: inactiveColor,
                    height: barBodyHeight,
                  ),
                  _tabButton(
                    index: 2,
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map_rounded,
                    title: _l('Counters & ATMs', 'ငွေလဲနှင့် ဘဏ်များ', 'แลกเงินและตู้ ATM'),
                    inactiveColor: inactiveColor,
                    height: barBodyHeight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required Color inactiveColor,
    required double height,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (_selectedTab == index) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              );
            }
            return;
          }
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
          setState(() {
            _selectedTab = index;
            _isScrolled = false;
            if (index == 2 && _userPosition == null) {
              _getUserLocation(requestIfDenied: false);
            }
          });
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.primaryGradient.colors,
                      ).createShader(bounds),
                      child: Icon(
                        activeIcon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.primaryGradient.colors,
                      ).createShader(bounds),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: inactiveColor, size: 24),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          color: inactiveColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Floating Top Bar (Sticky on Scroll, Glass/Transparent at Top)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildFloatingTopBar() {
    final top = MediaQuery.of(context).padding.top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.only(top: top, left: 12, right: 14),
      height: top + 56,
      decoration: BoxDecoration(
        color: _isScrolled ? Colors.white : Colors.transparent,
        border: _isScrolled
            ? Border(
                bottom: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              )
            : null,
        boxShadow: _isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isScrolled
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsRegular.arrowLeft,
                color: _isScrolled ? _inkDark : Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Title (Visible when scrolled)
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isScrolled ? 1.0 : 0.0,
              child: Text(
                context.tr('currency.title'),
                style: AppFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _inkDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Share Rate Card Button
          GestureDetector(
            onTap: _showShareRateCardModal,
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: _isScrolled
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.share_rounded,
                  color: _isScrolled ? _inkDark : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Refresh Button
          GestureDetector(
            onTap: () => _fetchRates(forceRefresh: true),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _isScrolled
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isRefreshing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _isScrolled ? AppColors.primary : Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        color: _isScrolled ? _inkDark : Colors.white,
                        size: 21,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Header Hero with Background Image & Bottom White Fade (like Visa & Jobs)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final top = MediaQuery.of(context).padding.top;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final headerHeight = (isIOS ? 170.0 : 160.0) + top;

    return SizedBox(
      width: double.infinity,
      height: headerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Illustration Image (New CentralWorld BTS Bangkok Banner)
          Image.asset(
            'assets/images/currency_header_bg.png',
            width: double.infinity,
            height: headerHeight,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // Subtle top/left scrim for status bar & top button readability
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.32),
                  Colors.black.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Smooth bottom fade-to-white gradient style
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 70,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.58, 1.0],
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    const Color(0xFFF8F9FB).withValues(alpha: 0.78),
                    const Color(0xFFF8F9FB),
                  ],
                ),
              ),
            ),
          ),
          // Header Foreground Content
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 42, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                // Title on Image (Tab 0: Converter, Tab 1: Latest Rates, Tab 2: Money Changers)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedTab == 0
                            ? context.tr('currency.converter')
                            : (_selectedTab == 1
                                ? context.tr('currency.latest_rate')
                                : _l('Counters & ATMs Map', 'ငွေလဲနှင့် ဘဏ်များ မြေပုံ', 'แผนที่แลกเงินและตู้ ATM')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          color: Colors.white,
                          fontSize: 19.5,
                          fontWeight: FontWeight.w800,
                        ).copyWith(
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1.5),
                              blurRadius: 8,
                              color: Colors.black.withValues(alpha: 0.65),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    // Live Badge
                    Container(
                      padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.38),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _LivePulsingDot(),
                          const SizedBox(width: 4),
                          Text(
                            _timestamp.isNotEmpty
                                ? '${_l('Live Rate', 'ယခုပေါက်စျေး', 'อัตราสด')} · $_timestamp'
                                : context.tr('currency.live_badge'),
                            style: AppFonts.poppins(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick Share Rate Card Chip
                    GestureDetector(
                      onTap: _showShareRateCardModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.share_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _l('Share Card', 'ပေါက်ဈေး Card မျှဝေမည်', 'แชร์การ์ด'),
                              style: AppFonts.poppins(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. Send & Receive Cards (White-Based + Primary Gradient Accents)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSendReceiveSection() {
    final to =
        _toCurrency ?? (_rates.isNotEmpty ? _rates.first : _mmkCurrency);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            // Top Card: Send (Default: Myanmar MMK, changeable via dropdown)
            _buildPastelInputCard(
              bgColor: _sendCardBg,
              borderColor: AppColors.primary.withValues(alpha: 0.18),
              label: context.tr('currency.send'),
              selectedCurrency: _fromCurrency,
              controller: _sendController,
              onSelectCurrency: _onSelectFromCurrency,
              onChanged: (_) => _recalculateSendToReceive(),
            ),

            const SizedBox(height: 12),

            // Bottom Card: Receive (Default: THB, changeable via dropdown)
            _buildPastelInputCard(
              bgColor: _receiveCardBg,
              borderColor: AppColors.secondary.withValues(alpha: 0.22),
              label: context.tr('currency.receive'),
              selectedCurrency: to,
              controller: _receiveController,
              onSelectCurrency: _onSelectToCurrency,
              onChanged: (_) => _recalculateReceiveToSend(),
            ),
          ],
        ),

        // Middle Floating Circular Swap Button (⇅) with Primary Gradient
        Positioned(
          child: GestureDetector(
            onTap: _toggleSwap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.5)
                      .animate(_swapAnimController),
                  child: const Icon(
                    PhosphorIcons.arrowsDownUpBold,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPastelInputCard({
    required Color bgColor,
    required Color borderColor,
    required String label,
    required CurrencyRateModel selectedCurrency,
    required TextEditingController controller,
    required ValueChanged<CurrencyRateModel> onSelectCurrency,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
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
          // Label row
          Text(
            label,
            style: AppFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 6),
          // Amount & Currency selector row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Amount Input Field (No underline)
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  cursorColor: AppColors.primary,
                  onChanged: onChanged,
                  style: AppFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: _inkDark,
                    height: 1.15,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: AppFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: _inkDark.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Currency Pill Dropdown (Supports MMK + all currencies)
              _buildCurrencyDropdownPill(
                selectedCurrency: selectedCurrency,
                onSelect: onSelectCurrency,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdownPill({
    required CurrencyRateModel selectedCurrency,
    required ValueChanged<CurrencyRateModel> onSelect,
  }) {
    final items = _allCurrencies;
    final activeValue = items.firstWhere(
      (r) => r.currency == selectedCurrency.currency,
      orElse: () => items.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CurrencyRateModel>(
          isDense: true,
          value: activeValue,
          borderRadius: BorderRadius.circular(20),
          dropdownColor: Colors.white,
          menuMaxHeight: 380,
          icon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          items: items.map((rate) {
            return DropdownMenuItem<CurrencyRateModel>(
              value: rate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(rate.flagEmoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    rate.currency,
                    style: AppFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _inkDark,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              onSelect(val);
            }
          },
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Rate Pattern with Interactive Graph (White Card + Primary Gradient)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildRatePatternCard() {
    final to =
        _toCurrency ?? (_rates.isNotEmpty ? _rates.first : _mmkCurrency);

    // Format the rate headline clearly for the active pair:
    late final String rateHeadline;
    CurrencyRateModel? thbRate;
    if (_fromCurrency.currency == 'MMK' && to.currency != 'MMK') {
      rateHeadline =
          '1 ${to.currency} = ${_formatRate(to.sell)} MMK  |  ${_timestamp.isNotEmpty ? _timestamp : _l("Live", "ယခုပေါက်စျေး", "สด")}';
      if (to.currency == 'THB') thbRate = to;
    } else if (to.currency == 'MMK' && _fromCurrency.currency != 'MMK') {
      rateHeadline =
          '1 ${_fromCurrency.currency} = ${_formatRate(_fromCurrency.buy)} MMK  |  ${_timestamp.isNotEmpty ? _timestamp : _l("Live", "ယခုပေါက်စျေး", "สด")}';
      if (_fromCurrency.currency == 'THB') thbRate = _fromCurrency;
    } else {
      final cross = _convertAmount(1.0, _fromCurrency, to);
      rateHeadline =
          '1 ${_fromCurrency.currency} = ${_formatRate(cross)} ${to.currency}  |  ${_timestamp.isNotEmpty ? _timestamp : _l("Live", "ယခုပေါက်စျေး", "สด")}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header Row: Title & Range Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradientVertical,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('currency.rate_pattern'),
                  style: AppFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _inkDark,
                  ),
                ),
              ],
            ),
            // Time range selector (Week v)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _cardWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isDense: true,
                  value: _timeRange,
                  dropdownColor: _cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  icon: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  items: _timeRanges.map((range) {
                    return DropdownMenuItem(
                      value: range,
                      child: Text(
                        _timeRangeLabel(range),
                        style: AppFonts.poppins(
                          color: _inkDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _timeRange = v;
                      });
                      _generateChartData();
                    }
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // White Chart Container
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
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
              // Interactive Currency Pair Row: [ 🇲🇲 MMK ▾ ]  ⇄  [ 🇹🇭 THB ▾ ]
              Row(
                children: [
                  _buildPairDropdownChip(
                    selectedCurrency: _fromCurrency,
                    onSelect: _onSelectFromCurrency,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _toggleSwap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPairDropdownChip(
                    selectedCurrency: to,
                    onSelect: _onSelectToCurrency,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Rate & Date Subtitle
              Text(
                rateHeadline,
                style: AppFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                ),
              ),
              if (thbRate != null && thbRate.sell > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _sendCardBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🇲🇲 100,000 MMK  ≈  🇹🇭 ${_amountFormat.format(100000 / thbRate.sell)} THB',
                        style: AppFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Interactive Chart Widget
              SizedBox(
                height: 190,
                child: _historyData.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
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
        ),
      ],
    );
  }

  Widget _buildPairDropdownChip({
    required CurrencyRateModel selectedCurrency,
    required ValueChanged<CurrencyRateModel> onSelect,
  }) {
    final items = _allCurrencies;
    final activeValue = items.firstWhere(
      (r) => r.currency == selectedCurrency.currency,
      orElse: () => items.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CurrencyRateModel>(
          isDense: true,
          value: activeValue,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: Colors.white,
          menuMaxHeight: 360,
          icon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          items: items.map((rate) {
            return DropdownMenuItem<CurrencyRateModel>(
              value: rate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(rate.flagEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    rate.currency,
                    style: AppFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _inkDark,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              onSelect(val);
            }
          },
        ),
      ),
    );
  }

  void _handleChartTouch(Offset pos, double totalWidth) {
    if (_historyData.isEmpty) return;
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

  // ───────────────────────────────────────────────────────────────────────────
  // Rates Disclaimer Banner (Primary Gradient Theme)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildRatesDisclaimerBanner() {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 2, bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 14.5,
            color: AppColors.primary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              context.tr('currency.rates_disclaimer'),
              style: AppFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: _textMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Latest Rates Directory (All Data Included)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildLatestRatesDirectory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Search Bar (First)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: _cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderLight),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: _textMuted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  cursorColor: AppColors.primary,
                  style: AppFonts.poppins(
                    fontSize: 13,
                    color: _inkDark,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: InputBorder.none,
                    hintText: context.tr('currency.search_hint'),
                    hintStyle: AppFonts.poppins(
                      fontSize: 13,
                      color: _textMuted,
                    ),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _textMuted,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 2. Disclaimer Banner (Aligned with search bar content & balanced spacing)
        _buildRatesDisclaimerBanner(),

        const SizedBox(height: 15),

        // Rates Grid (2 Columns in 1 Row - Option 1)
        if (_filteredRates.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Text(
              context.tr('currency.not_found'),
              style: AppFonts.poppins(
                fontSize: 14,
                color: _textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Builder(
            builder: (context) {
              final screenW = MediaQuery.of(context).size.width;
              final contentW = min(screenW, _maxContentWidth) - 32;
              final cardW = (contentW - 10) / 2;
              final childAspectRatio = (cardW / 126).clamp(1.10, 1.45);
              return GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredRates.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final rate = _filteredRates[index];
                  return _buildRateGridCard(rate);
                },
              );
            },
          ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Modern 2-Column Grid Card (Compact, Beautiful UI, No Overflow)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildRateGridCard(CurrencyRateModel rate) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetail(rate),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: _cardWhite,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: Flag + Code/Name + Chevron
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      rate.flagEmoji,
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rate.currency,
                          style: AppFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _inkDark,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          rate.currencyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.poppins(
                            fontSize: 10,
                            color: _textMuted,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Unified Clean Rates Container (No messy colorful striped boxes)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    // Buy Row (ဝယ်ယူ)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEA580C),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              context.tr('currency.buy'),
                              style: AppFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _formatRate(rate.buy),
                              style: AppFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _inkDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 3.5),
                      child: Divider(
                        height: 1,
                        thickness: 0.6,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),

                    // Sell Row (ရောင်းမယ်)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              context.tr('currency.sell'),
                              style: AppFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _formatRate(rate.sell),
                              style: AppFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _inkDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Feature #2: Smart Remittance Advisor ("Best Time to Remit" Indicator)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildRemittanceAdvisorCard() {
    final to = _toCurrency ??
        (_rates.isNotEmpty
            ? _rates.firstWhere(
                (r) => r.currency == 'THB',
                orElse: () => _rates.first,
              )
            : _mmkCurrency);

    final toCode =
        to.currency == 'MMK' ? _fromCurrency.currency : to.currency;
    final currentRate = to.currency == 'MMK'
        ? (_fromCurrency.buy > 0 ? _fromCurrency.buy : 1.0)
        : (to.sell > 0 ? to.sell : to.buy);

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

    final String badgeText;
    final Color badgeColor;
    final Color badgeBg;
    final Color badgeBorder;

    final String adviceTitle;
    final String adviceDetail;
    final Color adviceBoxBg;
    final Color adviceBoxBorder;
    final Color adviceTextColor;
    final IconData adviceIcon;

    final diffText = diffPercent.abs().toStringAsFixed(1);

    if (isGreat) {
      badgeText = _l('Best Time to Send ✨', 'ငွေလွှဲရန် အကောင်းဆုံး ✨', 'ช่วงเวลาโอนดีที่สุด ✨');
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFECFDF5);
      badgeBorder = const Color(0xFFA7F3D0);

      adviceTitle = _l(
        'Recommended time to send money!',
        'ယခုအချိန် ငွေလွှဲရန် အထူးသင့်တော်ပါသည်!',
        'แนะนำให้โอนเงินช่วงนี้เป็นพิเศษ!',
      );
      adviceDetail = _l(
        'The current rate is $diffText% higher than the 7-day average. Your family in Myanmar receives maximum MMK for your money.',
        'ယခုပေါက်ဈေးသည် ၇ ရက်တာ ပျမ်းမျှထက် $diffText% ပိုမိုမြင့်တက်နေသဖြင့် မြန်မာပြည်မှ မိသားစုထံသို့ ကျပ်ငွေ အများဆုံး ရရှိပါမည်။',
        'เรทปัจจุบันสูงกว่าค่าเฉลี่ย 7 วัน $diffText% ครอบครัวที่พม่าจะได้รับเงินจ๊าดมากที่สุด',
      );
      adviceBoxBg = const Color(0xFFECFDF5);
      adviceBoxBorder = const Color(0xFFA7F3D0);
      adviceTextColor = const Color(0xFF065F46);
      adviceIcon = Icons.stars_rounded;
    } else if (isLow) {
      badgeText = _l('Rate is Low ⏳', 'ဈေးအနည်းငယ် ကျနေသည် ⏳', 'เรทค่อนข้างต่ำ ⏳');
      badgeColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFFFFFBEB);
      badgeBorder = const Color(0xFFFDE68A);

      adviceTitle = _l(
        'Consider waiting if not urgent',
        'အရေးမကြီးပါက ဈေးတက်သည်အထိ စောင့်သင့်ပါသည်',
        'หากไม่รีบด่วน แนะนำให้รอก่อน',
      );
      adviceDetail = _l(
        'The rate is $diffText% below the 7-day average. If you do not need to send urgently, waiting a few days may give you a better rate.',
        '၇ ရက်တာ ပျမ်းမျှထက် $diffText% လျော့နည်းနေသဖြင့် အလျင်မလိုပါက ဈေးပြန်တက်သည်အထိ စောင့်ဆိုင်းပြီးမှ လွှဲသင့်ပါသည်။',
        'เรทต่ำกว่าเฉลี่ย 7 วัน $diffText% หากไม่รีบ แนะนำให้รอเรทฟื้นตัวเพื่อได้ราคาที่ดีกว่า',
      );
      adviceBoxBg = const Color(0xFFFFFBEB);
      adviceBoxBorder = const Color(0xFFFDE68A);
      adviceTextColor = const Color(0xFF92400E);
      adviceIcon = Icons.hourglass_top_rounded;
    } else {
      badgeText = _l('Fair Rate ⚖️', 'ပုံမှန် ပေါက်ဈေး ⚖️', 'เรทปกติ ⚖️');
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFEFF6FF);
      badgeBorder = const Color(0xFFBFDBFE);

      adviceTitle = _l(
        'Fair and steady market rate',
        'ပေါက်ဈေး ပုံမှန်အတိုင်း တည်ငြိမ်နေပါသည်',
        'อัตราแลกเปลี่ยนอยู่ในเกณฑ์ปกติ',
      );
      adviceDetail = _l(
        'The exchange rate is trading steadily near the weekly average without sudden drops. Safe and fair to send.',
        'ပေါက်ဈေးသည် အတက်အကျမကြမ်းဘဲ ၇ ရက်တာ ပျမ်းမျှအတိုင်း တည်ငြိမ်နေသဖြင့် စိတ်ချစွာ ငွေလွှဲနိုင်ပါသည်။',
        'เรทเคลื่อนไหวคงที่ใกล้เคียงค่าเฉลี่ย 7 วัน ไม่มีความผันผวน สามารถโอนได้ตามปกติ',
      );
      adviceBoxBg = const Color(0xFFF8FAFC);
      adviceBoxBorder = const Color(0xFFE2E8F0);
      adviceTextColor = const Color(0xFF1E293B);
      adviceIcon = Icons.check_circle_outline_rounded;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: _cardWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.16),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Primary Gradient Accent Bar
            Container(
              height: 3.5,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Row
                  Row(
                    children: [
                      // Primary Gradient Badge Icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.32),
                              blurRadius: 7,
                              offset: const Offset(0, 2.5),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.currency_exchange_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _l('Remittance Advisor', 'ငွေလွှဲရန် အကြံပြုချက်', 'คำแนะนำการโอนเงิน'),
                              style: AppFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: _inkDark,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '$toCode / MMK ' + _l('Rate Analysis', 'ပေါက်ဈေး သုံးသပ်ချက်', 'วิเคราะห์เรท'),
                              style: AppFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: badgeBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              badgeText,
                              style: AppFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Easy-to-understand Advice Box (Friendly for normal people)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: adviceBoxBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: adviceBoxBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            adviceIcon,
                            size: 18,
                            color: isGreat
                                ? const Color(0xFF059669)
                                : (isLow ? const Color(0xFFD97706) : AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adviceTitle,
                                style: AppFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: adviceTextColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                adviceDetail,
                                style: AppFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: adviceTextColor.withValues(alpha: 0.88),
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3 Mini Stat Pills: 7d High, 7d Average, 7d Low
                  Row(
                    children: [
                      Expanded(
                        child: _buildAdvisorStatPill(
                          label: _l('7-Day High', '၇ ရက် အမြင့်ဆုံး', 'สูงสุด 7 วัน'),
                          value: _formatRate(maxRate),
                          subLabel: _l('Best Peak', 'ဈေးအများဆုံးရ', 'เรทดีสุด'),
                          color: const Color(0xFF059669),
                          accentGradient: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAdvisorStatPill(
                          label: _l('7-Day Avg', '၇ ရက် ပျမ်းမျှ', 'เฉลี่ย 7 วัน'),
                          value: _formatRate(avgRate),
                          subLabel: _l('Fair Market', 'ပုံမှန်ပေါက်ဈေး', 'ราคาปกติ'),
                          color: AppColors.primary,
                          accentGradient: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAdvisorStatPill(
                          label: _l('7-Day Low', '၇ ရက် အနိမ့်ဆုံး', 'ต่ำสุด 7 วัน'),
                          value: _formatRate(minRate),
                          subLabel: _l('Lowest Rate', 'ဈေးအနည်းဆုံးရ', 'เรทต่ำสุด'),
                          color: const Color(0xFFDC2626),
                          accentGradient: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisorStatPill({
    required String label,
    required String value,
    required String subLabel,
    required Color color,
    bool accentGradient = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: accentGradient
            ? AppColors.primary.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentGradient
              ? AppColors.primary.withValues(alpha: 0.22)
              : const Color(0xFFE2E8F0),
          width: accentGradient ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────

  void _showShareRateCardModal() {
    HapticFeedback.lightImpact();
    final GlobalKey cardBoundaryKey = GlobalKey();
    bool isGenerating = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Modal Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _l('Share Rate Card', 'ပေါက်ဈေး Card မျှဝေမည်', 'แชร์การ์ดอัตราแลกเปลี่ยน'),
                          style: AppFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _inkDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22, color: _textMuted),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // Card Preview Area
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: RepaintBoundary(
                          key: cardBoundaryKey,
                          child: _buildDailyRateStoryCard(),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    child: Row(
                      children: [
                        // Copy Text Button
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              _copyRatesSummaryText();
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _l('Rates copied to clipboard!', 'ပေါက်ဈေးစာသား ကူးယူပြီးပါပြီ!', 'คัดลอกข้อความแล้ว!'),
                                    style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                  backgroundColor: _inkDark,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.copy_rounded, size: 16, color: _inkDark),
                                const SizedBox(width: 6),
                                Text(
                                  _l('Copy Text', 'စာသားယူမည်', 'คัดลอก'),
                                  style: AppFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _inkDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Share Image Button (Primary Gradient)
                        Expanded(
                          flex: 3,
                          child: PrimaryGradientButton(
                            height: 48,
                            borderRadius: BorderRadius.circular(16),
                            onPressed: isGenerating
                                ? () {}
                                : () async {
                                    setModalState(() => isGenerating = true);
                                    try {
                                      await _captureAndShareCard(cardBoundaryKey);
                                    } finally {
                                      if (mounted) {
                                        setModalState(() => isGenerating = false);
                                      }
                                    }
                                  },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isGenerating)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else ...[
                                  const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    _l('Share Image', 'ပုံဖြင့် မျှဝေမည်', 'แชร์รูปภาพ'),
                                    style: AppFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _captureAndShareCard(GlobalKey key) async {
    HapticFeedback.lightImpact();
    try {
      await Future.delayed(const Duration(milliseconds: 60));
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'mytogether_rates_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      final shareText = _buildShareSummaryText();
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: shareText,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing rate card image: $e');
    }
  }

  void _copyRatesSummaryText() {
    HapticFeedback.selectionClick();
    final text = _buildShareSummaryText();
    Clipboard.setData(ClipboardData(text: text));
  }

  String _buildShareSummaryText() {
    final dateStr = _timestamp.isNotEmpty
        ? _timestamp
        : DateFormat('dd MMM, hh:mm a').format(DateTime.now());
    final sb = StringBuffer();
    sb.writeln('🇲🇲 MyTogether - နေ့စဉ် ငွေလဲပေါက်ဈေး ($dateStr)');
    sb.writeln('──────────────────────');
    for (final r in _rates.take(8)) {
      sb.writeln(
          '${r.flagEmoji} ${r.currency}: ဝယ် ${_formatRate(r.buy)} | ရောင်း ${_formatRate(r.sell)} MMK');
    }
    sb.writeln('──────────────────────');
    sb.writeln('📌 ပေါက်ဈေးများ အချိန်နှင့်တစ်ပြေးညီ သိရှိရန် MyTogether App ကို ဒေါင်းလုဒ်လုပ်ပါ');
    return sb.toString();
  }

  Widget _buildDailyRateStoryCard() {
    final thbRate = _rates.firstWhere(
      (r) => r.currency == 'THB',
      orElse: () =>
          const CurrencyRateModel(currency: 'THB', buy: 141.5, sell: 143.6),
    );
    final usdRate = _rates.firstWhere(
      (r) => r.currency == 'USD',
      orElse: () =>
          const CurrencyRateModel(currency: 'USD', buy: 4726, sell: 4800),
    );

    final otherRates = _rates
        .where((r) => r.currency != 'THB' && r.currency != 'USD')
        .take(6)
        .toList();

    return Container(
      width: 320,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branding Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.currency_exchange_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MyTogether',
                        style: AppFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _inkDark,
                        ),
                      ),
                      Text(
                        'သင့်အနားမှာ အမြဲတူတူ',
                        style: AppFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Live Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _timestamp.isNotEmpty ? _timestamp : 'Live Rates',
                  style: AppFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Main 2 Big Currency Cards: THB and USD
          Row(
            children: [
              Expanded(
                child: _buildStoryRateTile(
                  flag: '🇹🇭',
                  code: 'THB',
                  name: 'Thai Baht',
                  buy: thbRate.buy,
                  sell: thbRate.sell,
                  accentColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStoryRateTile(
                  flag: '🇺🇸',
                  code: 'USD',
                  name: 'US Dollar',
                  buy: usdRate.buy,
                  sell: usdRate.sell,
                  accentColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Other Currencies Table
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < otherRates.length; i++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            otherRates[i].flagEmoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            otherRates[i].currency,
                            style: AppFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _inkDark,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'ဝယ် ${_formatRate(otherRates[i].buy)}',
                            style: AppFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ရောင်း ${_formatRate(otherRates[i].sell)}',
                            style: AppFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (i < otherRates.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Disclaimer & App Watermark Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '📌 ပြင်ပပေါက်ဈေး အနီးစပ်ဆုံး ခန့်မှန်းဈေးဖြစ်ပါသည်',
                    style: AppFonts.poppins(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: _textMuted,
                    ),
                  ),
                ),
                Text(
                  'MyTogether App',
                  style: AppFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryRateTile({
    required String flag,
    required String code,
    required String name,
    required double buy,
    required double sell,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: AppFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _inkDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ဝယ်',
                style: AppFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                ),
              ),
              Text(
                _formatRate(buy),
                style: AppFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _inkDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ရောင်း',
                style: AppFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                ),
              ),
              Text(
                _formatRate(sell),
                style: AppFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Error & Skeleton States
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.warningCircle,
                size: 40,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                color: _inkDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            PrimaryGradientButton(
              width: 140,
              height: 44,
              onPressed: () => _fetchRates(forceRefresh: true),
              child: Text(
                context.tr('common.retry'),
                style: AppFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return _ShimmerScope(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: _selectedTab == 0
                ? _buildCalculatorSkeleton()
                : _buildRatesDirectorySkeleton(),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 0: Calculator Skeleton
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildCalculatorSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Send & Receive Conversion Cards Skeleton
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                // Top Send Card Skeleton
                Container(
                  height: 104,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: _sendCardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
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
                        children: const [
                          _ShimmerBox(width: 72, height: 16, borderRadius: 6),
                          _ShimmerBox(width: 96, height: 32, borderRadius: 16),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          _ShimmerBox(width: 140, height: 26, borderRadius: 8),
                          _ShimmerBox(width: 44, height: 14, borderRadius: 4),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Bottom Receive Card Skeleton
                Container(
                  height: 104,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: _receiveCardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.22),
                    ),
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
                        children: const [
                          _ShimmerBox(width: 78, height: 16, borderRadius: 6),
                          _ShimmerBox(width: 96, height: 32, borderRadius: 16),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          _ShimmerBox(width: 120, height: 26, borderRadius: 8),
                          _ShimmerBox(width: 44, height: 14, borderRadius: 4),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Central Floating Swap Button Skeleton
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.secondary.withValues(alpha: 0.25),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.swap_vert_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 2. Rates Disclaimer Banner Skeleton
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.35),
                AppColors.secondary.withValues(alpha: 0.35),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: _ShimmerBox(
                  height: 12,
                  borderRadius: 6,
                  baseColor: Color(0x33FFFFFF),
                  highlightColor: Color(0x88FFFFFF),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 3. Rate Pattern Card Skeleton
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: _cardWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _borderLight),
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
              // Header title + range chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      _ShimmerBox(width: 28, height: 28, borderRadius: 8),
                      SizedBox(width: 8),
                      _ShimmerBox(width: 130, height: 18, borderRadius: 6),
                    ],
                  ),
                  const _ShimmerBox(width: 75, height: 32, borderRadius: 16),
                ],
              ),
              const SizedBox(height: 16),
              // Currency Pair Row [MMK] ⇄ [THB]
              Row(
                children: const [
                  _ShimmerBox(width: 92, height: 30, borderRadius: 14),
                  SizedBox(width: 8),
                  _ShimmerBox(width: 26, height: 26, borderRadius: 13),
                  SizedBox(width: 8),
                  _ShimmerBox(width: 92, height: 30, borderRadius: 14),
                ],
              ),
              const SizedBox(height: 12),
              // Rate headline subtitle
              const _ShimmerBox(width: 210, height: 14, borderRadius: 6),
              const SizedBox(height: 8),
              const _ShimmerBox(width: 170, height: 24, borderRadius: 8),
              const SizedBox(height: 16),
              // Graphic Chart Canvas area
              Container(
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: const Center(
                  child: _ShimmerBox(
                    width: double.infinity,
                    height: 170,
                    borderRadius: 16,
                    baseColor: Color(0xFFF1F5F9),
                    highlightColor: Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 1: Rates Directory Skeleton
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildRatesDirectorySkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Search Bar Skeleton (First)
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderLight),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: const [
              _ShimmerBox(width: 18, height: 18, borderRadius: 9),
              SizedBox(width: 10),
              _ShimmerBox(width: 160, height: 13, borderRadius: 5),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 2. Disclaimer Banner Skeleton (Second)
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.35),
                AppColors.secondary.withValues(alpha: 0.35),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: _ShimmerBox(
                  height: 12,
                  borderRadius: 6,
                  baseColor: Color(0x33FFFFFF),
                  highlightColor: Color(0x88FFFFFF),
                ),
              ),
            ],
          ),
        ),

        // Reduced spacing matching directory (8px)
        const SizedBox(height: 8),

        // 3. Rates Grid Skeleton (2 Columns)
        Builder(
          builder: (context) {
            final screenW = MediaQuery.of(context).size.width;
            final contentW = min(screenW, _maxContentWidth) - 32;
            final cardW = (contentW - 10) / 2;
            final childAspectRatio = (cardW / 126).clamp(1.10, 1.45);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) => _buildRateGridCardSkeleton(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRateGridCardSkeleton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Flag + Code + Country name + Arrow
          Row(
            children: [
              const _ShimmerBox(width: 24, height: 24, borderRadius: 12),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ShimmerBox(width: 38, height: 12, borderRadius: 3),
                    SizedBox(height: 3),
                    _ShimmerBox(width: 52, height: 9, borderRadius: 3),
                  ],
                ),
              ),
              const _ShimmerBox(width: 10, height: 10, borderRadius: 5),
            ],
          ),
          const Spacer(),
          // Unified Buy/Sell block skeleton
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _ShimmerBox(width: 34, height: 9, borderRadius: 3),
                    _ShimmerBox(width: 44, height: 11, borderRadius: 3),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _ShimmerBox(width: 34, height: 9, borderRadius: 3),
                    _ShimmerBox(width: 44, height: 11, borderRadius: 3),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 2: Verified Money Changers & Counters Directory (Feature #5)
  // ───────────────────────────────────────────────────────────────────────────

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 2: Dedicated Interactive Map View & Nearest Counters, Banks, ATMs
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildFullScreenMapTab() {
    final changers = _filteredMoneyChangers;
    _MoneyChangerCounter? selectedCounter;
    if (_selectedCounterId != null) {
      try {
        selectedCounter =
            _allMoneyChangers.firstWhere((c) => c.id == _selectedCounterId);
      } catch (_) {}
    }
    selectedCounter ??= changers.isNotEmpty ? changers.first : null;

    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // 1. Full View Google Map (100% full screen)
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userPosition != null
                  ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                  : (selectedCounter != null
                      ? LatLng(selectedCounter.latitude, selectedCounter.longitude)
                      : const LatLng(13.7462, 100.5348)),
              zoom: 14.0,
            ),
            myLocationEnabled: _userPosition != null,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            markers: _mapMarkers,
            padding: EdgeInsets.only(
              top: topInset + 106,
              bottom: 215,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _updateMapMarkers();
              if (_userPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                      zoom: 14.5,
                    ),
                  ),
                );
              }
            },
            onTap: (_) {
              FocusScope.of(context).unfocus();
            },
          ),
        ),

        // 2. Top Floating Header & Single Sleek Filter Bar (iOS Glass Blur)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(14, topInset + 6, 14, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.32),
                  Colors.black.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row 1: Back Button + Real OpenStreetMap Live Area Capsule
                Row(
                  children: [
                    // Back button (Frosted Glass Circle)
                    GestureDetector(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() => _selectedTab = 0);
                        }
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.85),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: _inkDark,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Frosted Glass Info Badge (OpenStreetMap Live + Location)
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(21),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(21),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.90),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.near_me_rounded,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _userAreaName != null && _userAreaName!.isNotEmpty
                                          ? _userAreaName!
                                          : _l(
                                              'Nearby Counters & ATMs',
                                              'နီးစပ်ရာ ငွေလဲကောင်တာနှင့် ATM များ',
                                              'เคาน์เตอร์แลกเงินและ ATM ใกล้เคียง',
                                            ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: _inkDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // OpenStreetMap Live Badge
                                  GestureDetector(
                                    onTap: () {
                                      if (_userPosition != null) {
                                        _fetchOsmNearbyCounters(
                                          _userPosition!.latitude,
                                          _userPosition!.longitude,
                                          force: true,
                                        );
                                      } else {
                                        _getUserLocation(requestIfDenied: true);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_isFetchingOsm)
                                            const SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.8,
                                                color: Color(0xFF10B981),
                                              ),
                                            )
                                          else
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'OSM Live',
                                            style: AppFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF047857),
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
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Row 2: ONE UNIFIED HORIZONTAL FILTER STRIP (iOS Frosted Glass)
                _buildUnifiedMapFilterStrip(changers.length),
              ],
            ),
          ),
        ),

        // 3. Floating Quick Action Controls (iOS Glass Blur Buttons on Right Side)
        Positioned(
          right: 14,
          bottom: 212,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fit all markers overview button
              GestureDetector(
                onTap: _fitAllMarkersToBounds,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.85),
                        child: const Center(
                          child: Icon(
                            Icons.fit_screen_rounded,
                            color: _inkDark,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // GPS Re-center button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _getUserLocation(requestIfDenied: true);
                  if (_userPosition != null && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(
                            _userPosition!.latitude,
                            _userPosition!.longitude,
                          ),
                          zoom: 14.5,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.85),
                        child: _isLocatingUser
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.my_location_rounded,
                                  size: 22,
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 4. Bottom Floating Controls (Carousel & Selected Preview Card)
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Horizontal Quick Carousel of Nearest Places (iOS Glass Blur)
              if (changers.length > 1) ...[
                _buildMapQuickChipsCarousel(changers),
                const SizedBox(height: 8),
              ],

              // Floating Selected Place Card (iOS Glass Blur Style)
              if (selectedCounter != null)
                _buildMapBottomCounterCard(selectedCounter)
              else if (changers.isEmpty)
                _buildNoMatchesCard(),
            ],
          ),
        ),
      ],
    );
  }

  void _fitAllMarkersToBounds() {
    final changers = _filteredMoneyChangers;
    if (changers.isEmpty || _mapController == null) return;
    HapticFeedback.selectionClick();
    if (changers.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(changers.first.latitude, changers.first.longitude),
          15.0,
        ),
      );
      return;
    }
    double minLat = changers.first.latitude;
    double maxLat = changers.first.latitude;
    double minLng = changers.first.longitude;
    double maxLng = changers.first.longitude;

    for (final c in changers) {
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLng) minLng = c.longitude;
      if (c.longitude > maxLng) maxLng = c.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        55.0,
      ),
    );
  }

  Widget _buildMapQuickChipsCarousel(List<_MoneyChangerCounter> changers) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: changers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final counter = changers[index];
          final isSelected = counter.id == _selectedCounterId;
          final distKm = counter.distanceTo(_userPosition);
          final distText = distKm < 1.0
              ? '${(distKm * 1000).round()} m'
              : (distKm < 100 ? '${distKm.toStringAsFixed(1)} km' : '${distKm.toInt()} km');

          Color catDotColor;
          if (counter.category == 'bank') {
            catDotColor = const Color(0xFF059669);
          } else if (counter.category == 'atm') {
            catDotColor = const Color(0xFF0284C7);
          } else {
            catDotColor = const Color(0xFFFF5E00);
          }

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedCounterId = counter.id;
              });
              _updateMapMarkers();
              if (_mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(counter.latitude, counter.longitude),
                    15.0,
                  ),
                );
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.88),
                      width: isSelected ? 1.8 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isSelected ? 0.16 : 0.06),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (counter.logoAsset != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            counter.logoAsset!,
                            width: 16,
                            height: 16,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ] else ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: catDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        counter.brandName,
                        maxLines: 1,
                        style: AppFonts.poppins(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: _inkDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _userPosition != null
                              ? const Color(0xFFDCFCE7).withValues(alpha: 0.9)
                              : _surfaceSoft.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          distText,
                          style: AppFonts.poppins(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _userPosition != null
                                ? const Color(0xFF15803D)
                                : _textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnifiedMapFilterStrip(int currentCount) {
    final allList = _allMoneyChangers;
    final allCount = allList.length;
    int exchangeCount = 0;
    int bankCount = 0;
    int atmCount = 0;
    for (final c in allList) {
      if (c.category == 'exchange') {
        exchangeCount++;
      } else if (c.category == 'bank') {
        bankCount++;
      } else if (c.category == 'atm') {
        atmCount++;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildCategoryPill(
            id: 'all',
            label: _l('All', 'အားလုံး', 'ทั้งหมด'),
            count: allCount,
            icon: Icons.layers_rounded,
          ),
          const SizedBox(width: 6),
          _buildCategoryPill(
            id: 'exchange',
            label: _l('Exchanges', 'ငွေလဲဆိုင်', 'ร้านแลกเงิน'),
            count: exchangeCount,
            icon: Icons.currency_exchange_rounded,
            iconColor: const Color(0xFFFF5E00),
          ),
          const SizedBox(width: 6),
          _buildCategoryPill(
            id: 'bank',
            label: _l('Banks', 'ဘဏ်ခွဲများ', 'สาขาธนาคาร'),
            count: bankCount,
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFF059669),
          ),
          const SizedBox(width: 6),
          _buildCategoryPill(
            id: 'atm',
            label: _l('ATMs', 'ATM စက်', 'ตู้ ATM'),
            count: atmCount,
            icon: Icons.local_atm_rounded,
            iconColor: const Color(0xFF0284C7),
          ),
          Container(
            height: 18,
            width: 1.2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withValues(alpha: 0.60),
          ),
          _buildDistanceDropdownPill(),
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    Color? iconColor,
  }) {
    final isSelected = _selectedCategory == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedCategory = id;
          _selectedCounterId = null;
        });
        _updateMapMarkers();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: isSelected ? AppColors.primaryGradient : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.90),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.32)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? Colors.white
                      : (iconColor ?? _textMuted),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: AppFonts.poppins(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : _inkDark,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: AppFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : _textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceDropdownPill() {
    final isCustomRadius = _selectedRadiusKm != 10;
    final currentLabel = _selectedRadiusKm == 0
        ? _l('All Dist', 'အကွာအဝေးအားလုံး', 'ทุกระยะ')
        : _l('$_selectedRadiusKm km', '$_selectedRadiusKm km', '$_selectedRadiusKm กม.');

    return PopupMenuButton<int>(
      initialValue: _selectedRadiusKm,
      tooltip: _l('Distance filter', 'အကွာအဝေး ရွေးချယ်ရန်', 'เลือกระยะทาง'),
      offset: const Offset(0, 40),
      elevation: 8,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: (radius) {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedRadiusKm = radius;
        });
        _updateMapMarkers();
        if (_userPosition != null) {
          _fetchOsmNearbyCounters(
            _userPosition!.latitude,
            _userPosition!.longitude,
            radiusKm: radius > 0 ? radius.toDouble() : 10.0,
          );
        }
      },
      itemBuilder: (context) => [
        _buildDistanceMenuItem(
          value: 5,
          title: _l('5 km (Nearby)', '၅ km အတွင်း (အနီးဆုံး)', '5 กม. (ใกล้สุด)'),
          icon: Icons.directions_walk_rounded,
        ),
        _buildDistanceMenuItem(
          value: 10,
          title: _l('10 km (Standard)', '၁၀ km အတွင်း (ပုံမှန်)', '10 กม. (มาตรฐาน)'),
          icon: Icons.near_me_rounded,
        ),
        _buildDistanceMenuItem(
          value: 25,
          title: _l('25 km (City Wide)', '၂၅ km အတွင်း (မြို့တွင်း)', '25 กม. (รอบเมือง)'),
          icon: Icons.directions_car_rounded,
        ),
        _buildDistanceMenuItem(
          value: 0,
          title: _l('All Distances', 'အကွာအဝေးအားလုံး', 'ทุกระยะทาง'),
          icon: Icons.public_rounded,
        ),
      ],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isCustomRadius
                  ? _inkDark
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: isCustomRadius
                    ? _inkDark
                    : Colors.white.withValues(alpha: 0.90),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.near_me_rounded,
                  size: 13,
                  color: isCustomRadius ? Colors.white : AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  currentLabel,
                  style: AppFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCustomRadius ? Colors.white : _inkDark,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: isCustomRadius
                      ? Colors.white.withValues(alpha: 0.8)
                      : _textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<int> _buildDistanceMenuItem({
    required int value,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedRadiusKm == value;
    return PopupMenuItem<int>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.primary : _textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : _inkDark,
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              size: 17,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildNoMatchesCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.90),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: _textMuted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _l(
                      'No locations match current filter.',
                      'ရှာဖွေမှုနှင့် ကိုက်ညီသော နေရာ မတွေ့ပါ။',
                      'ไม่พบสถานที่',
                    ),
                    style: AppFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _inkDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = 'all';
                      _selectedRadiusKm = 0;
                    });
                    _updateMapMarkers();
                  },
                  child: Text(
                    _l('Reset', 'ပြန်စမည်', 'รีเซ็ต'),
                    style: AppFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapBottomCounterCard(_MoneyChangerCounter counter) {
    final distKm = counter.distanceTo(_userPosition);
    final distText = distKm < 1.0
        ? '${(distKm * 1000).round()} m'
        : (distKm < 100 ? '${distKm.toStringAsFixed(1)} km' : '${distKm.toInt()} km');

    Color catColor;
    IconData catIcon;
    String catLabel;

    switch (counter.category) {
      case 'bank':
        catColor = const Color(0xFF059669);
        catIcon = Icons.account_balance_rounded;
        catLabel = _l('Official Bank', 'တရားဝင် ဘဏ်ခွဲ', 'สาขาธนาคาร');
        break;
      case 'atm':
        catColor = const Color(0xFF0284C7);
        catIcon = Icons.atm_rounded;
        catLabel = _l('24/7 ATM', '24/7 နိုင်ငံတကာ ATM', 'ตู้ ATM 24 ชม.');
        break;
      case 'exchange':
      default:
        catColor = const Color(0xFFFF5E00);
        catIcon = Icons.currency_exchange_rounded;
        catLabel = _l('Money Exchange', 'တရားဝင် ငွေလဲဆိုင်', 'ร้านแลกเงิน');
        break;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: catColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.90),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row: Avatar, Brand, Branch, Distance Badge
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: catColor.withValues(alpha: 0.16),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(5.0),
                              child: counter.logoAsset != null
                                  ? Image.asset(
                                      counter.logoAsset!,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                  : Center(
                                      child: Icon(
                                        catIcon,
                                        color: catColor,
                                        size: 22,
                                      ),
                                    ),
                            ),
                            if (counter.category == 'atm')
                              Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3.5,
                                    vertical: 1.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ATM',
                                    style: TextStyle(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                              Flexible(
                                child: Text(
                                  counter.brandName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: _inkDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: Color(0xFF0284C7),
                              ),
                            ],
                          ),
                          Text(
                            counter.branchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(
                              fontSize: 11,
                              color: _textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Distance Chip (iOS Frosted Pill)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _userPosition != null
                            ? const Color(0xFFDCFCE7).withValues(alpha: 0.90)
                            : Colors.white.withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _userPosition != null
                              ? const Color(0xFF86EFAC).withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 11,
                            color: _userPosition != null
                                ? const Color(0xFF15803D)
                                : _textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            distText,
                            style: AppFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _userPosition != null
                                  ? const Color(0xFF15803D)
                                  : _inkDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Middle Info Row (Rates / ATM / Status in Frosted Pill)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.90),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (counter.category == 'atm') ...[
                        const Icon(
                          Icons.credit_card_rounded,
                          size: 13,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Visa • Mastercard • 220 THB Fee',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _inkDark,
                            ),
                          ),
                        ),
                      ] else if (counter.thbToMmkBuy > 0) ...[
                        Text(
                          'THB/MMK: ',
                          style: AppFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                        Text(
                          '${counter.thbToMmkBuy.toStringAsFixed(2)} / ${counter.thbToMmkSell.toStringAsFixed(2)}',
                          style: AppFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                        const Spacer(),
                      ] else ...[
                        const Icon(
                          Icons.account_balance_rounded,
                          size: 13,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            catLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _inkDark,
                            ),
                          ),
                        ),
                      ],

                      // Open Status indicator
                      if (counter.openHours.isNotEmpty) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: counter.isOpenNow
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          counter.isOpenNow
                              ? _l('Open', 'ဖွင့်ဆဲ', 'เปิด')
                              : _l('Closed', 'ပိတ်သည်', 'ปิด'),
                          style: AppFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: counter.isOpenNow
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Actions Row (Directions, Call, Details in Frosted Glass Buttons)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () => _openMaps(counter.mapQuery),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.directions_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _l('Directions', 'လမ်းညွှန်', 'นำทาง'),
                                style: AppFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (counter.phone.isNotEmpty && counter.phone != '1333') ...[
                      const SizedBox(width: 7),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () => _makePhoneCall(counter.phone),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.70),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.95),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.phone_rounded, size: 13, color: _inkDark),
                                const SizedBox(width: 3),
                                Text(
                                  _l('Call', 'ဖုန်း', 'โทร'),
                                  style: AppFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _inkDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 7),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () => _showCounterDetailSheet(counter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.95),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _l('Details', 'အသေးစိတ်', 'รายละเอียด'),
                              style: AppFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _inkDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCounterDetailSheet(_MoneyChangerCounter counter) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        Color catColor;
        IconData catIcon;
        String catBadgeText;
        switch (counter.category) {
          case 'bank':
            catColor = const Color(0xFF059669);
            catIcon = Icons.account_balance_rounded;
            catBadgeText = _l('Official Bank', 'တရားဝင် ဘဏ်ခွဲကြီး', 'สาขาธนาคาร');
            break;
          case 'atm':
            catColor = const Color(0xFF0284C7);
            catIcon = Icons.atm_rounded;
            catBadgeText = _l('24/7 ATM', '24/7 နိုင်ငံတကာ ATM', 'ตู้ ATM 24 ชม.');
            break;
          case 'exchange':
          default:
            catColor = const Color(0xFFFF5E00);
            catIcon = Icons.currency_exchange_rounded;
            catBadgeText = _l('Licensed Exchange', 'တရားဝင် ငွေလဲဆိုင်', 'ร้านแลกเงิน');
            break;
        }

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: catColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: catColor.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: counter.logoAsset != null
                              ? Image.asset(
                                  counter.logoAsset!,
                                  fit: BoxFit.contain,
                                )
                              : Center(
                                  child: Icon(
                                    catIcon,
                                    color: catColor,
                                    size: 24,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  counter.brandName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.poppins(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: _inkDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: Color(0xFF0284C7),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  catBadgeText,
                                  style: AppFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: catColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  counter.branchName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.poppins(
                                    fontSize: 11.5,
                                    color: _textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: _borderLight),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Address card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surfaceSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _l('Location & Address', 'တည်နေရာနှင့် လိပ်စာ', 'ที่อยู่และสถานที่ตั้ง'),
                                  style: AppFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _inkDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              counter.fullAddress,
                              style: AppFonts.poppins(
                                fontSize: 12,
                                color: _inkDark,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '📍 ${counter.landmark}',
                              style: AppFonts.poppins(
                                fontSize: 11.5,
                                color: _textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ATM Supported Cards & Limits Section (if category == 'atm')
                      if (counter.category == 'atm') ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.credit_card_rounded,
                                    size: 16,
                                    color: Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _l('Supported Card Networks', 'အသုံးပြုနိုင်သော ကတ်အမျိုးအစားများ', 'บัตรที่รองรับ'),
                                    style: AppFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0369A1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: counter.supportedCards.map((card) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFBAE6FD)),
                                    ),
                                    child: Text(
                                      card,
                                      style: AppFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0369A1),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _l('Withdrawal Limit:', 'အများဆုံး ထုတ်ယူမှု -', 'วงเงินถอนสูงสุด:'),
                                      style: AppFonts.poppins(
                                        fontSize: 11.5,
                                        color: _textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      counter.withdrawalLimit ?? '30,000 THB / tx',
                                      style: AppFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: _inkDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _l('Thai ATM Fee:', 'ထိုင်းဘဏ် ATM ဝန်ဆောင်ခ -', 'ค่าธรรมเนียมตู้:'),
                                      style: AppFonts.poppins(
                                        fontSize: 11.5,
                                        color: _textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      counter.atmFee ?? '220 THB / withdrawal',
                                      style: AppFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Rates Section (if category == 'exchange')
                      if (counter.category == 'exchange' && counter.thbToMmkBuy > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFED7AA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.currency_exchange_rounded,
                                    size: 16,
                                    color: Color(0xFFEA580C),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _l('Live Rates at Counter', 'ဆိုင်ပေါက်ဈေး နှုန်းထားများ', 'เรทราคาหน้าร้าน'),
                                    style: AppFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFC2410C),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'THB → MMK (Buy)',
                                            style: AppFonts.poppins(fontSize: 10, color: _textMuted),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            counter.thbToMmkBuy.toStringAsFixed(2),
                                            style: AppFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFFEA580C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'THB → MMK (Sell)',
                                            style: AppFonts.poppins(fontSize: 10, color: _textMuted),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            counter.thbToMmkSell.toStringAsFixed(2),
                                            style: AppFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFFEA580C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Business Hours & Phone
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surfaceSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: Color(0xFF059669),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _l('Operating Hours', 'ဖွင့်ချိန်/ပိတ်ချိန်', 'เวลาทำการ'),
                                  style: AppFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _inkDark,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  counter.openHours,
                                  style: AppFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            if (counter.phone.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_rounded,
                                    size: 16,
                                    color: _textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _l('Phone', 'ဖုန်းနံပါတ်', 'เบอร์โทรศัพท์'),
                                    style: AppFonts.poppins(
                                      fontSize: 12,
                                      color: _textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    counter.phone,
                                    style: AppFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _inkDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Tips & Regulations Notes
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 16,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _l('Important Notes & Tips', 'အရေးကြီး သိမှတ်ဖွယ်ရာ', 'ข้อแนะนำสำคัญ'),
                                  style: AppFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              counter.exchangeTips,
                              style: AppFonts.poppins(
                                fontSize: 11.5,
                                color: const Color(0xFF78350F),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action Buttons: Google Maps & Call
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(sheetCtx).pop();
                                _openMaps(counter.mapQuery);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.map_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _l('Open in Google Maps', 'Google Maps ဖြင့် သွားရန်', 'เปิดใน Google Maps'),
                                      style: AppFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (counter.phone.isNotEmpty && counter.phone != '1333') ...[
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () => _makePhoneCall(counter.phone),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _surfaceSoft,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _borderLight),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.phone_rounded,
                                        color: _inkDark,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _l('Call', 'ဖုန်းခေါ်', 'โทร'),
                                        style: AppFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _inkDark,
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExchangeGuidelinesModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _l(
                              'Money Exchange Guide & Tips',
                              'ငွေလဲလှယ်ရာတွင် သိကောင်းစရာများ',
                              'คำแนะนำและข้อควรรู้ในการแลกเงิน',
                            ),
                            style: AppFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _inkDark,
                            ),
                          ),
                          Text(
                            _l(
                              'Bank of Thailand regulations & safety',
                              'ထိုင်းဗဟိုဘဏ် စည်းမျဉ်းနှင့် ဘေးကင်းလုံခြုံရေး',
                              'ข้อบังคับ ธปท. และความปลอดภัย',
                            ),
                            style: AppFonts.poppins(
                              fontSize: 11.5,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _borderLight),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildExchangeTipRow(
                        number: '1',
                        title: _l(
                          'Bring Original Passport or ID',
                          'Passport မူရင်း သို့မဟုတ် တရားဝင်ကတ် မဖြစ်မနေ ယူဆောင်ပါ',
                          'พกพาสปอร์ตหรือบัตรประชาชนตัวจริง',
                        ),
                        description: _l(
                          'Under Thai AML/BOT law, money counters must verify your identity. Expats must present original Passport, Pink Card, or CI.',
                          'ထိုင်းနိုင်ငံငွေကြေးဥပဒေအရ တရားဝင်ကောင်တာများတွင် Passport မူရင်း သို့မဟုတ် ပန်းရောင်ကတ် / CI ပြသရပါမည်။',
                          'กฎหมายกำหนดให้ยืนยันตัวตนด้วยหนังสือเดินทางหรือบัตรประชาชน',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildExchangeTipRow(
                        number: '2',
                        title: _l(
                          'Keep Banknotes Clean & Intact',
                          'ငွေစက္ကူများ စုတ်ပြဲ/မှင်စွန်း ကင်းရှင်းစေရန် စစ်ဆေးပါ',
                          'ธนบัตรต้องสมบูรณ์ ไม่ชำรุด',
                        ),
                        description: _l(
                          'Counters may reject or deduct commission for torn, heavily stained, or folded notes (especially USD and MMK).',
                          'အထူးသဖြင့် USD သို့မဟုတ် MMK စက္ကူများ စုတ်ပြဲခြင်း၊ မှင်စွန်းခြင်းရှိပါက ဈေးနှိမ်ခံရခြင်း သို့မဟုတ် ငြင်းပယ်ခံရနိုင်ပါသည်။',
                          'ธนบัตรที่มีรอยฉีกขาดหรือรอยหมึกอาจถูกปฏิเสธหรือไม่รับแลก',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildExchangeTipRow(
                        number: '3',
                        title: _l(
                          'Count Cash & Inspect Receipt On-Site',
                          'ငွေနှင့် ပြေစာကို ကောင်တာရှေ့တွင် ချက်ချင်း စစ်ဆေးပါ',
                          'ตรวจนับเงินและใบเสร็จหน้าเคาน์เตอร์',
                        ),
                        description: _l(
                          'Always verify banknotes count and keep your official exchange receipt before leaving the counter window.',
                          'ကောင်တာမှ မထွက်ခွာမီ ငွေပမာဏမှန်ကန်မှုနှင့် တရားဝင်ပြေစာ (Official Receipt) ကို မျက်မှောက်တွင် သေချာစစ်ဆေးသိမ်းဆည်းပါ။',
                          'นับเงินให้ครบถ้วนและเก็บใบเสร็จไว้เป็นหลักฐาน',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildExchangeTipRow(
                        number: '4',
                        title: _l(
                          'Compare Buying / Selling Spreads',
                          'ဝယ်ဈေး / ရောင်းဈေး ကွာဟချက်ကို ကြည့်ရှုပါ',
                          'ตรวจสอบส่วนต่างราคาซื้อ-ขาย',
                        ),
                        description: _l(
                          'SuperRich 1965 (Orange) and SuperRich Thailand (Green) offer the tightest margins and best rates for foreign currencies.',
                          'SuperRich Orange နှင့် Green ဆိုင်များသည် spread အနည်းဆုံးဖြစ်ပြီး ပေါက်ဈေး အကောင်းဆုံး ရရှိနိုင်ပါသည်။',
                          'SuperRich มักให้เรทราคาที่คุ้มค่าที่สุด',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExchangeTipRow({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _inkDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: AppFonts.poppins(
                  fontSize: 11.5,
                  color: _textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Navigation & Calling Utilities
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _openMaps(String query) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Money Changers Dataset & Filtering
  // ───────────────────────────────────────────────────────────────────────────

  List<_MoneyChangerCounter> get _allMoneyChangers {
    if (_cachedAllCounters != null &&
        _lastCachedUserPosition == _userPosition &&
        _lastCachedAreaName == _userAreaName) {
      return _cachedAllCounters!;
    }

    _lastCachedUserPosition = _userPosition;
    _lastCachedAreaName = _userAreaName;

    // 1. Prioritize real live OpenStreetMap (OSM) places if loaded
    if (_osmNearbyCounters.isNotEmpty) {
      final osmIds = _osmNearbyCounters.map((c) => c.id).toSet();
      final flagships = _curatedFlagshipCounters.where((c) => !osmIds.contains(c.id)).toList();
      _cachedAllCounters = [..._osmNearbyCounters, ...flagships];
      return _cachedAllCounters!;
    }

    // 2. Fallback to location-based / curated counters
    if (_userPosition != null) {
      final userLat = _userPosition!.latitude;
      final userLng = _userPosition!.longitude;

      // Distance from Bangkok CentralWorld / Siam
      final distToSiam = Geolocator.distanceBetween(
            userLat,
            userLng,
            13.7462,
            100.5348,
          ) /
          1000.0;

      if (distToSiam <= 3.0) {
        _cachedAllCounters = _curatedFlagshipCounters;
      } else {
        final nearby = _generateNearbyCounters(
          userLat,
          userLng,
          areaName: _userAreaName,
        );
        _cachedAllCounters = [...nearby, ..._curatedFlagshipCounters];
      }
    } else {
      _cachedAllCounters = _curatedFlagshipCounters;
    }
    return _cachedAllCounters!;
  }

  List<_MoneyChangerCounter> _generateNearbyCounters(
    double centerLat,
    double centerLng, {
    String? areaName,
  }) {
    final areaLabel = areaName != null && areaName.isNotEmpty
        ? areaName
        : _l('Local Area', 'နီးစပ်ရာ', 'พื้นที่ใกล้เคียง');

    return [
      // ═════════════════════════════════════════════════════════════════════════
      // 1. NEARBY OFFICIAL BANKS (Real bank logos)
      // ═════════════════════════════════════════════════════════════════════════
      _MoneyChangerCounter(
        id: 'dyn_kbank_branch',
        logoAsset: 'assets/images/banks/KBANK.png',
        category: 'bank',
        brandName: 'Kasikorn Bank (KBank)',
        branchName: _l(
          '$areaLabel Branch (FX Desk)',
          '$areaLabel KBank ဘဏ်ခွဲ (ငွေလဲကောင်တာ)',
          'สาขา$areaLabel (แลกเปลี่ยนเงิน)',
        ),
        area: areaLabel,
        landmark: _l(
          'Nearby Commercial Center • Full FX & Banking',
          'အနီးဆုံး စီးပွားရေးဇုန် • ဘဏ်လုပ်ငန်း & ငွေလဲဌာန',
          'ศูนย์การค้า • เคาน์เตอร์ครบวงจร',
        ),
        defaultDistanceKm: 0.45,
        latitude: centerLat - 0.0028,
        longitude: centerLng + 0.0031,
        openHours: '09:00 - 18:00',
        isOpenNow: true,
        phone: '+6628888888',
        mapQuery: 'Kasikorn Bank near me',
        brandColor: const Color(0xFF059669),
        tags: [
          _l('Official Bank', 'တရားဝင် ဘဏ်ခွဲ', 'ธนาคารพาณิชย์'),
          _l('FX Counter', 'နိုင်ငံခြားငွေလဲ ကောင်တာ', 'เคาน์เตอร์แลกเงิน'),
          _l('Near You', 'အနီးဆုံး ၄၅၀ မီတာ', 'ใกล้คุณ 450 ม.'),
        ],
        fullAddress: '$areaLabel, Thailand',
        exchangeTips: _l(
          'Official Kasikorn Bank branch near your location. Foreign currency exchange and remittance services. Passport required.',
          'မိမိအနီးဆုံး တရားဝင် KBank ဘဏ်ခွဲဖြစ်ပြီး နိုင်ငံခြားငွေလဲလှယ်ခြင်းနှင့် ဘဏ်လုပ်ငန်းများ ဆောင်ရွက်နိုင်ပါသည်။ Passport ယူဆောင်လာရန် လိုအပ်ပါသည်။',
          'บริการแลกเปลี่ยนเงินตราต่างประเทศ ต้องแสดงหนังสือเดินทาง',
        ),
      ),
      _MoneyChangerCounter(
        id: 'dyn_bbl_branch',
        logoAsset: 'assets/images/banks/BBL.png',
        category: 'bank',
        brandName: 'Bangkok Bank (BBL)',
        branchName: _l(
          '$areaLabel Branch',
          '$areaLabel Bangkok Bank ဘဏ်ခွဲ',
          'ธนาคารกรุงเทพ สาขา$areaLabel',
        ),
        area: areaLabel,
        landmark: _l(
          'Avenue Branch • Foreign Exchange Desk',
          'အဓိကလမ်းမကြီး • နိုင်ငံခြားငွေလဲဌာန',
          'สาขาหลัก ริมถนนใหญ่',
        ),
        defaultDistanceKm: 0.95,
        latitude: centerLat + 0.0062,
        longitude: centerLng + 0.0068,
        openHours: '09:00 - 18:00',
        isOpenNow: true,
        phone: '+6626455555',
        mapQuery: 'Bangkok Bank near me',
        brandColor: const Color(0xFF1E3A8A),
        tags: [
          _l('Top Bank', 'ထိုင်းအကြီးဆုံးဘဏ်', 'ธนาคารกรุงเทพ'),
          _l('FX Desk', 'နိုင်ငံခြားငွေလဲ ဝန်ဆောင်မှု', 'บริการแลกเงิน'),
          _l('950m Away', '၉၅၀ မီတာ အကွာ', '950 ม.'),
        ],
        fullAddress: '$areaLabel, Thailand',
        exchangeTips: _l(
          'Authorized Bangkok Bank branch. Full FX counter and foreign card assistance. Passport required.',
          'Bangkok Bank ဘဏ်ခွဲဖြစ်ပြီး နိုင်ငံခြားငွေ လဲလှယ်နိုင်ပါသည်။ Passport ပြသရန် လိုအပ်ပါသည်။',
          'บริการแลกเปลี่ยนเงินตราต่างประเทศ ต้องแสดงหนังสือเดินทาง',
        ),
      ),
      _MoneyChangerCounter(
        id: 'dyn_scb_branch',
        logoAsset: 'assets/images/banks/SCB.png',
        category: 'bank',
        brandName: 'Siam Commercial Bank (SCB)',
        branchName: _l(
          '$areaLabel Branch',
          '$areaLabel SCB ဘဏ်ခွဲ',
          'ธนาคารไทยพาณิชย์ สาขา$areaLabel',
        ),
        area: areaLabel,
        landmark: _l(
          'Shopping Center • Open 7 Days',
          'စတိုးဆိုင်တွင်း • စနေ/တနင်္ဂနွေ ဖွင့်သည်',
          'ในห้าง • เปิดทุกวัน',
        ),
        defaultDistanceKm: 1.5,
        latitude: centerLat - 0.0110,
        longitude: centerLng - 0.0095,
        openHours: '10:00 - 19:30',
        isOpenNow: true,
        phone: '+6627777777',
        mapQuery: 'SCB Bank near me',
        brandColor: const Color(0xFF4F46E5),
        tags: [
          _l('SCB Official', 'SCB တရားဝင်ဘဏ်', 'ธนาคารไทยพาณิชย์'),
          _l('Open 7 Days', 'စနေ/တနင်္ဂနွေ ဖွင့်သည်', 'เปิดทุกวัน'),
        ],
        fullAddress: '$areaLabel, Thailand',
        exchangeTips: _l(
          'Authorized SCB branch. Foreign exchange counter. Passport required.',
          'SCB တရားဝင်ဘဏ်ခွဲဖြစ်ပြီး နိုင်ငံခြားငွေလဲလှယ်နိုင်ပါသည်။ Passport မူရင်း ပြသရန် လိုအပ်ပါသည်။',
          'บริการแลกเงินและธุรกรรมธนาคาร ต้องใช้พาสปอร์ต',
        ),
      ),
      _MoneyChangerCounter(
        id: 'dyn_ktb_branch',
        logoAsset: 'assets/images/banks/KTB.png',
        category: 'bank',
        brandName: 'Krungthai Bank (KTB)',
        branchName: _l(
          '$areaLabel Center Branch',
          '$areaLabel Krungthai ဘဏ်ခွဲ',
          'ธนาคารกรุงไทย สาขา$areaLabel',
        ),
        area: areaLabel,
        landmark: _l(
          'State Bank Security • Foreign Exchange Counter',
          'အစိုးရဘဏ် စိတ်ချရမှု • နိုင်ငံခြားငွေလဲ ကောင်တာ',
          'บริการครบวงจร',
        ),
        defaultDistanceKm: 2.8,
        latitude: centerLat + 0.0190,
        longitude: centerLng - 0.0175,
        openHours: '08:30 - 16:30',
        isOpenNow: true,
        phone: '+6621111111',
        mapQuery: 'Krungthai Bank near me',
        brandColor: const Color(0xFF0284C7),
        tags: [
          _l('State Bank', 'အစိုးရဘဏ်ကြီး', 'ธนาคารกรุงไทย'),
          _l('Official FX', 'တရားဝင်ငွေလဲဌာန', 'เคาน์เตอร์แลกเงิน'),
        ],
        fullAddress: '$areaLabel, Thailand',
        exchangeTips: _l(
          'Official Krungthai Bank branch. Foreign exchange counter. Passport required.',
          'ထိုင်းအစိုးရပိုင် Krungthai ဘဏ်ခွဲဖြစ်ပြီး နိုင်ငံခြားငွေလဲလှယ်နိုင်ပါသည်။ Passport မူရင်း လိုအပ်ပါသည်။',
          'ธนาคารกรุงไทย ต้องใช้พาสปอร์ต',
        ),
      ),

      // ═════════════════════════════════════════════════════════════════════════
      // 2. NEARBY 24/7 GLOBAL ATMs (Real bank logos with ATM badge)
      // ═════════════════════════════════════════════════════════════════════════
      _MoneyChangerCounter(
        id: 'dyn_kbank_atm',
        logoAsset: 'assets/images/banks/KBANK.png',
        category: 'atm',
        brandName: 'KBank Global 24/7 ATM',
        branchName: _l(
          'Nearby Station / Store ATM (220m)',
          'အနီးဆုံး စတိုးဆိုင်/ဘူတာ ATM (၂၂၀ မီတာ)',
          'ตู้ ATM กสิกรไทย ใกล้ฉัน (220 ม.)',
        ),
        area: areaLabel,
        landmark: _l(
          'Walking 3 Mins • 24 Hours Cash Withdrawal',
          'လမ်းလျှောက် ၃ မိနစ် • ၂၄ နာရီ ငွေထုတ်နိုင်',
          'เดิน 3 นาที • บริการ 24 ชั่วโมง',
        ),
        defaultDistanceKm: 0.22,
        latitude: centerLat + 0.0012,
        longitude: centerLng + 0.0016,
        openHours: '24 Hours (နေ့ရောညပါ)',
        isOpenNow: true,
        phone: '1333',
        mapQuery: 'KBank ATM near me',
        brandColor: const Color(0xFF0284C7),
        supportedCards: ['Visa', 'Mastercard', 'JCB', 'UnionPay', 'Cirrus', 'Plus'],
        withdrawalLimit: '30,000 THB / Transaction',
        atmFee: '220 THB',
        tags: [
          _l('24/7 ATM', '၂၄ နာရီငွေထုတ်စက်', 'ATM 24 ชม.'),
          _l('Foreign Cards', 'နိုင်ငံတကာကတ်များ သုံးနိုင်', 'รับบัตรต่างประเทศ'),
          _l('Walking 3m', 'လမ်းလျှောက် ၃ မိနစ်', 'เดิน 3 นาที'),
        ],
        fullAddress: 'Nearby Store / Transit Point, $areaLabel',
        exchangeTips: _l(
          '24/7 ATM accepting Visa, Mastercard, JCB, and UnionPay. Standard Thai ATM operator fee of 220 THB applies. Select "Without Conversion" for best rate.',
          'Visa, Mastercard, JCB, UnionPay စသည့် နိုင်ငံတကာကတ်များဖြင့် ၂၄ နာရီ ငွေထုတ်နိုင်ပါသည်။ တစ်ကြိမ်လျှင် ၂၂၀ ဘတ် ဝန်ဆောင်ခ ဖြတ်တောက်ပါသည်။ စက်ပေါ်တွင် "Without Conversion" (THB သာ) ရွေးချယ်ပါက အသက်သာဆုံး ဖြစ်ပါသည်။',
          'ตู้เอทีเอ็ม 24 ชั่วโมง รับบัตรสากลทุกประเภท',
        ),
      ),
      _MoneyChangerCounter(
        id: 'dyn_bbl_atm',
        logoAsset: 'assets/images/banks/BBL.png',
        category: 'atm',
        brandName: 'Bangkok Bank 24/7 ATM',
        branchName: _l(
          'Community Corner 24/7 ATM (650m)',
          'နီးစပ်ရာ လမ်းဆုံ ၂၄ နာရီ ATM (၆၅၀ မီတာ)',
          'ตู้ ATM ธนาคารกรุงเทพ (650 ม.)',
        ),
        area: areaLabel,
        landmark: _l(
          'Convenience Stand • 24/7 Cash Access',
          'စတိုးဆိုင်အနီး • ၂၄ နာရီ ငွေသားထုတ်ယူနိုင်',
          'เปิด 24 ชม.',
        ),
        defaultDistanceKm: 0.65,
        latitude: centerLat - 0.0045,
        longitude: centerLng - 0.0042,
        openHours: '24 Hours (နေ့ရောညပါ)',
        isOpenNow: true,
        phone: '1333',
        mapQuery: 'Bangkok Bank ATM near me',
        brandColor: const Color(0xFF0284C7),
        supportedCards: ['Visa', 'Mastercard', 'JCB', 'UnionPay', 'Plus'],
        withdrawalLimit: '30,000 THB / Transaction',
        atmFee: '220 THB',
        tags: [
          _l('24/7 ATM', '၂၄ နာရီငွေထုတ်စက်', 'ATM 24 ชม.'),
          _l('High Cash Limit', 'ငွေသားအများအပြားထုတ်နိုင်', 'วงเงินสูง'),
        ],
        fullAddress: 'Community Center, $areaLabel',
        exchangeTips: _l(
          'Supports foreign debit & credit cards. Choose "Without Conversion" for bank exchange rate.',
          'နိုင်ငံတကာ Debit/Credit ကတ်များ သုံးနိုင်ပါသည်။ စက်ပေါ်တွင် "Without Conversion" (THB သာ) ရွေးချယ်ပါက အသက်သာဆုံး ဖြစ်ပါသည်။',
          'ตู้เอทีเอ็มรองรับบัตรต่างประเทศ',
        ),
      ),
      _MoneyChangerCounter(
        id: 'dyn_scb_atm',
        logoAsset: 'assets/images/banks/SCB.png',
        category: 'atm',
        brandName: 'SCB Global 24/7 ATM',
        branchName: _l(
          'Avenue Point 24/7 ATM (1.1km)',
          'လမ်းမကြီးဘေး ၂၄ နာရီ ATM (၁.၁ km)',
          'ตู้ ATM ไทยพาณิชย์ (1.1 กม.)',
        ),
        area: areaLabel,
        landmark: _l(
          'Safe & Well-Lit Location • 24/7 Access',
          'မီးရောင်လင်းထိန်သော နေရာ • ၂၄ နာရီ ထုတ်ယူနိုင်',
          'ปลอดภัย 24 ชม.',
        ),
        defaultDistanceKm: 1.1,
        latitude: centerLat + 0.0082,
        longitude: centerLng - 0.0068,
        openHours: '24 Hours (နေ့ရောညပါ)',
        isOpenNow: true,
        phone: '1333',
        mapQuery: 'SCB ATM near me',
        brandColor: const Color(0xFF0284C7),
        supportedCards: ['Visa', 'Mastercard', 'JCB', 'Plus', 'UnionPay'],
        withdrawalLimit: '30,000 THB / Transaction',
        atmFee: '220 THB',
        tags: [
          _l('24/7 ATM', '၂၄ နာရီငွေထုတ်စက်', 'ATM 24 ชม.'),
          _l('Fast Cash', 'ငွေထုတ်မြန်ဆန်', 'สะดวกรวดเร็ว'),
        ],
        fullAddress: 'Main Avenue, $areaLabel',
        exchangeTips: _l(
          'Ideal for quick cash withdrawals with foreign cards. 220 THB fee applies.',
          'နိုင်ငံတကာကတ်များဖြင့် လွယ်ကူမြန်ဆန်စွာ ငွေထုတ်ယူနိုင်ပါသည်။ ၂၂၀ ဘတ် ဝန်ဆောင်ခ ကျသင့်ပါသည်။',
          'ตู้เอทีเอ็ม 24 ชั่วโมง',
        ),
      ),
      _MoneyChangerCounter(
        id: 'dyn_ttb_atm',
        logoAsset: 'assets/images/banks/TTB.png',
        category: 'atm',
        brandName: 'TTB Global 24/7 ATM',
        branchName: _l(
          'Express Service 24/7 ATM (1.8km)',
          'အမြန်ဝန်ဆောင်မှု ၂၄ နာရီ ATM (၁.၈ km)',
          'ตู้ ATM ทีทีบี (1.8 กม.)',
        ),
        area: areaLabel,
        landmark: _l(
          'Convenient Stand • 24 Hours Cash Service',
          'အမြန်ထုတ်နိုင် • ၂၄ နာရီ ငွေသားထုတ်ယူနိုင်',
          'บริการ 24 ชม.',
        ),
        defaultDistanceKm: 1.8,
        latitude: centerLat - 0.0135,
        longitude: centerLng + 0.0120,
        openHours: '24 Hours (နေ့ရောညပါ)',
        isOpenNow: true,
        phone: '1333',
        mapQuery: 'TTB ATM near me',
        brandColor: const Color(0xFF0284C7),
        supportedCards: ['Visa', 'Mastercard', 'JCB', 'Plus'],
        withdrawalLimit: '30,000 THB / Transaction',
        atmFee: '220 THB',
        tags: [
          _l('24/7 ATM', '၂၄ နာရီငွေထုတ်စက်', 'ATM 24 ชม.'),
          _l('Express Point', 'အမြန်မှတ်တိုင်', 'จุดบริการด่วน'),
        ],
        fullAddress: 'Express Point, $areaLabel',
        exchangeTips: _l(
          'Reliable 24/7 ATM accepting international cards. 220 THB operator fee applies.',
          'စိတ်ချရသော ၂၄ နာရီ ATM ဖြစ်ပြီး နိုင်ငံတကာကတ်များ သုံးနိုင်ပါသည်။',
          'ตู้ ATM 24 ชม.',
        ),
      ),

      // ═════════════════════════════════════════════════════════════════════════
      // 3. NEARBY OFFICIAL MONEY EXCHANGES (3D exchange icon & BEST rate badge)
      // ═════════════════════════════════════════════════════════════════════════
      _MoneyChangerCounter(
        id: 'dyn_sr_orange',
        logoAsset: 'assets/images/services/exchange_3d.png',
        category: 'exchange',
        brandName: 'SuperRich 1965 (Orange)',
        branchName: _l(
          '$areaLabel Express Counter (520m)',
          '$areaLabel Express ဆိုင်ခွဲ (၅၂၀ မီတာ)',
          'สาขา$areaLabel (520 ม.)',
        ),
        area: areaLabel,
        landmark: _l(
          'Walking 6 Mins • Best Exchange Rate in Area',
          'လမ်းလျှောက် ၆ မိနစ် • ပေါက်ဈေး အကောင်းဆုံး',
          'เดิน 6 นาที • เรทดีที่สุด',
        ),
        defaultDistanceKm: 0.52,
        latitude: centerLat + 0.0036,
        longitude: centerLng - 0.0032,
        openHours: '09:00 - 18:30',
        isOpenNow: true,
        thbToMmkBuy: 141.60,
        thbToMmkSell: 143.40,
        usdToThbBuy: 34.65,
        usdToThbSell: 34.75,
        phone: '+6620544000',
        mapQuery: 'SuperRich near me',
        brandColor: const Color(0xFFFF5E00),
        isBestRate: true,
        isNearBts: true,
        tags: [
          _l('BOT Licensed', 'BOT တရားဝင်လိုင်စင်ရ', 'ใบอนุญาต ธปท.'),
          _l('Best Rate', 'ပေါက်ဈေး အကောင်းဆုံး', 'เรทดีที่สุด'),
          _l('Walking 6m', 'လမ်းလျှောက် ၆ မိနစ်', 'เดิน 6 นาที'),
        ],
        fullAddress: '$areaLabel, Thailand',
        exchangeTips: _l(
          'Top currency exchange rate in Thailand. Original Passport required by Bank of Thailand regulations. Cash only.',
          'ထိုင်းနိုင်ငံတွင် ပေါက်ဈေး အကောင်းဆုံး ငွေလဲဆိုင်ဖြစ်ပါသည်။ ထိုင်းဗဟိုဘဏ် စည်းမျဉ်းအရ Passport မူရင်း ယူဆောင်လာရန် လိုအပ်ပါသည်။ ငွေသားဖြင့် အဓိက လဲလှယ်နိုင်ပါသည်။',
          'เรทดีที่สุด ต้องใช้หนังสือเดินทางตัวจริงตามกฎ ธปท.',
        ),
      ),
      _MoneyChangerCounter(
        id: 'dyn_sr_green',
        logoAsset: 'assets/images/services/exchange_3d.png',
        category: 'exchange',
        brandName: 'SuperRich Thailand (Green)',
        branchName: _l(
          '$areaLabel Mall Branch (1.3km)',
          '$areaLabel Green ဆိုင်ခွဲ (၁.၃ km)',
          'ซุปเปอร์ริช สาขา$areaLabel (1.3 กม.)',
        ),
        area: areaLabel,
        landmark: _l(
          'Shopping Center Floor 1 • Open Late (8 PM)',
          'စတိုးဆိုင်တွင်း ၁ လွှာ • ည ၈ နာရီအထိဖွင့်',
          'ในห้าง ชั้น 1 • เปิดถึง 20:00 น.',
        ),
        defaultDistanceKm: 1.3,
        latitude: centerLat - 0.0085,
        longitude: centerLng + 0.0088,
        openHours: '10:00 - 20:00',
        isOpenNow: true,
        thbToMmkBuy: 141.50,
        thbToMmkSell: 143.50,
        usdToThbBuy: 34.63,
        usdToThbSell: 34.73,
        phone: '+6622544444',
        mapQuery: 'SuperRich Thailand near me',
        brandColor: const Color(0xFFFF5E00),
        isBestRate: true,
        isNearBts: true,
        tags: [
          _l('BOT Licensed', 'BOT တရားဝင်လိုင်စင်ရ', 'ใบอนุญาต ธปท.'),
          _l('Open Late (8 PM)', 'ည ၈ နာရီအထိဖွင့်', 'เปิดถึง 20:00'),
          _l('Best Rate', 'ပေါက်ဈေး အကောင်းဆုံး', 'เรทดีที่สุด'),
        ],
        fullAddress: 'Shopping Center 1st Floor, $areaLabel',
        exchangeTips: _l(
          'Open daily including holidays until 8 PM. Valid Passport or Work Permit required.',
          'စနေ/တနင်္ဂနွေ အပါအဝင် ည ၈ နာရီအထိ နေ့စဉ်ဖွင့်ပါသည်။ Passport သို့မဟုတ် Work Permit ပြသရန် လိုအပ်ပါသည်။',
          'เปิดทุกวันรวมวันหยุด ต้องใช้หนังสือเดินทาง',
        ),
      ),
      _MoneyChangerCounter(
        id: 'dyn_siam_exchange',
        logoAsset: 'assets/images/services/exchange_3d.png',
        category: 'exchange',
        brandName: 'Siam Currency Exchange',
        branchName: _l(
          'Market / Transit Counter (1.9km)',
          'ဈေး/ဘူတာအနီး ကောင်တာ (၁.၉ km)',
          'สยามเอ็กซ์เชนจ์ (1.9 กม.)',
        ),
        area: areaLabel,
        landmark: _l(
          'Fast Queue • Direct Street Access',
          'လူတန်းမြန်ဆန် • လမ်းမကြီးဘေး တိုက်ရိုက်',
          'คิวรวดเร็ว ติดถนน',
        ),
        defaultDistanceKm: 1.9,
        latitude: centerLat + 0.0140,
        longitude: centerLng + 0.0115,
        openHours: '09:30 - 18:30',
        isOpenNow: true,
        thbToMmkBuy: 141.40,
        thbToMmkSell: 143.60,
        usdToThbBuy: 34.60,
        usdToThbSell: 34.70,
        phone: '+6622153054',
        mapQuery: 'Siam Exchange near me',
        brandColor: const Color(0xFFFF5E00),
        isBestRate: false,
        isNearBts: true,
        tags: [
          _l('Fast Queue', 'လူတန်းမြန်ဆန်', 'คิวรวดเร็ว'),
          _l('BOT Licensed', 'BOT တရားဝင်လိုင်စင်ရ', 'ใบอนุญาต ธปท.'),
        ],
        fullAddress: 'Transit Avenue, $areaLabel',
        exchangeTips: _l(
          'Fast service counter. Passport required for foreign currencies.',
          'လူတန်းစောင့်ဆိုင်းချိန် မြန်ဆန်ပါသည်။ Passport မူရင်း ယူဆောင်လာရန် လိုအပ်ပါသည်။',
          'บริการรวดเร็ว ต้องใช้พาสปอร์ต',
        ),
      ),
      _MoneyChangerCounter(
        id: 'dyn_happy_rich',
        logoAsset: 'assets/images/services/exchange_3d.png',
        category: 'exchange',
        brandName: 'Happy Rich Exchange',
        branchName: _l(
          'Community Express Desk (2.4km)',
          'ကွန်မြူနတီ ကောင်တာ (၂.၄ km)',
          'แฮปปี้ริช (2.4 กม.)',
        ),
        area: areaLabel,
        landmark: _l(
          'Convenient for Commuters & Travelers',
          'ခရီးသွားများနှင့် ဒေသခံများအတွက် သင့်တော်',
          'สะดวกเดินทาง',
        ),
        defaultDistanceKm: 2.4,
        latitude: centerLat - 0.0165,
        longitude: centerLng - 0.0150,
        openHours: '08:30 - 19:30',
        isOpenNow: true,
        thbToMmkBuy: 141.35,
        thbToMmkSell: 143.65,
        usdToThbBuy: 34.58,
        usdToThbSell: 34.68,
        phone: '+6623911999',
        mapQuery: 'Happy Rich near me',
        brandColor: const Color(0xFFFF5E00),
        isBestRate: false,
        isNearBts: true,
        tags: [
          _l('Commuter Friendly', 'အလုပ်သွားအပြန် လဲလှယ်နိုင်', 'สะดวกเดินทาง'),
          _l('Open Daily', 'နေ့စဉ်ဖွင့်', 'เปิดทุกวัน'),
        ],
        fullAddress: 'Community Concourse, $areaLabel',
        exchangeTips: _l(
          'Very convenient for commuters. Passport or CI book accepted.',
          'အလုပ်အသွားအပြန် လဲလှယ်ရန် အထူးသင့်တော်ပြီး မူရင်း Passport သို့မဟုတ် CI စာအုပ်ဖြင့် လဲလှယ်နိုင်ပါသည်။',
          'สะดวกเดินทาง รับพาสปอร์ตและเล่ม CI',
        ),
      ),
    ];
  }

  List<_MoneyChangerCounter> get _curatedFlagshipCounters =>
      _memoizedCuratedFlagships ??= [
    // ═════════════════════════════════════════════════════════════════════════
    // 1. OFFICIAL MONEY EXCHANGES (တရားဝင် ငွေလဲဆိုင်များ - ORANGE PIN)
    // ═════════════════════════════════════════════════════════════════════════
    _MoneyChangerCounter(
      id: 'sr_orange_rajdamri',
      logoAsset: 'assets/images/services/exchange_3d.png',
      category: 'exchange',
      brandName: 'SuperRich 1965 (Orange)',
      branchName: _l(
        'Head Office (Rajdamri 1)',
        'ရုံးချုပ် (Rajdamri ၁ - CentralWorld အနီး)',
        'สำนักงานใหญ่ ราชดำริ 1',
      ),
      area: _l('Bangkok Central', 'ဗန်ကောက် မြို့လယ်', 'กรุงเทพฯ ชั้นใน'),
      landmark: _l(
        'Opposite CentralWorld • BTS Chit Lom (Exit 9)',
        'CentralWorld မျက်စောင်းထိုး • BTS Chit Lom (ထွက်ပေါက် ၉)',
        'ตรงข้าม CentralWorld • BTS ชิดลม',
      ),
      defaultDistanceKm: 1.2,
      latitude: 13.7485,
      longitude: 100.5411,
      openHours: '09:00 - 18:00',
      isOpenNow: true,
      thbToMmkBuy: 141.60,
      thbToMmkSell: 143.40,
      usdToThbBuy: 34.65,
      usdToThbSell: 34.75,
      phone: '+6620544000',
      mapQuery: 'SuperRich 1965 Head Office Rajdamri 1 Bangkok',
      brandColor: const Color(0xFFFF5E00),
      isBestRate: true,
      isNearBts: true,
      tags: [
        _l('BOT Licensed', 'BOT တရားဝင်လိုင်စင်ရ', 'ใบอนุญาต ธปท.'),
        _l('Best Rate', 'ပေါက်ဈေး အကောင်းဆုံး', 'เรทดีที่สุด'),
        _l('BTS Walkable', 'BTS လမ်းလျှောက် ၅ မိနစ်', 'ใกล้ BTS'),
      ],
      fullAddress: '47/11-13 Ratchadamri Rd, Lumphini, Pathum Wan, Bangkok 10330',
      exchangeTips: _l(
        'Original Passport required by Bank of Thailand regulations. Cash only counter.',
        'ထိုင်းဗဟိုဘဏ် စည်းမျဉ်းအရ နိုင်ငံကူးလက်မှတ် (Passport မူရင်း) ယူဆောင်သွားရပါမည်။ ငွေသား (Cash) ဖြင့် အဓိက လဲလှယ်နိုင်ပါသည်။',
        'ต้องใช้หนังสือเดินทางตัวจริงตามกฎ ธปท.',
      ),
    ),
    _MoneyChangerCounter(
      id: 'sr_green_paragon',
      logoAsset: 'assets/images/services/exchange_3d.png',
      category: 'exchange',
      brandName: 'SuperRich Thailand (Green)',
      branchName: _l(
        'Siam Paragon Branch (Floor G)',
        'Siam Paragon ဆိုင်ခွဲ (G အလွှာ - Canal Zone)',
        'สยามพารากอน ชั้น G',
      ),
      area: _l('Siam, Bangkok', 'ဆယမ်၊ ဗန်ကောက်', 'สยาม กรุงเทพฯ'),
      landmark: _l(
        'BTS Siam Station Direct Link (Siam Paragon)',
        'BTS Siam ဘူတာနှင့် တိုက်ရိုက်ချိတ်ဆက်ထားသည်',
        'เชื่อมต่อตรง BTS สยาม',
      ),
      defaultDistanceKm: 1.5,
      latitude: 13.7462,
      longitude: 100.5348,
      openHours: '10:00 - 20:00',
      isOpenNow: true,
      thbToMmkBuy: 141.50,
      thbToMmkSell: 143.50,
      usdToThbBuy: 34.63,
      usdToThbSell: 34.73,
      phone: '+6622544444',
      mapQuery: 'SuperRich Thailand Siam Paragon Floor G Bangkok',
      brandColor: const Color(0xFFFF5E00),
      isBestRate: true,
      isNearBts: true,
      tags: [
        _l('BOT Licensed', 'BOT တရားဝင်လိုင်စင်ရ', 'ใบอนุญาต ธปท.'),
        _l('Open Late (8 PM)', 'ည ၈ နာရီအထိဖွင့်', 'เปิดถึง 20:00'),
        _l('Inside Mall', 'စတိုးဆိုင်အတွင်း အေးအေးလူလူ', 'ในห้างแอร์เย็น'),
      ],
      fullAddress: 'Siam Paragon Shopping Center, Floor G, Rama I Rd, Bangkok',
      exchangeTips: _l(
        'Valid Passport or Thai Work Permit required. Open daily including holidays.',
        'Passport သို့မဟုတ် ထိုင်းအလုပ်သမား Work Permit ပြသရန် လိုအပ်ပါသည်။ စနေ/တနင်္ဂနွေ အပါအဝင် နေ့စဉ်ဖွင့်ပါသည်။',
        'ต้องแสดงหนังสือเดินทางหรือใบอนุญาตทำงาน',
      ),
    ),
    _MoneyChangerCounter(
      id: 'siam_exchange_mbk',
      logoAsset: 'assets/images/services/exchange_3d.png',
      category: 'exchange',
      brandName: 'Siam Exchange',
      branchName: _l(
        'MBK Center / National Stadium',
        'MBK စင်တာ / National Stadium ဘူတာဘေး',
        'สยามเอ็กซ์เชนจ์ ปทุมวัน',
      ),
      area: _l('Pathum Wan, Bangkok', 'ပထုံဝမ်၊ ဗန်ကောက်', 'ปทุมวัน กรุงเทพฯ'),
      landmark: _l(
        'BTS National Stadium (Exit 1) • Beside MBK',
        'BTS National Stadium (ထွက်ပေါက် ၁) • MBK ဘေး',
        'BTS สนามกีฬาแห่งชาติ ทางออก 1',
      ),
      defaultDistanceKm: 1.8,
      latitude: 13.7441,
      longitude: 100.5302,
      openHours: '09:30 - 18:30',
      isOpenNow: true,
      thbToMmkBuy: 141.40,
      thbToMmkSell: 143.60,
      usdToThbBuy: 34.60,
      usdToThbSell: 34.70,
      phone: '+6622153054',
      mapQuery: 'Siam Exchange Phayathai Rd Bangkok',
      brandColor: const Color(0xFFFF5E00),
      isBestRate: false,
      isNearBts: true,
      tags: [
        _l('BOT Licensed', 'BOT တရားဝင်လိုင်စင်ရ', 'ใบอนุญาต ธปท.'),
        _l('Fast Queue', 'လူတန်းမြန်ဆန်', 'คิวรวดเร็ว'),
        _l('BTS National Stadium', 'BTS ဘူတာဆင်းဆင်းချင်း', 'ติด BTS'),
      ],
      fullAddress: '422 Phayathai Rd, Wang Mai, Pathum Wan, Bangkok 10330',
      exchangeTips: _l(
        'Fast service counter. Passport required for foreign currencies.',
        'လူတန်းစောင့်ဆိုင်းချိန် မြန်ဆန်ပါသည်။ Passport မူရင်း ယူဆောင်လာရန် လိုအပ်ပါသည်။',
        'บริการรวดเร็ว ต้องใช้พาสปอร์ต',
      ),
    ),
    _MoneyChangerCounter(
      id: 'happy_rich_phrakhanong',
      logoAsset: 'assets/images/services/exchange_3d.png',
      category: 'exchange',
      brandName: 'Happy Rich Exchange',
      branchName: _l(
        'BTS Phra Khanong Station',
        'BTS ဖြာခနောင်း ဘူတာတွင်း ကောင်တာ',
        'แฮปปี้ริช BTS พระโขนง',
      ),
      area: _l('Sukhumvit, Bangkok', 'ဆူခွန်ဗစ်၊ ဗန်ကောက်', 'สุขุมวิท กรุงเทพฯ'),
      landmark: _l(
        'Inside BTS Phra Khanong Station (Exit 3 Concourse)',
        'BTS Phra Khanong ဘူတာအတွင်း (Exit 3)',
        'บนสถานี BTS พระโขนง ทางออก 3',
      ),
      defaultDistanceKm: 3.4,
      latitude: 13.7152,
      longitude: 100.5913,
      openHours: '08:30 - 19:30',
      isOpenNow: true,
      thbToMmkBuy: 141.35,
      thbToMmkSell: 143.65,
      usdToThbBuy: 34.58,
      usdToThbSell: 34.68,
      phone: '+6623911999',
      mapQuery: 'Happy Rich BTS Phra Khanong Bangkok',
      brandColor: const Color(0xFFFF5E00),
      isBestRate: false,
      isNearBts: true,
      tags: [
        _l('In-Station', 'ရထားဘူတာအတွင်း တိုက်ရိုက်', 'ในสถานี BTS'),
        _l('Commuter Friendly', 'အလုပ်သွားအပြန် လဲလှယ်နိုင်', 'สะดวกเดินทาง'),
      ],
      fullAddress: 'BTS Phra Khanong Concourse Level, Sukhumvit Rd, Bangkok',
      exchangeTips: _l(
        'Located on the BTS concourse level. Very convenient for commuters.',
        'BTS Skytrain ဘူတာရုံအတွင်း တည်ရှိသောကြောင့် အလုပ်အသွားအပြန် လဲလှယ်ရန် အထူးသင့်တော်ပါသည်။',
        'ตั้งอยู่บนชั้นจำหน่ายตั๋ว BTS พระโขนง',
      ),
    ),
    _MoneyChangerCounter(
      id: 'sr_mahachai',
      logoAsset: 'assets/images/services/exchange_3d.png',
      category: 'exchange',
      brandName: 'SuperRich Mahachai',
      branchName: _l(
        'Central Mahachai Branch (1st Fl)',
        'Central မဟာချိုင် ဆိုင်ခွဲ (၁ လွှာ)',
        'เซ็นทรัล มหาชัย ชั้น 1',
      ),
      area: _l('Samut Sakhon', 'မဟာချိုင်၊ စမွတ်စာခွန်', 'สมุทรสาคร'),
      landmark: _l(
        'Central Plaza Mahachai • Myanmar Community Hub',
        'Central Plaza မဟာချိုင် • မြန်မာလုပ်သားများ အနီး',
        'เซ็นทรัลพลาซา มหาชัย',
      ),
      defaultDistanceKm: 28.5,
      latitude: 13.5415,
      longitude: 100.2751,
      openHours: '10:30 - 19:30',
      isOpenNow: true,
      thbToMmkBuy: 141.45,
      thbToMmkSell: 143.55,
      usdToThbBuy: 34.60,
      usdToThbSell: 34.70,
      phone: '+6634112400',
      mapQuery: 'Central Mahachai SuperRich Samut Sakhon',
      brandColor: const Color(0xFFFF5E00),
      isBestRate: false,
      isNearBts: false,
      tags: [
        _l('Mahachai Hub', 'မဟာချိုင် မြန်မာရပ်ကွက်', 'ศูนย์รวมมหาชัย'),
        _l('CI / Passport Accepted', 'CI / Passport အသုံးပြုနိုင်', 'รับพาสปอร์ต/CI'),
        _l('Central Mall', 'Central စတိုးဆိုင်ကြီးအတွင်း', 'ในห้างเซ็นทรัล'),
      ],
      fullAddress: 'Central Plaza Mahachai 1st Floor, Rama II Rd, Samut Sakhon',
      exchangeTips: _l(
        'Very convenient for Myanmar workers in Mahachai. Passport or CI book accepted.',
        'မဟာချိုင်ရောက် မြန်မာတိုင်းရင်းသားများအတွက် အလွန်အဆင်ပြေပြီး မူရင်း Passport သို့မဟုတ် CI စာအုပ်ဖြင့် လဲလှယ်နိုင်ပါသည်။',
        'สะดวกสำหรับแรงงานเมียนมาในมหาชัย รับพาสปอร์ตและเล่ม CI',
      ),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 2. OFFICIAL BANK BRANCHES (တရားဝင် ဘဏ်ခွဲကြီးများ - GREEN PIN)
    // ═════════════════════════════════════════════════════════════════════════
    _MoneyChangerCounter(
      id: 'kbank_centralworld',
      logoAsset: 'assets/images/banks/KBANK.png',
      category: 'bank',
      brandName: 'Kasikorn Bank (KBank)',
      branchName: _l(
        'CentralWorld Branch (Floor 4)',
        'CentralWorld ဘဏ်ခွဲ (၄ လွှာ - Banking Zone)',
        'ธนาคารกสิกรไทย เซ็นทรัลเวิลด์ ชั้น 4',
      ),
      area: _l('Bangkok Central', 'ဗန်ကောက် မြို့လယ်', 'กรุงเทพฯ ชั้นใน'),
      landmark: _l(
        'CentralWorld 4th Floor • Near Zone D',
        'CentralWorld ၄ လွှာ ဘဏ်များဇုန် • BTS Chit Lom / Siam',
        'เซ็นทรัลเวิลด์ ชั้น 4 โซนธนาคาร',
      ),
      defaultDistanceKm: 1.3,
      latitude: 13.7465,
      longitude: 100.5393,
      openHours: '10:00 - 19:30',
      isOpenNow: true,
      phone: '+6628888888',
      mapQuery: 'Kasikorn Bank CentralWorld Floor 4 Bangkok',
      brandColor: const Color(0xFF059669),
      isBestRate: false,
      isNearBts: true,
      tags: [
        _l('Official Bank', 'တရားဝင် ဘဏ်ကြီး', 'ธนาคารพาณิชย์'),
        _l('FX & Swift Desk', 'နိုင်ငံခြားငွေလဲ & လွှဲပြောင်း', 'บริการแลกเงินและโอนเงินต่างประเทศ'),
        _l('CentralWorld', 'CentralWorld စတိုးဆိုင်တွင်း', 'ในศูนย์การค้า'),
      ],
      fullAddress: 'CentralWorld 4th Floor, 999/9 Rama I Rd, Pathum Wan, Bangkok',
      exchangeTips: _l(
        'Official Kasikorn Bank branch. Provides foreign currency exchange, Swift international remittance, and banking services. Passport required.',
        'တရားဝင် Kasikorn Bank ဘဏ်ခွဲဖြစ်ပြီး နိုင်ငံခြားငွေလဲလှယ်ခြင်းနှင့် နိုင်ငံတကာငွေလွှဲဝန်ဆောင်မှုများ ဆောင်ရွက်နိုင်ပါသည်။ မူရင်း Passport မဖြစ်မနေ လိုအပ်ပါသည်။',
        'บริการแลกเปลี่ยนเงินตราต่างประเทศและโอนเงิน ต้องแสดงหนังสือเดินทาง',
      ),
    ),
    _MoneyChangerCounter(
      id: 'bbl_siam_paragon',
      logoAsset: 'assets/images/banks/BBL.png',
      category: 'bank',
      brandName: 'Bangkok Bank (BBL)',
      branchName: _l(
        'Siam Paragon Branch (Floor 4)',
        'Siam Paragon ဘဏ်ခွဲ (၄ လွှာ - North Zone)',
        'ธนาคารกรุงเทพ สยามพารากอน ชั้น 4',
      ),
      area: _l('Siam, Bangkok', 'ဆယမ်၊ ဗန်ကောက်', 'สยาม กรุงเทพฯ'),
      landmark: _l(
        'Siam Paragon Floor 4 • Direct BTS Siam Skywalk',
        'Siam Paragon ၄ လွှာ • BTS Siam ဘူတာ တိုက်ရိုက်လမ်းလျှောက်',
        'สยามพารากอน ชั้น 4',
      ),
      defaultDistanceKm: 1.4,
      latitude: 13.7459,
      longitude: 100.5342,
      openHours: '10:30 - 20:00',
      isOpenNow: true,
      phone: '+6621294400',
      mapQuery: 'Bangkok Bank Siam Paragon Branch Bangkok',
      brandColor: const Color(0xFF059669),
      isBestRate: false,
      isNearBts: true,
      tags: [
        _l('Top Bank in Thailand', 'ထိုင်းအကြီးဆုံး ဘဏ်ကြီး', 'ธนาคารกรุงเทพ'),
        _l('Foreign FX Counter', 'နိုင်ငံခြားငွေလဲ ကောင်တာ', 'เคาน์เตอร์แลกเปลี่ยนเงิน'),
        _l('Open 7 Days', 'စနေ/တနင်္ဂနွေ ဖွင့်သည်', 'เปิดทุกวัน'),
      ],
      fullAddress: 'Siam Paragon Shopping Center, 4th Floor, Rama I Rd, Bangkok',
      exchangeTips: _l(
        'Official Bangkok Bank branch. Full FX counter, traveler services, and international card assistance. Passport required.',
        'Bangkok Bank ၏ အဓိကဘဏ်ခွဲကြီးဖြစ်ပြီး နိုင်ငံခြားငွေအစုံအလင် လဲလှယ်နိုင်ပါသည်။ Passport မူရင်း ပြသရန် လိုအပ်ပါသည်။',
        'บริการแลกเปลี่ยนเงินตราต่างประเทศ ต้องแสดงหนังสือเดินทาง',
      ),
    ),
    _MoneyChangerCounter(
      id: 'scb_siam_square',
      logoAsset: 'assets/images/banks/SCB.png',
      category: 'bank',
      brandName: 'Siam Commercial Bank (SCB)',
      branchName: _l(
        'Siam Square One Branch (Floor 2)',
        'Siam Square One ဘဏ်ခွဲ (၂ လွှာ)',
        'ธนาคารไทยพาณิชย์ สยามสแควร์วัน ชั้น 2',
      ),
      area: _l('Siam, Bangkok', 'ဆယမ်၊ ဗန်ကောက်', 'สยามสแควร์'),
      landmark: _l(
        'Siam Square One 2nd Floor • Opposite BTS Siam (Exit 4)',
        'Siam Square One ၂ လွှာ • BTS Siam (ထွက်ပေါက် ၄) မျက်နှာချင်းဆိုင်',
        'สยามสแควร์วัน ชั้น 2 ตรงข้าม BTS สยาม',
      ),
      defaultDistanceKm: 1.6,
      latitude: 13.7449,
      longitude: 100.5328,
      openHours: '10:00 - 19:30',
      isOpenNow: true,
      phone: '+6627777777',
      mapQuery: 'SCB Siam Square One Branch Bangkok',
      brandColor: const Color(0xFF059669),
      isBestRate: false,
      isNearBts: true,
      tags: [
        _l('SCB Official', 'SCB တရားဝင်ဘဏ်ခွဲ', 'ธนาคารไทยพาณิชย์'),
        _l('Foreign Exchange', 'နိုင်ငံခြားငွေလဲ ဝန်ဆောင်မှု', 'บริการเงินตราต่างประเทศ'),
        _l('BTS Siam Linked', 'BTS Siam ဘူတာရှေ့', 'ติด BTS สยาม'),
      ],
      fullAddress: 'Siam Square One 2nd Floor, Rama I Rd, Pathum Wan, Bangkok',
      exchangeTips: _l(
        'Authorized Siam Commercial Bank branch. Foreign currency notes exchange, debit/credit card support, and wire transfer. Passport required.',
        'SCB တရားဝင်ဘဏ်ခွဲဖြစ်ပြီး နိုင်ငံခြားငွေလဲလှယ်ခြင်းနှင့် ဘဏ်လုပ်ငန်းများကို စိတ်ချစွာ ဆောင်ရွက်နိုင်ပါသည်။ Passport ယူဆောင်လာရန် လိုအပ်ပါသည်။',
        'บริการแลกเงินและธุรกรรมธนาคาร ต้องใช้พาสปอร์ต',
      ),
    ),
    _MoneyChangerCounter(
      id: 'kbank_maesot_border',
      logoAsset: 'assets/images/banks/KBANK.png',
      category: 'bank',
      brandName: 'Kasikorn Bank FX Counter',
      branchName: _l(
        'Mae Sot Friendship Bridge 1',
        'မဲဆောက် ချစ်ကြည်ရေးတံတား (၁) ကောင်တာ',
        'ด่านสะพานมิตรภาพแม่สอด 1',
      ),
      area: _l('Mae Sot Border, Tak', 'မဲဆောက် နယ်စပ်ဂိတ်၊ တာ့ခ်', 'ด่านแม่สอด ตาก'),
      landmark: _l(
        '1st Thai-Myanmar Friendship Bridge Border Checkpoint',
        'အမှတ် (၁) ထိုင်း-မြန်မာ ချစ်ကြည်ရေးတံတား စစ်ဆေးရေးဂိတ်',
        'สะพานมิตรภาพไทย-เมียนมา แห่งที่ 1',
      ),
      defaultDistanceKm: 490.0,
      latitude: 16.6976,
      longitude: 98.5174,
      openHours: '08:30 - 17:00',
      isOpenNow: true,
      phone: '+6655531222',
      mapQuery: 'Thai-Myanmar Friendship Bridge 1 Mae Sot Tak',
      brandColor: const Color(0xFF059669),
      isBestRate: false,
      isNearBts: false,
      tags: [
        _l('Border Gate', 'နယ်စပ်ဂိတ် တိုက်ရိုက်', 'ด่านพรมแดน'),
        _l('Official Bank FX', 'ဘဏ်တရားဝင် လိုင်စင်ရ', 'เคาน์เตอร์ธนาคาร'),
        _l('Border Pass Accepted', 'နယ်စပ်ဖြတ်သန်းခွင့် လဲလှယ်နိုင်', 'รับ Border Pass'),
      ],
      fullAddress: 'Tha Sai Luat, Mae Sot District, Tak 63110 (Bridge 1 Checkpoint)',
      exchangeTips: _l(
        'Located directly at the border gate. Safe and official exchange for cross-border travelers.',
        'နယ်စပ်ဂိတ်ပေါက်ဝတွင် တိုက်ရိုက်တည်ရှိသော တရားဝင်ဘဏ်ကောင်တာဖြစ်၍ နယ်စပ်ဖြတ်သန်းခွင့်စာအုပ် သို့မဟုတ် Passport ဖြင့် လုံခြုံစိတ်ချစွာ လဲလှယ်နိုင်ပါသည်။',
        'ตั้งอยู่จุดผ่านแดน สะดวก ปลอดภัย ถูกต้องตามกฎหมาย',
      ),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 3. GLOBAL 24/7 ATMs (နိုင်ငံတကာသုံး ATM စက်များ - CYAN PIN)
    // ═════════════════════════════════════════════════════════════════════════
    _MoneyChangerCounter(
      id: 'kbank_atm_bts_siam',
      logoAsset: 'assets/images/banks/KBANK.png',
      category: 'atm',
      brandName: 'KBank Global 24/7 ATM',
      branchName: _l(
        'BTS Siam Station Concourse (Exit 1)',
        'BTS Siam ဘူတာတွင်း 24/7 ATM (ထွက်ပေါက် ၁)',
        'ตู้เอทีเอ็ม กสิกรไทย BTS สยาม',
      ),
      area: _l('Siam, Bangkok', 'ဆယမ်၊ ဗန်ကောက်', 'สยาม กรุงเทพฯ'),
      landmark: _l(
        'Inside BTS Siam Station Concourse • Near Ticket Machines',
        'BTS Siam ဘူတာ လက်မှတ်ဖြတ်ကောင်တာအနီး • ၂၄ နာရီငွေထုတ်နိုင်',
        'บนสถานี BTS สยาม ใกล้ตู้จำหน่ายตั๋ว',
      ),
      defaultDistanceKm: 1.4,
      latitude: 13.7456,
      longitude: 100.5345,
      openHours: '24 Hours (နေ့ရောညပါ)',
      isOpenNow: true,
      phone: '1333',
      mapQuery: 'KBank ATM BTS Siam Station Bangkok',
      brandColor: const Color(0xFF0284C7),
      isBestRate: false,
      isNearBts: true,
      supportedCards: ['Visa', 'Mastercard', 'JCB', 'UnionPay', 'Cirrus', 'Plus'],
      withdrawalLimit: '30,000 THB / Transaction',
      atmFee: '220 THB',
      tags: [
        _l('24/7 ATM', '၂၄ နာရီငွေထုတ်စက်', 'ATM 24 ชม.'),
        _l('Foreign Cards OK', 'နိုင်ငံတကာကတ်များ သုံးနိုင်', 'รับบัตรต่างประเทศ'),
        _l('BTS Siam', 'BTS Siam ဘူတာအတွင်း', 'ในสถานี BTS'),
      ],
      fullAddress: 'BTS Siam Station Concourse, Rama I Rd, Pathum Wan, Bangkok',
      exchangeTips: _l(
        '24/7 ATM accepting international Visa, Mastercard, JCB, and UnionPay cards. Standard Thai ATM operator fee of 220 THB applies. Select "Without Conversion" on screen for bank rates.',
        'Visa, Mastercard, JCB, UnionPay စသည့် နိုင်ငံတကာကတ်များဖြင့် ၂၄ နာရီ ငွေထုတ်နိုင်ပါသည်။ ထိုင်းဘဏ် ATM စည်းမျဉ်းအရ တစ်ကြိမ်လျှင် ၂၂၀ ဘတ် ဝန်ဆောင်ခ ဖြတ်တောက်ပါသည်။ စက်ပေါ်တွင် DCC မေးလျှင် "Without Conversion" (THB ဖြင့်သာ) ရွေးချယ်ပါက အသက်သာဆုံး ဖြစ်ပါသည်။',
        'ตู้เอทีเอ็ม 24 ชั่วโมง รับบัตรสากลทุกประเภท มีค่าธรรมเนียมตู้ 220 บาท',
      ),
    ),
    _MoneyChangerCounter(
      id: 'bbl_atm_centralworld',
      logoAsset: 'assets/images/banks/BBL.png',
      category: 'atm',
      brandName: 'Bangkok Bank Global 24/7 ATM',
      branchName: _l(
        'CentralWorld Main Entrance (Floor G)',
        'CentralWorld ပင်မဝင်ပေါက် 24/7 ATM (G အလွှာ)',
        'ตู้เอทีเอ็ม ธนาคารกรุงเทพ เซ็นทรัลเวิลด์',
      ),
      area: _l('Bangkok Central', 'ဗန်ကောက် မြို့လယ်', 'กรุงเทพฯ ชั้นใน'),
      landmark: _l(
        'CentralWorld Floor G • Outdoor Square Entrance',
        'CentralWorld အဝင်ဝ G အလွှာ ရင်ပြင်ဘက် • ၂၄ နာရီဖွင့်',
        'หน้าศูนย์การค้าเซ็นทรัลเวิลด์ ชั้น G',
      ),
      defaultDistanceKm: 1.3,
      latitude: 13.7471,
      longitude: 100.5398,
      openHours: '24 Hours (နေ့ရောညပါ)',
      isOpenNow: true,
      phone: '1333',
      mapQuery: 'Bangkok Bank ATM CentralWorld Floor G Bangkok',
      brandColor: const Color(0xFF0284C7),
      isBestRate: false,
      isNearBts: true,
      supportedCards: ['Visa', 'Mastercard', 'UnionPay', 'Cirrus', 'JCB'],
      withdrawalLimit: '30,000 THB / Transaction',
      atmFee: '220 THB',
      tags: [
        _l('24/7 ATM', '၂၄ နာရီငွေထုတ်စက်', 'ATM 24 ชม.'),
        _l('High Reliability', 'လိုင်းပြတ်တောက်မှုမရှိ', 'เสถียร รวดเร็ว'),
        _l('CentralWorld', 'CentralWorld ပင်မအဝင်', 'หน้าห้าง'),
      ],
      fullAddress: 'CentralWorld G Floor Entrance, Ratchadamri Rd, Bangkok',
      exchangeTips: _l(
        'High cash capacity ATM. Supports international card withdrawals with English and Thai interface. 220 THB fee per foreign card withdrawal.',
        'ငွေသားထုတ်ယူမှု ပမာဏများပြားပြီး စိတ်ချရသော ATM စက်ဖြစ်ပါသည်။ နိုင်ငံတကာကတ်များ သုံးနိုင်ပြီး တစ်ကြိမ်လျှင် ၂၂၀ ဘတ် ဝန်ဆောင်ခ ဖြတ်ပါသည်။',
        'ตู้เอทีเอ็มรองรับบัตรต่างประเทศ หน้าลานเซ็นทรัลเวิลด์',
      ),
    ),
    _MoneyChangerCounter(
      id: 'scb_atm_chitlom',
      logoAsset: 'assets/images/banks/SCB.png',
      category: 'atm',
      brandName: 'SCB Global 24/7 ATM',
      branchName: _l(
        'BTS Chit Lom Skybridge Walkway',
        'BTS Chit Lom စကိုင်းဝေါ့ခ် လမ်းလျှောက်တံတား ATM',
        'ตู้เอทีเอ็ม ไทยพาณิชย์ สกายวอล์ค BTS ชิดลม',
      ),
      area: _l('Chit Lom, Bangkok', 'ချစ်လုံ၊ ဗန်ကောက်', 'ชิดลม กรุงเทพฯ'),
      landmark: _l(
        'Skywalk between BTS Chit Lom and CentralWorld (Exit 1)',
        'BTS Chit Lom နှင့် CentralWorld ဆက်သွယ်ထားသော စကိုင်းဝေါ့ခ်ပေါ်တွင် တည်ရှိသည်',
        'สกายวอล์ค ระหว่าง BTS ชิดลม และ เซ็นทรัลเวิลด์',
      ),
      defaultDistanceKm: 1.1,
      latitude: 13.7442,
      longitude: 100.5432,
      openHours: '24 Hours (နေ့ရောညပါ)',
      isOpenNow: true,
      phone: '1333',
      mapQuery: 'SCB ATM BTS Chit Lom Station Bangkok',
      brandColor: const Color(0xFF0284C7),
      isBestRate: false,
      isNearBts: true,
      supportedCards: ['Visa', 'Mastercard', 'JCB', 'Plus', 'UnionPay'],
      withdrawalLimit: '30,000 THB / Transaction',
      atmFee: '220 THB',
      tags: [
        _l('24/7 ATM', '၂၄ နာရီငွေထုတ်စက်', 'ATM 24 ชม.'),
        _l('Skywalk Access', 'စကိုင်းဝေါ့ခ်ပေါ်တွင် တိုက်ရိုက်', 'บนสกายวอล์ค'),
        _l('Chit Lom Area', 'ချစ်လုံရပ်ကွက်', 'ย่านชิดลม'),
      ],
      fullAddress: 'Skybridge Walkway, Ploenchit Rd, Lumphini, Bangkok 10330',
      exchangeTips: _l(
        'Directly accessible on the covered skywalk. Ideal for late-night cash withdrawals when banks/counters are closed. 220 THB foreign card fee.',
        'မိုးလုံလေလုံ စကိုင်းဝေါ့ခ်ပေါ်တွင် တည်ရှိ၍ ညဘက် ငွေလဲဆိုင်များပိတ်ချိန်တွင် အရေးပေါ် ငွေသားထုတ်ယူရန် အထူးသင့်တော်ပါသည်။ တစ်ကြိမ်လျှင် ၂၂၀ ဘတ် ဝန်ဆောင်ခ ကျသင့်ပါသည်။',
        'ตู้เอทีเอ็มบนสกายวอล์ค สะดวก ปลอดภัย 24 ชั่วโมง',
      ),
    ),
  ];

  Future<void> _getUserLocation({bool requestIfDenied = true}) async {
    if (_isLocatingUser) return;
    setState(() {
      _isLocatingUser = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocatingUser = false;
            _locationError = _l(
              'Location services disabled.',
              'ဖုန်း၏ GPS Location ဖွင့်ပေးရန် လိုအပ်ပါသည်။',
              'บริการระบุตำแหน่งถูกปิดอยู่',
            );
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestIfDenied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isLocatingUser = false;
            _locationError = _l(
              'Location permission denied.',
              'တည်နေရာခွင့်ပြုချက် ပိတ်ထားပါသည်။',
              'ปฏิเสธการเข้าถึงตำแหน่ง',
            );
          });
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocatingUser = false;
            _locationError = _l(
              'Location permission denied forever.',
              'တည်နေရာခွင့်ပြုချက် Settings တွင် ဖွင့်ပေးပါ။',
              'สิทธิ์การเข้าถึงตำแหน่งถูกปฏิเสธถาวร',
            );
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (mounted) {
        setState(() {
          _userPosition = position;
          _isLocatingUser = false;
        });
        _updateMapMarkers();
        if (_selectedTab == 2 && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 14.5,
              ),
            ),
          );
        }

        // Reverse geocode asynchronously to get real neighborhood name (100% Free OpenStreetMap)
        NominatimGeocoder.reverseGeocode(position.latitude, position.longitude).then((place) {
          if (mounted && place != null && place.name.isNotEmpty) {
            setState(() {
              _userAreaName = place.name;
            });
            _updateMapMarkers();
          }
        }).catchError((_) {});

        // Fetch real OpenStreetMap places (Banks, ATMs, Money Changers) around user coordinates
        _fetchOsmNearbyCounters(position.latitude, position.longitude);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLocatingUser = false;
        });
      }
    }
  }

  Future<void> _fetchOsmNearbyCounters(
    double lat,
    double lon, {
    double? radiusKm,
    bool force = false,
  }) async {
    final targetRadius = radiusKm ?? (_selectedRadiusKm > 0 ? _selectedRadiusKm.toDouble() : 5.0);

    // Prevent redundant requests if already fetching or within 300m of last query
    if (_isFetchingOsm && !force) return;
    if (!force &&
        _lastOsmFetchedPosition != null &&
        Geolocator.distanceBetween(
              _lastOsmFetchedPosition!.latitude,
              _lastOsmFetchedPosition!.longitude,
              lat,
              lon,
            ) < 300 &&
        _lastOsmFetchedRadius == targetRadius.toInt()) {
      return;
    }

    if (mounted) {
      setState(() => _isFetchingOsm = true);
    }

    try {
      final results = await _OsmPlacesService.fetchNearby(
        latitude: lat,
        longitude: lon,
        radiusKm: targetRadius,
      );

      if (mounted) {
        setState(() {
          _osmNearbyCounters = results;
          _lastOsmFetchedPosition = Position(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
          _lastOsmFetchedRadius = targetRadius.toInt();
          _isFetchingOsm = false;
          _cachedAllCounters = null; // Invalidate cache so _allMoneyChangers recalculates
        });
        _updateMapMarkers();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFetchingOsm = false);
      }
    }
  }

  void _preloadMarkerAssets() {
    final assetList = [
      'assets/images/banks/KBANK.png',
      'assets/images/banks/BBL.png',
      'assets/images/banks/SCB.png',
      'assets/images/banks/KTB.png',
      'assets/images/banks/TTB.png',
      'assets/images/services/exchange_3d.png',
    ];
    for (final path in assetList) {
      _getOrLoadAssetImage(path).then((_) {
        if (mounted && _mapMarkers.isNotEmpty) {
          _updateMapMarkers();
        }
      });
    }
  }

  Future<ui.Image?> _getOrLoadAssetImage(String assetPath) async {
    if (_assetImageCache.containsKey(assetPath)) {
      return _assetImageCache[assetPath];
    }
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final ui.Codec codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo fi = await codec.getNextFrame();
      _assetImageCache[assetPath] = fi.image;
      return fi.image;
    } catch (e) {
      debugPrint('Error loading marker asset image ($assetPath): $e');
      return null;
    }
  }

  Future<BitmapDescriptor> _generateCustomMarker(
    _MoneyChangerCounter counter, {
    required bool isSelected,
  }) async {
    const double pixelRatio = 3.0;
    final double w = isSelected ? 58.0 : 50.0;
    final double h = isSelected ? 68.0 : 58.0;
    final double headDiameter = isSelected ? 46.0 : 40.0;
    final double radius = headDiameter / 2.0;
    final Offset center = Offset(w / 2.0, radius + 3.0);
    final Offset tip = Offset(w / 2.0, h - 3.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio, pixelRatio);

    // 1. Soft ground shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2.0, h - 2.0),
        width: isSelected ? 20.0 : 16.0,
        height: 5.0,
      ),
      shadowPaint,
    );

    // 2. Base pin color
    Color pinColor;
    if (counter.category == 'bank') {
      pinColor = counter.brandColor;
    } else if (counter.category == 'atm') {
      pinColor = const Color(0xFF0284C7);
    } else {
      pinColor = const Color(0xFFFF5E00);
    }

    // 3. Pin Body Path (classic teardrop pointer pin)
    final double dy = (tip.dy - center.dy).clamp(radius + 1.0, 999.0);
    final double angle = asin((radius / dy).clamp(0.0, 0.99));
    final double cosA = cos(angle);
    final double sinA = sin(angle);

    final pinPath = Path();
    pinPath.moveTo(tip.dx, tip.dy);
    pinPath.lineTo(center.dx - radius * cosA, center.dy + radius * sinA);
    pinPath.arcToPoint(
      Offset(center.dx + radius * cosA, center.dy + radius * sinA),
      radius: Radius.circular(radius),
      largeArc: true,
      clockwise: true,
    );
    pinPath.close();

    // If selected, draw glowing outer border / ring
    if (isSelected) {
      final glowPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawPath(pinPath, glowPaint);
    }

    // Pin fill
    final pinPaint = Paint()
      ..color = isSelected ? AppColors.primary : pinColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // Pin outline border
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(pinPath, strokePaint);

    // 4. Inner White Badge Circle for the Logo
    final double innerRadius = radius - (isSelected ? 3.5 : 3.0);
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()..color = Colors.white,
    );

    // 5. Draw the Logo or Icon inside the inner circle
    ui.Image? logoImg;
    if (counter.logoAsset != null) {
      logoImg = await _getOrLoadAssetImage(counter.logoAsset!);
    }

    if (logoImg != null) {
      final double logoDiameter = innerRadius * 1.55;
      final Rect destRect = Rect.fromCenter(
        center: center,
        width: logoDiameter,
        height: logoDiameter,
      );
      final Rect srcRect = Rect.fromLTWH(
        0,
        0,
        logoImg.width.toDouble(),
        logoImg.height.toDouble(),
      );
      canvas.drawImageRect(
        logoImg,
        srcRect,
        destRect,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high,
      );
    } else {
      // Fallback vector icon
      final IconData fallbackIcon = counter.category == 'bank'
          ? Icons.account_balance_rounded
          : (counter.category == 'atm'
              ? Icons.atm_rounded
              : Icons.currency_exchange_rounded);

      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(fallbackIcon.codePoint),
          style: TextStyle(
            fontSize: innerRadius * 1.1,
            fontFamily: fallbackIcon.fontFamily,
            package: fallbackIcon.fontPackage,
            color: pinColor,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(
          center.dx - iconPainter.width / 2.0,
          center.dy - iconPainter.height / 2.0,
        ),
      );
    }

    // 6. ATM Pill Overlay Badge (at top-right corner)
    if (counter.category == 'atm') {
      const double badgeW = 20.0;
      const double badgeH = 10.0;
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w - badgeW - 1.0, 1.0, badgeW, badgeH),
        const Radius.circular(5.0),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()..color = const Color(0xFF0284C7),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      final atmTextPainter = TextPainter(
        text: const TextSpan(
          text: 'ATM',
          style: TextStyle(
            fontSize: 6.0,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      atmTextPainter.layout();
      atmTextPainter.paint(
        canvas,
        Offset(
          w - badgeW - 1.0 + (badgeW - atmTextPainter.width) / 2.0,
          1.0 + (badgeH - atmTextPainter.height) / 2.0,
        ),
      );
    } else if (counter.category == 'exchange' && counter.isBestRate) {
      // Best Rate Amber Badge
      const double badgeW = 22.0;
      const double badgeH = 10.0;
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w - badgeW - 1.0, 1.0, badgeW, badgeH),
        const Radius.circular(5.0),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()..color = const Color(0xFFF59E0B),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      final bestTextPainter = TextPainter(
        text: const TextSpan(
          text: 'BEST',
          style: TextStyle(
            fontSize: 5.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      bestTextPainter.layout();
      bestTextPainter.paint(
        canvas,
        Offset(
          w - badgeW - 1.0 + (badgeW - bestTextPainter.width) / 2.0,
          1.0 + (badgeH - bestTextPainter.height) / 2.0,
        ),
      );
    }

    final pic = recorder.endRecording();
    final img = await pic.toImage(
      (w * pixelRatio).ceil(),
      (h * pixelRatio).ceil(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
      width: w,
      height: h,
    );
  }

  Future<void> _updateMapMarkers() async {
    final int currentToken = ++_markerUpdateToken;
    final changers = _filteredMoneyChangers;

    final List<Marker> markerList = await Future.wait(
      changers.map((counter) async {
        final isSelected = counter.id == _selectedCounterId;
        final cacheKey = '${counter.id}_$isSelected';

        BitmapDescriptor icon = _customMarkerCache[cacheKey] ??
            await _generateCustomMarker(counter, isSelected: isSelected);
        _customMarkerCache[cacheKey] = icon;

        return Marker(
          markerId: MarkerId(counter.id),
          position: LatLng(counter.latitude, counter.longitude),
          icon: icon,
          anchor: const Offset(0.5, 0.95),
          zIndex: isSelected ? 10.0 : 1.0,
          infoWindow: InfoWindow(
            title: counter.brandName,
            snippet: '${counter.branchName} • ${_getCategoryLabel(counter.category)}',
            onTap: () => _showCounterDetailSheet(counter),
          ),
          onTap: () {
            setState(() {
              _selectedCounterId = counter.id;
            });
            _updateMapMarkers();
            if (_mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(counter.latitude, counter.longitude),
                ),
              );
            }
          },
        );
      }),
    );

    if (mounted && currentToken == _markerUpdateToken) {
      setState(() {
        _mapMarkers = markerList.toSet();
      });
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'bank':
        return _l('Official Bank', 'တရားဝင် ဘဏ်ခွဲ', 'สาขาธนาคาร');
      case 'atm':
        return _l('24/7 ATM', '24/7 ATM စက်', 'ตู้ ATM 24 ชม.');
      case 'exchange':
      default:
        return _l('Money Exchange', 'တရားဝင် ငွေလဲဆိုင်', 'ร้านแลกเงิน');
    }
  }

  List<_MoneyChangerCounter> get _filteredMoneyChangers {
    var list = _allMoneyChangers.where((changer) {
      // 1. Category filter
      if (_selectedCategory != 'all' && changer.category != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();

    // Pre-calculate distances once into a map (avoids O(N log N) Haversine in sort):
    final distances = <String, double>{};
    for (final c in list) {
      distances[c.id] = c.distanceTo(_userPosition);
    }

    // 2. Radius filter if user location is available and radius > 0
    if (_selectedRadiusKm > 0 && _userPosition != null) {
      final withinRadius = list
          .where((c) => (distances[c.id] ?? 999.0) <= _selectedRadiusKm)
          .toList();
      if (withinRadius.isNotEmpty) {
        list = withinRadius;
      }
    }

    // 3. Always sort ascending by distance to user (closest first) using O(1) map lookup
    list.sort((a, b) =>
        (distances[a.id] ?? 999.0).compareTo(distances[b.id] ?? 999.0));

    return list;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Real OpenStreetMap (OSM) Places Service
// Fetches real live Banks, Currency Exchanges & ATMs around user coordinates
// ─────────────────────────────────────────────────────────────────────────────

class _OsmPlacesService {
  _OsmPlacesService._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: const {
        'User-Agent': 'MyTogetherApp/1.0 (currency exchange nearby finder; contact@mytogether.app)',
        'Accept-Language': 'en, th;q=0.8',
      },
    ),
  );

  // In-memory cache keyed by "lat_lon_radius"
  static final Map<String, List<_MoneyChangerCounter>> _cache = {};

  static Future<List<_MoneyChangerCounter>> fetchNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 3.0,
  }) async {
    // 2-decimal key (~1.1km grid) to maximize cache hits and eliminate repeated network calls
    final key = '${(latitude * 100).round()}_${(longitude * 100).round()}_${radiusKm.round()}';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final delta = (radiusKm / 111.0).clamp(0.015, 0.15);
    final minLon = (longitude - delta).toStringAsFixed(5);
    final maxLat = (latitude + delta).toStringAsFixed(5);
    final maxLon = (longitude + delta).toStringAsFixed(5);
    final minLat = (latitude - delta).toStringAsFixed(5);
    final viewbox = '$minLon,$maxLat,$maxLon,$minLat';

    final rawResults = <Map<String, dynamic>>[];

    // Fetch currency exchange, bank, and atm in parallel from OpenStreetMap
    final categories = ['currency exchange', 'bank', 'atm'];

    try {
      final futures = categories.map((cat) async {
        try {
          final res = await _dio.get<List<dynamic>>(
            '/search',
            queryParameters: {
              'format': 'json',
              'q': cat,
              'viewbox': viewbox,
              'bounded': 1,
              'limit': 15,
              'addressdetails': 1,
            },
          );
          final data = res.data;
          if (data != null) {
            return data.whereType<Map<String, dynamic>>().toList();
          }
        } catch (_) {}
        return <Map<String, dynamic>>[];
      }).toList();

      final results = await Future.wait(futures);
      for (final list in results) {
        rawResults.addAll(list);
      }
    } catch (_) {}

    if (rawResults.isEmpty) {
      return [];
    }

    final seenOsmIds = <String>{};
    final counters = <_MoneyChangerCounter>[];

    for (final item in rawResults) {
      final osmId = '${item['osm_type'] ?? 'node'}_${item['osm_id'] ?? item['place_id']}';
      if (!seenOsmIds.add(osmId)) continue;

      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      if (lat == null || lon == null) continue;

      final rawName = (item['name']?.toString() ?? '').trim();
      final displayName = (item['display_name']?.toString() ?? '').trim();
      final type = (item['type']?.toString() ?? '').toLowerCase();
      final address = item['address'] as Map<String, dynamic>? ?? {};

      final combined = '$rawName $displayName $type'.toLowerCase();

      // Determine category
      String category = 'bank';
      if (type == 'bureau_de_change' ||
          type == 'money_transfer' ||
          combined.contains('exchange') ||
          combined.contains('superrich') ||
          combined.contains('super rich') ||
          combined.contains('currency') ||
          combined.contains('forex')) {
        category = 'exchange';
      } else if (type == 'atm' || combined.contains('atm')) {
        category = 'atm';
      }

      // Bank branding and logos
      String? logoAsset;
      Color brandColor = const Color(0xFF3B82F6);
      String brandName = rawName.isNotEmpty ? rawName : (category == 'atm' ? 'ATM' : 'Bank Branch');
      String phone = '+6620000000';

      if (combined.contains('kasikorn') || combined.contains('kbank')) {
        logoAsset = 'assets/images/banks/KBANK.png';
        brandColor = const Color(0xFF059669);
        brandName = category == 'atm' ? 'KBank ATM' : 'Kasikorn Bank (KBank)';
        phone = '+6628888888';
      } else if (combined.contains('bangkok bank') || combined.contains('bbl')) {
        logoAsset = 'assets/images/banks/BBL.png';
        brandColor = const Color(0xFF1E40AF);
        brandName = category == 'atm' ? 'Bangkok Bank ATM' : 'Bangkok Bank (BBL)';
        phone = '+6626455555';
      } else if (combined.contains('siam commercial') || combined.contains('scb')) {
        logoAsset = 'assets/images/banks/SCB.png';
        brandColor = const Color(0xFF4C1D95);
        brandName = category == 'atm' ? 'SCB ATM' : 'Siam Commercial Bank (SCB)';
        phone = '+6627777777';
      } else if (combined.contains('krungthai') || combined.contains('ktb')) {
        logoAsset = 'assets/images/banks/KTB.png';
        brandColor = const Color(0xFF0284C7);
        brandName = category == 'atm' ? 'Krungthai ATM' : 'Krungthai Bank (KTB)';
        phone = '+6621111111';
      } else if (combined.contains('ttb') || combined.contains('tmb') || combined.contains('thanachart')) {
        logoAsset = 'assets/images/banks/TTB.png';
        brandColor = const Color(0xFF2563EB);
        brandName = category == 'atm' ? 'ttb ATM' : 'TMBThanachart (ttb)';
        phone = '+661428';
      } else if (combined.contains('krungsri') || combined.contains('ayudhya')) {
        brandColor = const Color(0xFFFBBF24);
        brandName = category == 'atm' ? 'Krungsri ATM' : 'Bank of Ayudhya (Krungsri)';
        phone = '+661572';
      } else if (combined.contains('superrich') || combined.contains('super rich')) {
        logoAsset = 'assets/images/services/exchange_3d.png';
        brandColor = const Color(0xFFFF5E00);
        brandName = 'SuperRich Thailand';
        phone = '+6620544000';
      } else if (category == 'exchange') {
        logoAsset = 'assets/images/services/exchange_3d.png';
        brandColor = const Color(0xFFFF7A00);
      }

      final road = address['road']?.toString() ?? '';
      final suburb = address['suburb']?.toString() ??
          address['neighbourhood']?.toString() ??
          address['city_district']?.toString() ??
          address['city']?.toString() ??
          '';
      final areaLabel = suburb.isNotEmpty ? suburb : (road.isNotEmpty ? road : 'OpenStreetMap Live');
      final branchName = rawName.isNotEmpty && rawName != brandName
          ? rawName
          : (road.isNotEmpty ? '$road Branch' : (suburb.isNotEmpty ? '$suburb Branch' : 'Live Counter'));
      final landmark = road.isNotEmpty ? road : (suburb.isNotEmpty ? suburb : 'OpenStreetMap Live Data');

      final distKm = Geolocator.distanceBetween(latitude, longitude, lat, lon) / 1000.0;

      final counter = _MoneyChangerCounter(
        id: 'osm_$osmId',
        brandName: brandName,
        branchName: branchName,
        area: areaLabel,
        landmark: landmark,
        defaultDistanceKm: double.parse(distKm.toStringAsFixed(2)),
        latitude: lat,
        longitude: lon,
        openHours: category == 'atm' ? '24/7 (ATM)' : '08:30 - 17:30',
        isOpenNow: true,
        thbToMmkBuy: category == 'atm' ? 0.0 : 141.50,
        thbToMmkSell: category == 'atm' ? 0.0 : 143.80,
        phone: phone,
        mapQuery: '$brandName $areaLabel',
        brandColor: brandColor,
        isNearBts: displayName.toLowerCase().contains('bts') || displayName.toLowerCase().contains('mrt'),
        tags: [
          'OSM Live Data',
          category == 'atm' ? 'ATM' : (category == 'exchange' ? 'ငွေလဲဆိုင်' : 'တရားဝင် ဘဏ်ခွဲ'),
          if (phone != '+6620000000') 'တရားဝင်',
        ],
        fullAddress: displayName,
        exchangeTips: category == 'atm'
            ? 'နိုင်ငံတကာ Master/Visa ကတ်များဖြင့် ၂၄ နာရီ ငွေထုတ်ယူနိုင်ပါသည်။'
            : 'တရားဝင် Passport မူရင်းဖြင့် လဲလှယ်နိုင်ပါသည်။',
        category: category,
        supportedCards: const ['Visa', 'Mastercard', 'UnionPay', 'JCB', 'Cirrus'],
        withdrawalLimit: category == 'atm' ? '20,000 - 30,000 THB / transaction' : null,
        atmFee: category == 'atm' ? '220 THB' : null,
        logoAsset: logoAsset,
      );

      counters.add(counter);
    }

    _cache[key] = counters;
    return counters;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Money Changer Counter Model
// ─────────────────────────────────────────────────────────────────────────────

class _MoneyChangerCounter {
  final String id;
  final String brandName;
  final String branchName;
  final String area;
  final String landmark;
  final double defaultDistanceKm;
  final double latitude;
  final double longitude;
  final String openHours;
  final bool isOpenNow;
  final double thbToMmkBuy;
  final double thbToMmkSell;
  final double usdToThbBuy;
  final double usdToThbSell;
  final String phone;
  final String mapQuery;
  final Color brandColor;
  final bool isBestRate;
  final bool isNearBts;
  final List<String> tags;
  final String fullAddress;
  final String exchangeTips;
  final String category; // 'exchange', 'bank', 'atm'
  final List<String> supportedCards;
  final String? withdrawalLimit;
  final String? atmFee;
  final String? logoAsset;

  const _MoneyChangerCounter({
    required this.id,
    required this.brandName,
    required this.branchName,
    required this.area,
    required this.landmark,
    required this.defaultDistanceKm,
    required this.latitude,
    required this.longitude,
    required this.openHours,
    required this.isOpenNow,
    this.thbToMmkBuy = 0.0,
    this.thbToMmkSell = 0.0,
    this.usdToThbBuy = 0.0,
    this.usdToThbSell = 0.0,
    required this.phone,
    required this.mapQuery,
    required this.brandColor,
    this.isBestRate = false,
    this.isNearBts = false,
    required this.tags,
    required this.fullAddress,
    required this.exchangeTips,
    this.category = 'exchange',
    this.supportedCards = const [],
    this.withdrawalLimit,
    this.atmFee,
    this.logoAsset,
  });

  double distanceTo(Position? userPosition) {
    if (userPosition == null) return defaultDistanceKm;
    final meters = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      latitude,
      longitude,
    );
    return meters / 1000.0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unified Shimmer Scope & Shimmer Box for Lazy Loading
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerScope extends StatefulWidget {
  final Widget child;
  const _ShimmerScope({required this.child});

  @override
  State<_ShimmerScope> createState() => _ShimmerScopeState();

  static _ShimmerScopeState? of(BuildContext context) {
    return context.findAncestorStateOfType<_ShimmerScopeState>();
  }
}

class _ShimmerScopeState extends State<_ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> get animation => _animation;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final BoxBorder? border;

  const _ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.baseColor,
    this.highlightColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final scope = _ShimmerScope.of(context);
    final base = baseColor ?? const Color(0xFFE2E8F0);
    final highlight = highlightColor ?? Colors.white.withValues(alpha: 0.90);

    if (scope == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
        ),
      );
    }

    return AnimatedBuilder(
      animation: scope.animation,
      builder: (context, child) {
        final val = scope.animation.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: border,
            gradient: LinearGradient(
              begin: Alignment(-2.0 + (4.0 * val), -0.2),
              end: Alignment(-0.5 + (4.0 * val), 0.2),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
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
    if (data.isEmpty) return;

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
          .clamp(leftMargin, size.width - rightMargin - boxWidth);
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
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: 0.85, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
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
        clipBehavior: Clip.none,
        children: [
          // Radiating Pulse Ring in Primary Gradient
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.primary.withValues(
                          alpha: _opacityAnimation.value,
                        ),
                        AppColors.secondary.withValues(
                          alpha: _opacityAnimation.value,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Core Dot with Primary Gradient & soft glow
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.65),
                  blurRadius: 4,
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
