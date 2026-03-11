import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/active_order_state.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';

class OrderCompletePage extends StatefulWidget {
  const OrderCompletePage({super.key});

  @override
  State<OrderCompletePage> createState() => _OrderCompletePageState();
}

class _OrderCompletePageState extends State<OrderCompletePage> {
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    // We don't clear the order here anymore so it remains in the tracking card
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ActiveOrderState.instance.setOrderStatus(4); // 4 = Completed
    });
  }

  void _goToFoodTab() {
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = ActiveOrderState.instance;
    final storeName = state.restaurantName ?? state.storeName ?? 'Restaurant';
    final total = state.totalAmount ?? 0.0;
    
    // In a real app we'd format actual Arrival time, mocked for now
    final now = DateTime.now();
    final arrivalTime = '${now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final logoPath = state.logoPath;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            _goToFoodTab();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Completed',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arrived at: $arrivalTime',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            
            // Progress Bar (all filled)
            _buildProgressBar(),
            const SizedBox(height: 32),

            // Rating Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    child: Column(
                      children: [
                        // Logo with lazy-load and no-image fallback
                        ClipOval(
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: (logoPath != null && logoPath.isNotEmpty)
                              ? Image.network(
                                  logoPath,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                    if (wasSynchronouslyLoaded || frame != null) return child;
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Center(child: CustomLoadingIndicator(size: 24)),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) => _buildNoImageAvatar(),
                                )
                              : _buildNoImageAvatar(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Rate Your Experience at $storeName',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your feedback helps improve food quality and delivery service.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        // Stars
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final isSelected = _rating > index;
                            return GestureDetector(
                              onTap: () => setState(() => _rating = index + 1),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 44,
                                  color: isSelected ? const Color(0xFFFBBF24) : const Color(0xFFCBD5E1),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB), indent: 20, endIndent: 20),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(
                        'Total',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${total.toStringAsFixed(0)} ฿',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFED3973),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(PhosphorIcons.caretDown(), size: 16, color: Colors.grey[600]),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Items ordered will be displayed here.', 
                                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // "Done" button to clear order and go home
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  ActiveOrderState.instance.clearOrder();
                  _goToFoodTab();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFED3973),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImageAvatar() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: const Icon(Icons.image_not_supported_rounded, size: 36, color: Colors.grey),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        _buildStepNode(PhosphorIcons.wallet()),
        _buildStepLine(),
        _buildStepNode(PhosphorIcons.cookingPot()),
        _buildStepLine(),
        _buildStepNode(PhosphorIcons.moped()),
        _buildStepLine(),
        _buildStepNode(PhosphorIcons.house()),
      ],
    );
  }

  Widget _buildStepNode(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFFED3973),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }

  Widget _buildStepLine() {
    return Expanded(
      child: Container(
        height: 3,
        color: const Color(0xFFED3973),
      ),
    );
  }
}
