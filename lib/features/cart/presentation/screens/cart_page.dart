import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../home/presentation/widgets/image_skeleton_loader.dart';
import '../../data/cart_manager.dart';
import '../../../../core/presentation/widgets/global_modal.dart';
import '../widgets/confirm_remove_modal.dart';
import 'order_summary_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_translations.dart';

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
              context.tr('cart.title'),
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
                        context.tr('cart.select_shop'),
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
          Icon(PhosphorIcons.shoppingCart, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            context.tr('cart.empty'),
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreItem(CartStore store) {
    return Slidable(
      key: Key(store.nameKey),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) {
              GlobalModal.show(
                context: context,
                child: ConfirmRemoveModal(
                  title: context.tr('cart.remove_shop'),
                  message: context.tr('cart.remove_shop_confirm'),
                  onConfirm: () async {
                    await CartManager.instance.removeStore(store.nameKey);
                  },
                ),
              );
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: context.tr('common.remove'),
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
                    '${context.trArgs(store.items.fold(0, (int sum, item) => sum + item.quantity) == 1 ? 'cart.item' : 'cart.items', {'count': store.items.fold(0, (int sum, item) => sum + item.quantity).toString()})}  •  ${context.tr('cart.from')} ${store.time}  •  ${store.distance}',
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
                          context.tr('cart.closed_now'),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.circle, size: 3, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('cart.order_tomorrow'),
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
            _buildStoreThumbnail(store),
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

  Widget _buildStoreThumbnail(CartStore store) {
    final shopImage = store.shopImageUrl;
    if (shopImage != null && shopImage.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: CachedNetworkImage(
            imageUrl: shopImage,
            fit: BoxFit.cover,
            width: 60,
            height: 60,
            placeholder: (_, _) => const ImageSkeletonLoader(width: 60, height: 60),
            errorWidget: (_, _, _) => _buildImageStack(
              store.items.map((i) => i.imagePath).toList(),
            ),
          ),
        ),
      );
    }
    return _buildImageStack(store.items.map((i) => i.imagePath).toList());
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
                  fit: BoxFit.cover,
                  width: 50,
                  height: 50,
                  placeholder: (context, url) => const ImageSkeletonLoader(width: 50, height: 50),
                  errorWidget: (context, url, error) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[100],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 24),
                      ],
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
