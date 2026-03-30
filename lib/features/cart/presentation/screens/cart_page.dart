import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../home/presentation/widgets/image_skeleton_loader.dart';
import '../../data/cart_manager.dart';
import '../../../../core/presentation/widgets/global_modal.dart';
import '../widgets/confirm_remove_modal.dart';
import 'order_summary_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  void initState() {
    super.initState();
    // Fetch latest cart data from backend
    CartManager.instance.syncWithApi();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartManager.instance,
      builder: (context, _) {
        final stores = CartManager.instance.stores;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                color: Colors.black.withValues(alpha: 0.05),
                height: 1,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              'My Cart',
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: stores.isEmpty
              ? _buildEmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Select Shop',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: stores.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        itemBuilder: (context, index) {
                          final store = stores[index];
                          return _buildStoreItemWrapper(context, store);
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.shoppingCart(), size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreItem(CartStore store) {
    return Slidable(
      key: Key(store.name),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) {
              GlobalModal.show(
                context: context,
                child: ConfirmRemoveModal(
                  title: 'Remove Shop',
                  message: 'Are you sure you want to remove this shop and all its items from your cart?',
                  onConfirm: () async {
                    await CartManager.instance.removeStore(store.name);
                  },
                ),
              );
            },
            backgroundColor: const Color(0xFFED3973),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Remove',
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${store.items.fold(0, (int sum, item) => sum + item.quantity)} ${store.items.fold(0, (int sum, item) => sum + item.quantity) == 1 ? 'item' : 'items'}  •  From ${store.time}  •  ${store.distance}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (store.isClosed) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Closed Now',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFFED3973),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.circle, size: 3, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Order tomorrow 9:00 AM',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildImageStack(store.items.map((i) => i.imagePath).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreItemWrapper(BuildContext context, CartStore store) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderSummaryPage(store: store),
            ),
          );
        },
        child: _buildStoreItem(store),
      ),
    );
  }

  Widget _buildImageStack(List<String> images) {
    // Take unique images to show variety, limited to 4
    final displayImages = images.toSet().take(4).toList();
    
    return SizedBox(
      width: 90,
      height: 60,
      child: Stack(
        children: List.generate(displayImages.length, (index) {
          return Positioned(
            right: index * 12.0,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: displayImages[displayImages.length - 1 - index],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const ImageSkeletonLoader(width: 50, height: 50),
                  errorWidget: (context, url, error) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[100],
                    child: Center(
                      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 24),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
