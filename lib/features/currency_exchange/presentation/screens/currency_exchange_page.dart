import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import '../../data/models/currency_rate_model.dart';
import '../../data/repositories/currency_exchange_repository.dart';

class CurrencyExchangePage extends StatefulWidget {
  const CurrencyExchangePage({super.key});

  @override
  State<CurrencyExchangePage> createState() => _CurrencyExchangePageState();
}

class _CurrencyExchangePageState extends State<CurrencyExchangePage> {
  static List<Color> get _primaryGradient => AppColors.primaryGradient.colors;
  static const Color _bgColor = Color(0xFFF5F5F5);

  List<CurrencyRateModel> _rates = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  String _timestamp = '';

  CurrencyRateModel? _selectedCurrency;
  bool _isBuy = true; // true = Buy, false = Sell

  final TextEditingController _mmkController = TextEditingController();
  final TextEditingController _foreignController = TextEditingController();

  final NumberFormat _amountFormat = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  @override
  void dispose() {
    _mmkController.dispose();
    _foreignController.dispose();
    super.dispose();
  }

  Future<void> _fetchRates({bool forceRefresh = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      if (forceRefresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      final result = await CurrencyExchangeRepository.instance.fetchRates(
        forceRefresh: forceRefresh,
      );
      // Sort to prioritize requested sequence
      const priority = ['THB', 'USD', 'SGD', 'MYR', 'VND', 'JPY', 'GBP'];
      result.rates.sort((a, b) {
        final indexA = priority.indexOf(a.currency);
        final indexB = priority.indexOf(b.currency);

        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return a.currency.compareTo(b.currency);
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _rates = result.rates;
        _timestamp = result.timestamp;
        _isLoading = false;
        _isRefreshing = false;
        if (_selectedCurrency == null && _rates.isNotEmpty) {
          _selectedCurrency = _rates.firstWhere(
            (r) => r.currency == 'THB',
            orElse: () => _rates.first,
          );
        } else if (_selectedCurrency != null) {
          // Re-sync the selected currency instance from the new list
          _selectedCurrency = _rates.firstWhere(
            (r) => r.currency == _selectedCurrency!.currency,
            orElse: () => _rates.first,
          );
        }
        _recalculateForeignToMMK(); // Initial calc based on empty or zero
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to load exchange rates. Please check your connection.';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  double get _currentRate {
    if (_selectedCurrency == null) return 1.0;
    return _isBuy ? _selectedCurrency!.buy : _selectedCurrency!.sell;
  }

  void _recalculateMMKToForeign() {
    final rawMMK = _mmkController.text.trim().replaceAll(',', '');
    final mmkAmount = double.tryParse(rawMMK);
    if (mmkAmount == null) {
      _foreignController.text = '';
      return;
    }
    final foreignAmount = mmkAmount / _currentRate;
    _foreignController.text = _amountFormat.format(foreignAmount);
  }

  void _recalculateForeignToMMK() {
    final rawForeign = _foreignController.text.trim().replaceAll(',', '');
    final foreignAmount = double.tryParse(rawForeign);
    if (foreignAmount == null) {
      _mmkController.text = '';
      return;
    }
    final mmkAmount = foreignAmount * _currentRate;
    _mmkController.text = _amountFormat.format(mmkAmount);
  }

  void _onToggleBuySell(bool isBuy) {
    if (_isBuy == isBuy) {
      return;
    }
    setState(() {
      _isBuy = isBuy;
      _recalculateForeignToMMK();
    });
  }

  String _formatRate(double value) {
    return NumberFormat('#,##0.##', 'en_US').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
          ),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_isRefreshing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () => _fetchRates(forceRefresh: true),
              ),
          ],
        ),
        body: _isLoading
            ? _buildSkeletonLoading()
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIcons.warningCircle,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      PrimaryGradientButton(
                        width: 120,
                        height: 45,
                        onPressed: () => _fetchRates(forceRefresh: true),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopCalculatorSection(),
                    _buildLatestRatesSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTopCalculatorSection() {
    final now = DateTime.now();
    final todayStr = DateFormat('dd MMM, yyyy').format(now);

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date
          Text(
            todayStr,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          // Welcome Row & Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Welcome',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildBuySellToggle(),
            ],
          ),
          const SizedBox(height: 32),
          // MMK Input Box
          _buildInputCard(
            controller: _mmkController,
            suffixText: 'MMK',
            onChanged: (v) => _recalculateMMKToForeign(),
            trailingWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇲🇲', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'MMK',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Equals Sign
          Center(
            child: Icon(PhosphorIcons.equals, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          // Foreign Input Box
          _buildInputCard(
            controller: _foreignController,
            suffixText: _selectedCurrency?.currency ?? '',
            onChanged: (v) => _recalculateForeignToMMK(),
            trailingWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CurrencyRateModel>(
                  value: _selectedCurrency,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  items: _rates.map((rate) {
                    return DropdownMenuItem<CurrencyRateModel>(
                      value: rate,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rate.flagEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            rate.currency,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCurrency = val;
                        _recalculateForeignToMMK();
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Info Info
          if (_selectedCurrency != null) ...[
            Center(
              child: Text(
                '${_selectedCurrency!.flagEmoji} 1 ${_selectedCurrency!.currency} = 🇲🇲 ${_formatRate(_currentRate)} MMK',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'As of $_timestamp',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBuySellToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _onToggleBuySell(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _isBuy ? null : Colors.transparent,
                gradient: _isBuy
                    ? LinearGradient(
                        colors: _primaryGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Buy',
                style: GoogleFonts.poppins(
                  color: _isBuy ? Colors.white : Colors.black87,
                  fontWeight: _isBuy ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _onToggleBuySell(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: !_isBuy ? null : Colors.transparent,
                gradient: !_isBuy
                    ? LinearGradient(
                        colors: _primaryGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Sell',
                style: GoogleFonts.poppins(
                  color: !_isBuy ? Colors.white : Colors.black87,
                  fontWeight: !_isBuy ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({
    required TextEditingController controller,
    required String suffixText,
    required Widget trailingWidget,
    required Function(String) onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                suffixText: suffixText,
                suffixStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        trailingWidget,
      ],
    );
  }

  Widget _buildLatestRatesSection() {
    return Container(
      decoration: const BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Latest Rate',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'These rates are approximate street prices for informational purposes only.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rates.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final rate = _rates[index];
              return _buildRateCard(rate);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRateCard(CurrencyRateModel rate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Flag & Name
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Text(rate.flagEmoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rate.currency,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Buy
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Buy',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 9,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatRate(rate.buy),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Sell
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sell',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 9,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatRate(rate.sell),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Simulated Top Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const _ShimmerBox(width: 150, height: 24, opacity: 0.3),
                const SizedBox(height: 8),
                const _ShimmerBox(width: 100, height: 16, opacity: 0.2),
                const SizedBox(height: 32),
                // MMK Input Box
                _ShimmerBox(
                  width: double.infinity,
                  height: 80,
                  borderRadius: 16,
                  opacity: 0.3,
                ),
                const SizedBox(height: 12),
                const _ShimmerBox(width: 24, height: 24, opacity: 0.3),
                const SizedBox(height: 12),
                // Foreign Input Box
                _ShimmerBox(
                  width: double.infinity,
                  height: 80,
                  borderRadius: 16,
                  opacity: 0.3,
                ),
                const SizedBox(height: 24),
                const _ShimmerBox(width: 180, height: 16, opacity: 0.2),
              ],
            ),
          ),
          // Simulated List Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ShimmerBox(width: 120, height: 20),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    _ShimmerBox(width: 14, height: 14, opacity: 0.2),
                    SizedBox(width: 8),
                    _ShimmerBox(width: 220, height: 11, opacity: 0.15),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) => const _ShimmerBox(
                    width: double.infinity,
                    height: 70,
                    borderRadius: 16,
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

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final double opacity;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.opacity = 0.1,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey.withValues(alpha: widget.opacity),
                Colors.grey.withValues(alpha: widget.opacity + 0.1),
                Colors.grey.withValues(alpha: widget.opacity),
              ],
              stops: [0.0, _controller.value, 1.0],
            ),
          ),
        );
      },
    );
  }
}
