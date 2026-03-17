import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/features/order/data/repositories/order_repository.dart';
import 'package:mytogetherapp/features/order/data/models/order_history_dto.dart';
import 'package:mytogetherapp/features/order/presentation/widgets/order_history_card.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> with SingleTickerProviderStateMixin {
  late Future<OrderHistoryGroupedDto?> _ordersFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshOrders();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = OrderRepository().getGroupedOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Orders',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFED3A72),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFED3A72),
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'Past Orders'),
          ],
        ),
      ),
      body: FutureBuilder<OrderHistoryGroupedDto?>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomLoadingIndicator());
          }
          
          if (snapshot.hasError || snapshot.data == null) {
            return _buildEmptyState('Something went wrong', 'Could not load your orders');
          }

          final currentOrders = snapshot.data!.currentOrders;
          final pastOrders = snapshot.data!.pastOrders;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersList(currentOrders, 'No ongoing orders', 'New orders will appear here'),
              _buildOrdersList(pastOrders, 'No past orders yet', 'Your order history will appear here'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(List<OrderHistoryDto> orders, String emptyTitle, String emptySubtitle) {
    if (orders.isEmpty) {
      return _buildEmptyState(emptyTitle, emptySubtitle);
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshOrders(),
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

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[200],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
