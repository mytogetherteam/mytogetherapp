import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'dart:math';

import '../../data/models/currency_rate_model.dart';

class CurrencyDetailPage extends StatefulWidget {
  final CurrencyRateModel currencyRate;
  
  const CurrencyDetailPage({super.key, required this.currencyRate});

  @override
  State<CurrencyDetailPage> createState() => _CurrencyDetailPageState();
}

class _CurrencyDetailPageState extends State<CurrencyDetailPage> {
  static const Color _bgColor = Color(0xFFF5F5F5);
  bool _isBuy = true;

  final TextEditingController _foreignController = TextEditingController();
  final TextEditingController _mmkController = TextEditingController();
  final NumberFormat _amountFormat = NumberFormat('#,##0.##', 'en_US');
  
  // Mock historical data for the chart
  final List<double> _historicalData = [];

  @override
  void initState() {
    super.initState();
    _foreignController.text = '1';
    _recalculateForeignToMMK();
    _generateMockHistory();
  }

  void _generateMockHistory() {
    final random = Random();
    final baseRate = _currentRate;
    
    // Generate 7 days of slightly fluctuating data
    for (int i = 0; i < 7; i++) {
      final fluctuation = baseRate * (random.nextDouble() * 0.02 - 0.01); // +/- 1%
      _historicalData.add(baseRate + fluctuation);
    }
    _historicalData.add(baseRate); // Today's rate
  }

  @override
  void dispose() {
    _foreignController.dispose();
    _mmkController.dispose();
    super.dispose();
  }

  double get _currentRate => _isBuy ? widget.currencyRate.buy : widget.currencyRate.sell;

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

  void _onToggleBuySell(bool isBuy) {
    if (_isBuy == isBuy) return;
    setState(() {
      _isBuy = isBuy;
      _recalculateForeignToMMK();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.currencyRate.flagEmoji} ${widget.currencyRate.currency} Details',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section (Chart)
            _buildChartSection(),
            
            // Middle Section (Current Rates)
            _buildCurrentRates(),
            
            // Bottom Section (Converter)
            _buildConverterSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '7-Day History',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _ChartPainter(
                data: _historicalData,
                lineColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentRates() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildRateColumn('Buy', widget.currencyRate.buy, Colors.green),
          Container(height: 40, width: 1, color: Colors.grey.shade300),
          _buildRateColumn('Sell', widget.currencyRate.sell, Colors.red),
        ],
      ),
    );
  }

  Widget _buildRateColumn(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _amountFormat.format(value),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildConverterSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Convert',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Toggle Buy/Sell
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onToggleBuySell(true),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isBuy ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _isBuy
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Buy',
                          style: GoogleFonts.poppins(
                            fontWeight: _isBuy ? FontWeight.w600 : FontWeight.w500,
                            color: _isBuy ? AppColors.primary : Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onToggleBuySell(false),
                    child: Container(
                      decoration: BoxDecoration(
                        color: !_isBuy ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_isBuy
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Sell',
                          style: GoogleFonts.poppins(
                            fontWeight: !_isBuy ? FontWeight.w600 : FontWeight.w500,
                            color: !_isBuy ? AppColors.primary : Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Foreign Input
          _buildInputRow(
            controller: _foreignController,
            label: widget.currencyRate.currency,
            flag: widget.currencyRate.flagEmoji,
            onChanged: (val) => _recalculateForeignToMMK(),
          ),
          
          // Swap Icon
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.swap_vert,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ),
          ),
          
          // MMK Input
          _buildInputRow(
            controller: _mmkController,
            label: 'MMK',
            flag: '🇲🇲',
            onChanged: (val) => _recalculateMMKToForeign(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({
    required TextEditingController controller,
    required String label,
    required String flag,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Flag and Label
          Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 30,
            width: 1,
            color: Colors.grey.shade300,
          ),
          // Input
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;

  _ChartPainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double maxVal = data.reduce(max);
    final double minVal = data.reduce(min);
    final double range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    final double xStep = size.width / (data.length - 1);
    
    for (int i = 0; i < data.length; i++) {
      // Add padding to top and bottom
      final double normalizedY = (data[i] - minVal) / range;
      final double y = size.height - (normalizedY * (size.height * 0.8) + (size.height * 0.1));
      final double x = i * xStep;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
    
    // Add gradient fill under the line
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.3),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.lineColor != lineColor;
  }
}
