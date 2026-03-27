import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/features/order/data/models/demo_order_data.dart';
import 'package:mytogetherapp/features/order/presentation/widgets/order_history_card.dart';
import 'package:mytogetherapp/features/order/presentation/widgets/delivery_tracker_strip.dart';
// Note: we can use standard circular progress indicator or a custom skeleton. We will build a basic skeleton here for demo purposes.

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> with TickerProviderStateMixin {
  bool _isLoading = true;
  TabController? _tabController;
  
  @override
  void initState() {
    super.initState();
    _loadDemoData();
  }
  
  Future<void> _loadDemoData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _initTabController();
      });
    }
  }
  
  void _initTabController() {
    if (_tabController != null) {
      _tabController!.dispose();
    }
    
    int tabCount = demoActiveOrders.isNotEmpty ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveOrders = demoActiveOrders.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Order History',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: _isLoading ? null : TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFED3A72),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFED3A72),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: [
            if (hasActiveOrders) const Tab(text: 'Active'),
            const Tab(text: 'Completed'),
            const Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _isLoading 
        ? _buildSkeletonLoading()
        : TabBarView(
            controller: _tabController,
            children: [
              if (hasActiveOrders) _buildActiveTab(),
              _buildOrdersList(demoCompletedOrders, 'No Completed Orders'),
              _buildOrdersList(demoCancelledOrders, 'No Cancelled Orders'),
            ],
          ),
    );
  }

  Widget _buildActiveTab() {
    // If no active orders, this shouldn't be rendered anyway based on tabs.
    // However, if we're here, we have active orders.
    // The requirement says we need a list of active orders, and a persistent delivery tracker strip.
    return Stack(
      children: [
        // Main list
        RefreshIndicator(
          onRefresh: _loadDemoData,
          color: const Color(0xFFED3A72),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 200), // Extra padding for the tracker strip
            itemCount: demoActiveOrders.length,
            itemBuilder: (context, index) {
               return OrderHistoryCard(order: demoActiveOrders[index]);
            },
          ),
        ),
        // Persistent Strip pinned to bottom
        if (demoActiveOrders.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DeliveryTrackerStrip(
              order: demoActiveOrders.first,
              onTrackPressed: () {
                // Mock action
              },
            ),
          ),
      ],
    );
  }

  Widget _buildOrdersList(List<DemoOrder> orders, String emptyTitle) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDemoData,
        color: const Color(0xFFED3A72),
        // Need a scrollable widget so RefreshIndicator works even when empty
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmptyState(),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDemoData,
      color: const Color(0xFFED3A72),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return OrderHistoryCard(order: orders[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration Placeholder
          Container(
             width: 150,
             height: 150,
             decoration: BoxDecoration(
               color: Colors.grey[200],
               shape: BoxShape.circle,
             ),
             child: Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'No order yet!',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      itemCount: 3,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                   children: [
                     Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8))),
                     const SizedBox(width: 12),
                     Container(width: 120, height: 16, color: Colors.grey[200]),
                     const Spacer(),
                     Container(width: 60, height: 16, color: Colors.grey[200]),
                   ],
                ),
                const SizedBox(height: 20),
                Row(
                   children: [
                     Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8))),
                     const SizedBox(width: 8),
                     Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8))),
                     const Spacer(),
                     Container(width: 80, height: 16, color: Colors.grey[200]),
                   ],
                ),
                const Spacer(),
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      Container(width: 100, height: 14, color: Colors.grey[200]),
                      Container(width: 100, height: 36, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(100))),
                   ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
