import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mytogetherapp/features/order/data/models/demo_order_data.dart';

class DeliveryTrackerStrip extends StatelessWidget {
  final DemoOrder order;
  final VoidCallback onTrackPressed;

  const DeliveryTrackerStrip({
    super.key,
    required this.order,
    required this.onTrackPressed,
  });

  Color get primaryColor => const Color(0xFFED3A72);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
               Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.deliveryStatusTitle,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    order.deliveryStatusSubtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Shop Logo (Starbucks in mock)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ClipOval(
                  child: Image.network(
                    order.shopLogoUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Progress Bar
          _buildProgressTracker(),
          
          const SizedBox(height: 20),
          
          // Track Order Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTrackPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100), // Pill shape
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.bicycle(PhosphorIconsStyle.fill)),
                  const SizedBox(width: 8),
                  Text(
                    'Track Order',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTracker() {
    return Row(
      children: [
        _buildStep(PhosphorIcons.package(PhosphorIconsStyle.fill), true),
        _buildLine(true),
        _buildStep(PhosphorIcons.cookingPot(PhosphorIconsStyle.fill), true),
        _buildLine(true),
        _buildStep(PhosphorIcons.bicycle(PhosphorIconsStyle.fill), true), // Bicycle step
        _buildLine(false),
        _buildStep(PhosphorIcons.house(), false),
      ],
    );
  }

  Widget _buildStep(IconData icon, bool isFilled) {
    return Icon(
      icon,
      size: 26,
      color: isFilled ? primaryColor : Colors.grey[400],
    );
  }
  


  Widget _buildLine(bool isFilled) {
    return Expanded(
      child: Container(
        height: 3,
        color: isFilled ? primaryColor : Colors.grey[200],
      ),
    );
  }
}
