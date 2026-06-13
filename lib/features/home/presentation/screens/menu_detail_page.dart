import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../widgets/image_skeleton_loader.dart';
import '../widgets/review_card.dart';
import '../widgets/view_all_icon_button.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../cart/data/cart_repository.dart';
import '../../../cart/data/cart_manager.dart';
import '../../../cart/data/models/cart_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/food_detail_dto.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/menu_image_placeholder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';

class MenuDetailPage extends StatefulWidget {
  final String id;
  final String restaurantId;
  final String title;
  final String description;
  final double price;
  final String currency;
  final String imagePath;
  final double rating;
  final int reviewCount;
  final String restaurantName;
  final String? displayPrice;

  const MenuDetailPage({
    super.key,
    required this.id,
    required this.restaurantId,
    required this.title,
    this.description = '',
    required this.price,
    this.currency = '',
    required this.imagePath,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.restaurantName = '',
    this.displayPrice,
    this.initialVariantId,
    this.initialOptionIds,
    this.initialInstructions,
    this.cartItemId,
    this.isFavorite,
  });

  final int? initialVariantId;
  final List<int>? initialOptionIds;
  final String? initialInstructions;
  final String? cartItemId;
  final bool? isFavorite;

  @override
  State<MenuDetailPage> createState() => _MenuDetailPageState();
}

class _MenuDetailPageState extends State<MenuDetailPage> {
  // Food Detail state
  FoodDetailDto? _currentFood;
  bool _isLoading = true;

  int? _selectedVariantId;
  // Map<optionGroupId, Set<optionId>>
  final Map<int, Set<int>> _selectedOptions = {};

  // Scroll Controller for Icon Colors
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  // Quantity state
  int _quantity = 1;

  // Favorite state
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;

  // Special instructions
  final TextEditingController _instructionsController = TextEditingController();

  // Mock recommended items - To be replaced by API if available
  final List<Map<String, String>> _recommendedItems = [];

  final List<Map<String, dynamic>> _reviews = [];

  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _instructionsController.text = widget.initialInstructions ?? '';
    _instructionsController.addListener(() {
      setState(() {});
    });
    CartManager.instance.addListener(_onCartChanged);
    _initializeSelections();

    // Check if item is in cart to fulfill user expectation that "Add to Cart" = "Filled Heart"
    final isInCart =
        CartManager.instance.getStoreItemCount(widget.restaurantName) > 0 &&
        CartManager.instance.findItem(
              widget.restaurantName,
              int.tryParse(widget.id) ?? 0,
            ) !=
            null;
    _isFavorite = widget.isFavorite ?? isInCart;

    _fetchFoodDetails();
  }

  void _initializeSelections() {
    _selectedVariantId = widget.initialVariantId;
    if (widget.initialOptionIds != null) {
      // Note: We don't have the group assignment yet, so we'll need to
      // map these once _currentFood is loaded.
      // For now, we'll store them in a temporary set or handle it in _fetchFoodDetails
    }
  }

  void _onCartChanged() {
    if (mounted) {
      _syncWithCart();
    }
  }

  void _syncWithCart() {
    if (_currentFood == null) return;

    final allOptionIds = <int>[];
    for (final ids in _selectedOptions.values) {
      allOptionIds.addAll(ids);
    }

    // If we have a specific cartItemId we are editing, we should check its quantity
    // But we also want to know if the CURRENT selection matches ANY item in the cart
    // to show the correct quantity for that specific configuration.
    final cartItem = CartManager.instance.findItemInCarts(
      _currentFood!.id,
      variantId: _selectedVariantId,
      optionIds: allOptionIds.isNotEmpty ? allOptionIds : null,
    );

    if (cartItem != null) {
      setState(() {
        _quantity = cartItem.quantity;
      });
    } else {
      // If we are editing but changed to a configuration that doesn't exist,
      // we might want to reset quantity to 1 or keep current.
      // Keep current is usually safer.
    }
  }

  Future<void> _fetchFoodDetails() async {
    final foodId = int.tryParse(widget.id);
    if (foodId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final food = await RestaurantRepository.instance.getUserFoodById(foodId);
      if (mounted) {
        setState(() {
          _currentFood = food;
          _isLoading = false;

          if (food != null) {
            // Map initial options to their groups
            if (widget.initialOptionIds != null) {
              for (final group in food.optionGroups) {
                final selectedInGroup = group.options
                    .where((o) => widget.initialOptionIds!.contains(o.id))
                    .map((o) => o.id)
                    .toSet();
                if (selectedInGroup.isNotEmpty) {
                  _selectedOptions[group.id] = selectedInGroup;
                }
              }
            }

            _syncWithCart();
            _isFavorite = food.isFavorite;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<String> get _galleryImages {
    if (_currentFood != null && _currentFood!.photoUrls.isNotEmpty) {
      return _currentFood!.photoUrls;
    }

    // If we have an imagePath from the widget, use it
    if (widget.imagePath.isNotEmpty) {
      return [widget.imagePath];
    }

    // Fallback to an empty list, but the builder will handle the "No Image" case
    return [''];
  }

  void _onScroll() {
    // threshold calculation: expandedHeight (270) - toolbarHeight (56) - status bar (~40) = ~170
    if (_scrollController.hasClients && _scrollController.offset > 230) {
      if (!_isScrolled) {
        setState(() {
          _isScrolled = true;
        });
      }
    } else {
      if (_isScrolled) {
        setState(() {
          _isScrolled = false;
        });
      }
    }
  }

  @override
  void dispose() {
    CartManager.instance.removeListener(_onCartChanged);
    _instructionsController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeleton(context);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isScrolled
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 270.0,
                  pinned: false,
                  stretch: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        (() {
                          final img = _galleryImages.isNotEmpty
                              ? _galleryImages.first.trim()
                              : '';
                          if (img.isEmpty) {
                            return MenuImagePlaceholder(title: widget.title);
                          }
                          return Image.network(
                            img,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const ImageSkeletonLoader();
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                MenuImagePlaceholder(title: widget.title),
                          );
                        })(),
                        // Gradient Overlay for visibility when not scrolled
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(20),
                    child: Container(
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 0),
                        // Title
                        Text(
                          _currentFood?.name ?? widget.title,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        if ((_currentFood?.description ?? widget.description)
                            .trim()
                            .isNotEmpty) ...[
                          Text(
                            _currentFood?.description ?? widget.description,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Price
                        Row(
                          children: [
                            GradientText(
                              (() {
                                if (widget.displayPrice != null &&
                                    _selectedVariantId == null) {
                                  return widget.displayPrice!;
                                }
                                double price = 0;
                                if (_currentFood != null) {
                                  if (_selectedVariantId != null) {
                                    final variant = _currentFood!.variants
                                        .firstWhere(
                                          (v) => v.id == _selectedVariantId,
                                          orElse: () =>
                                              _currentFood!.variants.first,
                                        );
                                    price = variant.price;
                                  } else {
                                    double currentPrice = _currentFood!.price;
                                    double originalPrice =
                                        _currentFood!.originalPrice ?? 0.0;
                                    price =
                                        (currentPrice == 0 && originalPrice > 0)
                                        ? originalPrice
                                        : currentPrice;
                                  }
                                } else {
                                  price = widget.price;
                                }
                                return price
                                    .toStringAsFixed(0)
                                    .toFormattedPrice(
                                      currency:
                                          _currentFood?.currency ??
                                          widget.currency,
                                    );
                              })(),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Rating
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _currentFood?.shopName ?? widget.restaurantName,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (widget.rating > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.circle,
                                size: 4,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.rating}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${widget.reviewCount} Reviews)',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Tags
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (_currentFood?.cuisineType != null) ...[
                                _buildTag(
                                  _currentFood!.cuisineType!.displayName,
                                ),
                              ] else ...[
                                _buildTag(context.tr('menu.default_cuisine_tag')),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Variants
                        if (_currentFood != null &&
                            _currentFood!.variants.isNotEmpty) ...[
                          Text(
                            context.tr('menu.variants'),
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._currentFood!.variants.map((variant) {
                            return _buildSelectionItem(
                              title: variant.name,
                              price: variant.price
                                  .toStringAsFixed(0)
                                  .toFormattedPrice(
                                    currency: _currentFood!.currency,
                                  ),
                              isSelected: _selectedVariantId == variant.id,
                              isRadio: true,
                              onChanged: (isSelected) {
                                setState(() {
                                  if (_selectedVariantId == variant.id) {
                                    _selectedVariantId =
                                        null; // Unselect if already selected
                                  } else {
                                    _selectedVariantId = variant.id;
                                  }
                                  _syncWithCart();
                                });
                              },
                            );
                          }),
                          const SizedBox(height: 32),
                        ],

                        // Option Groups
                        if (_currentFood != null &&
                            _currentFood!.optionGroups.isNotEmpty) ...[
                          Text(
                            context.tr('menu.add_on'),
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._currentFood!.optionGroups.map((group) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (group.isRequired) ...[
                                  Text(
                                    group.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                ...group.options.map((option) {
                                  final isSelected =
                                      _selectedOptions[group.id]?.contains(
                                        option.id,
                                      ) ??
                                      false;
                                  final isRadio =
                                      group.groupType == 'SINGLE_SELECT' ||
                                      group.groupType == 'RADIO';
                                  return _buildSelectionItem(
                                    title: option.name,
                                    price:
                                        '+ ${option.price.toStringAsFixed(0)} ${_currentFood?.currency ?? widget.currency}',
                                    isSelected: isSelected,
                                    isRadio: isRadio,
                                    onChanged: (value) {
                                      setState(() {
                                        if (isRadio) {
                                          if (_selectedOptions[group.id]
                                                  ?.contains(option.id) ??
                                              false) {
                                            _selectedOptions[group.id] =
                                                {}; // Unselect if already selected
                                          } else {
                                            _selectedOptions[group.id] = {
                                              option.id,
                                            };
                                          }
                                        } else {
                                          final current =
                                              _selectedOptions[group.id] ?? {};
                                          if (value == true) {
                                            current.add(option.id);
                                          } else {
                                            current.remove(option.id);
                                          }
                                          _selectedOptions[group.id] = current;
                                        }
                                        _syncWithCart();
                                      });
                                    },
                                  );
                                }),
                                const SizedBox(height: 20),
                              ],
                            );
                          }),
                        ],
                        const SizedBox(height: 20),

                        // Special Instructions
                        Text(
                          context.tr('menu.special_instructions'),
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFEAEFF5,
                            ), // New background color
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: TextField(
                            controller: _instructionsController,
                            maxLines: null,
                            maxLength: 200,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            buildCounter:
                                (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => null,
                            decoration: InputDecoration(
                              hintText:
                                  context.tr('menu.special_instructions_hint'),
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                            ),
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '${_instructionsController.text.length}/200',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Recommended Section
                        if (_recommendedItems.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('menu.recommended_with'),
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              ViewAllIconButton(
                                onPressed: () {
                                  // Action for view all recommended
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 230,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _recommendedItems.length,
                              padding: EdgeInsets.zero,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final item = _recommendedItems[index];
                                return _buildRecommendedItem(
                                  item['title']!,
                                  double.tryParse(item['price'] ?? '0') ?? 0.0,
                                  item['imageUrl']!,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Review Section
                        if (_reviews.isNotEmpty) ...[
                          _buildReviewSection(),
                          const SizedBox(height: 80),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Custom Toolbar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                height: kToolbarHeight + MediaQuery.of(context).padding.top,
                decoration: BoxDecoration(
                  color: _isScrolled ? Colors.white : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: _isScrolled
                          ? Colors.black.withValues(alpha: 0.05)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    _buildCircleIconButton(
                      icon: PhosphorIcons.arrowLeft,
                      onPressed: () => Navigator.pop(context),
                      isScrolled: _isScrolled,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _isScrolled ? 1.0 : 0.0,
                        child: Text(
                          _currentFood?.name ?? widget.title,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    _buildCircleIconButton(
                      icon: PhosphorIcons.shareNetwork,
                      onPressed: () {},
                      isScrolled: _isScrolled,
                    ),
                    const SizedBox(width: 12),
                    _buildCircleIconButton(
                      icon: _isFavorite
                          ? PhosphorIcons.heartFill
                          : PhosphorIcons.heart,
                      onPressed: () async {
                        if (_isTogglingFavorite) return;
                        _isTogglingFavorite = true;

                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await RestaurantRepository.instance
                              .toggleMenuFavorite(
                                int.tryParse(widget.id) ?? 0,
                                _isFavorite,
                              );
                        } catch (e) {
                          // Rollback on error
                          if (!context.mounted) return;
                          setState(() => _isFavorite = !_isFavorite);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                context.tr('common.favorite_failed'),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          _isTogglingFavorite = false;
                        }
                      },
                      isScrolled: _isScrolled,
                      iconColorOverride: _isFavorite ? AppColors.primary : null,
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Quantity Selector
                Container(
                  height: 56, // Fixed height
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      _buildQtyButton(
                        icon: Icons.remove,
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() => _quantity--);
                          }
                        },
                      ),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 40,
                        ), // Increased spacing
                        alignment: Alignment.center,
                        child: Text(
                          '$_quantity',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      _buildQtyButton(
                        icon: Icons.add,
                        onPressed: () {
                          setState(() => _quantity++);
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Add to Cart / Save Changes Button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _isAddingToCart
                            ? null
                            : () async {
                                if (_currentFood != null) {
                                  /* 
                        // Removing mandatory variant check
                        if (_currentFood!.variants.isNotEmpty && _selectedVariantId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(context.tr('menu.select_variant')),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        */

                                  // Check if all required groups are selected
                                  for (var group
                                      in _currentFood!.optionGroups) {
                                    if (group.isRequired &&
                                        (_selectedOptions[group.id]?.isEmpty ??
                                            true)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.trArgs('menu.select_option_for', {
                                              'name': group.name,
                                            }),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                  }
                                }

                                if (_currentFood == null && widget.price == 0) {
                                  return; // Basic validation
                                }

                                bool operationCompleted = false;

                                // Optimistically fill the heart icon as requested by user
                                final bool wasFavoriteBefore = _isFavorite;
                                setState(() {
                                  _isFavorite = true;
                                });

                                // Only show loading if it takes longer than 500ms
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () {
                                    if (!operationCompleted && mounted) {
                                      setState(() => _isAddingToCart = true);
                                    }
                                  },
                                );

                                final menuItemId = int.tryParse(widget.id);
                                final shopIdStr =
                                    (_currentFood?.shopId != null &&
                                        _currentFood!.shopId! > 0)
                                    ? _currentFood!.shopId!.toString()
                                    : (widget.restaurantId.trim().isNotEmpty
                                          ? widget.restaurantId
                                          : '0');
                                final shopId = int.tryParse(shopIdStr);

                                if (menuItemId != null &&
                                    shopId != null &&
                                    shopId > 0) {
                                  final allOptionIds = <int>[];
                                  for (final ids in _selectedOptions.values) {
                                    allOptionIds.addAll(ids);
                                  }

                                  try {
                                    CartDto? result;
                                    if (widget.cartItemId != null) {
                                      // Find the names for the newly selected variant
                                      String? vName;
                                      String? vNameMm;
                                      if (_selectedVariantId != null &&
                                          _currentFood != null) {
                                        try {
                                          final variant = _currentFood!.variants
                                              .firstWhere(
                                                (v) =>
                                                    v.id == _selectedVariantId,
                                              );
                                          vName = variant.name;
                                          vNameMm = variant.nameMm;
                                        } catch (_) {}
                                      }

                                      // Update existing item
                                      result = await CartManager.instance
                                          .updateItemQuantity(
                                            widget.restaurantName,
                                            widget.cartItemId!,
                                            _quantity,
                                            variantId: _selectedVariantId,
                                            variantName: vName,
                                            variantNameMm: vNameMm,
                                            optionIds: allOptionIds.isNotEmpty
                                                ? allOptionIds
                                                : null,
                                            specialInstructions:
                                                _instructionsController.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : _instructionsController.text
                                                      .trim(),
                                          );
                                    } else {
                                      // Add new item
                                      result = await CartRepository.instance
                                          .addToCart(
                                            AddToCartRequest(
                                              menuItemId: menuItemId,
                                              quantity: _quantity,
                                              shopId: shopId,
                                              variantId: _selectedVariantId,
                                              specialInstructions:
                                                  _instructionsController.text
                                                      .trim()
                                                      .isEmpty
                                                  ? null
                                                  : _instructionsController.text
                                                        .trim(),
                                              optionIds: allOptionIds.isNotEmpty
                                                  ? allOptionIds
                                                  : null,
                                            ),
                                          );
                                    }

                                    if (result != null) {
                                      // Sync local state instantly without another network request
                                      CartManager.instance.updateCartFromDto(
                                        result,
                                      );

                                      // Also trigger a background sync just to be safe, but don't await it
                                      CartManager.instance
                                          .invalidateCache()
                                          .then((_) {
                                            CartManager.instance.syncWithApi();
                                          });

                                      if (mounted) {
                                        operationCompleted = true;
                                        setState(() => _isAddingToCart = false);
                                        if (!context.mounted) return;
                                        Navigator.pop(
                                          context,
                                        ); // Pop immediately for snappy feel
                                      }
                                      return;
                                    }

                                    // Fallback if result is null (shouldn't happen on success)
                                    await CartManager.instance
                                        .invalidateCache();
                                    await CartManager.instance.syncWithApi();
                                    if (mounted) {
                                      operationCompleted = true;
                                      setState(() {
                                        _isAddingToCart = false;
                                      });
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() {
                                        _isAddingToCart = false;
                                        // Rollback heart if it was only filled due to this operation
                                        _isFavorite = wasFavoriteBefore;
                                      });
                                      final errorStr = e.toString();

                                      // Handle Single Shop Rule Conflict (409)
                                      if (errorStr.contains('Conflict') ||
                                          errorStr.contains('409')) {
                                        if (!context.mounted) return;
                                        final bool? clearConfirmed =
                                            await AppDialog.show<bool>(
                                              context: context,
                                              title: context.tr('menu.new_cart_title'),
                                              content:
                                                  context.tr('menu.new_cart_message'),
                                              buttonText: context.tr('menu.clear_and_add'),
                                              secondaryButtonText: context.tr('common.cancel'),
                                            );

                                        if (clearConfirmed == true && mounted) {
                                          try {
                                            // Re-fill heart optimistically for retry
                                            setState(() {
                                              _isFavorite = true;
                                            });

                                            await CartRepository.instance
                                                .clearCart();
                                            // Retry adding to cart
                                            await CartRepository.instance
                                                .addToCart(
                                                  AddToCartRequest(
                                                    menuItemId: menuItemId,
                                                    quantity: _quantity,
                                                    shopId: shopId,
                                                    variantId:
                                                        _selectedVariantId,
                                                    specialInstructions:
                                                        _instructionsController
                                                            .text
                                                            .trim()
                                                            .isEmpty
                                                        ? null
                                                        : _instructionsController
                                                              .text
                                                              .trim(),
                                                    optionIds:
                                                        allOptionIds.isNotEmpty
                                                        ? allOptionIds
                                                        : null,
                                                  ),
                                                );
                                            // Sync local state
                                            await CartManager.instance
                                                .invalidateCache();
                                            await CartManager.instance
                                                .syncWithApi();
                                            if (mounted) {
                                              setState(
                                                () => _isAddingToCart = false,
                                              );
                                              if (!context.mounted) return;
                                              Navigator.pop(
                                                context,
                                              ); // Pop details page
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    context.tr('menu.cart_cleared_added'),
                                                  ),
                                                  backgroundColor:
                                                      AppColors.primary,
                                                ),
                                              );
                                            }
                                          } catch (retryErr) {
                                            if (mounted) {
                                              setState(() {
                                                _isAddingToCart = false;
                                                // Rollback heart again on retry failure
                                                _isFavorite = wasFavoriteBefore;
                                              });
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    context.trArgs(
                                                      'menu.failed_retry',
                                                      {'error': '$retryErr'},
                                                    ),
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        } else if (mounted) {
                                          setState(
                                            () => _isAddingToCart = false,
                                          );
                                        }
                                        return;
                                      }

                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.trArgs('menu.failed_add_cart', {'error': '$e'}),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  if (mounted) {
                                    setState(() => _isAddingToCart = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.tr('menu.invalid_item_shop'),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        borderRadius: BorderRadius.circular(20),
                        splashColor: Colors.white.withValues(alpha: 0.2),
                        highlightColor: Colors.transparent,
                        child: Container(
                          height: 56, // Fixed height to match qty selector
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          child: _isAddingToCart
                              ? const Center(
                                  child: CustomLoadingIndicator(
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.shopping_cart_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      (() {
                                        double basePrice = 0;
                                        double optionsPrice = 0;
                                        if (_currentFood != null) {
                                          if (_selectedVariantId != null) {
                                            final variant = _currentFood!
                                                .variants
                                                .firstWhere(
                                                  (v) =>
                                                      v.id ==
                                                      _selectedVariantId,
                                                );
                                            basePrice = variant.price;
                                          } else {
                                            double currentPrice =
                                                _currentFood!.price;
                                            double originalPrice =
                                                _currentFood!.originalPrice ??
                                                0.0;
                                            basePrice =
                                                (currentPrice == 0 &&
                                                    originalPrice > 0)
                                                ? originalPrice
                                                : currentPrice;
                                          }
                                          for (var group
                                              in _currentFood!.optionGroups) {
                                            final selectedIds =
                                                _selectedOptions[group.id] ??
                                                {};
                                            for (var id in selectedIds) {
                                              final option = group.options
                                                  .firstWhere(
                                                    (o) => o.id == id,
                                                  );
                                              optionsPrice += option.price;
                                            }
                                          }
                                        } else {
                                          basePrice = widget.price;
                                        }
                                        return ((basePrice + optionsPrice) *
                                                _quantity)
                                            .toStringAsFixed(0)
                                            .toFormattedPrice(
                                              currency:
                                                  _currentFood?.currency ??
                                                  widget.currency,
                                            );
                                      })(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isScrolled,
    Color? iconColorOverride,
  }) {
    // When scrolled (white app bar), icon is black, bg is transparent or light grey?
    // User request: "fade to white ... back button color change to opposite" (White on Image -> Black on White Bar)

    final Color iconColor =
        iconColorOverride ?? (isScrolled ? Colors.black : Colors.white);
    final Color backgroundColor = isScrolled
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.3);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon, color: iconColor, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1), // Light pink/branded
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSelectionItem({
    required String title,
    required String price,
    required bool isSelected,
    required bool isRadio,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Custom Radio/Checkbox
            Container(
              height: 20,
              width: 20,
              decoration: BoxDecoration(
                color: isSelected && !isRadio
                    ? AppColors.primary
                    : Colors.transparent,
                shape: isRadio ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isRadio ? null : BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFF94A3B8),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: isRadio
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                            )
                          : const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                    )
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GradientText(
              price,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedItem(String title, double price, String imageUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MenuDetailPage(
              id: '0', // Fallback for recommended items as they are mock
              restaurantId: widget.restaurantId,
              title: title,
              price: price,
              imagePath: imageUrl,
              description:
                  context.tr('menu.default_description'),
            ),
          ),
        );
      },
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    imageUrl,
                    height: 150,
                    width: 150,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const ImageSkeletonLoader(width: 150, height: 150);
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        MenuImagePlaceholder(title: title),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            GradientText(
              price.toStringAsFixed(0),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Icon(icon, size: 16, color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                context.trArgs('menu.customer_reviews', {'count': '11.4K'}),
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ViewAllIconButton(
              onPressed: () {
                // Action for view all reviews
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _reviews.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final review = _reviews[index];
            return ReviewCard(
              userName: review['userName'],
              userAvatar: review['userAvatar'],
              rating: review['rating'] as int,
              comment: review['comment'],
              tags: (review['tags'] as List).map((t) => t.toString()).toList(),
              date: review['date'],
              image: review['image'],
            );
          },
        ),
      ],
    );
  }


  // --- Skeleton Loading View ---
  Widget _buildSkeleton(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 270.0,
                pinned: false,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: const ImageSkeletonLoader(),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(20),
                  child: Container(
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title skeleton
                      _shimmerBox(width: 200, height: 24, radius: 8),
                      const SizedBox(height: 12),
                      // Description skeleton
                      _shimmerBox(
                        width: double.infinity,
                        height: 14,
                        radius: 4,
                      ),
                      const SizedBox(height: 8),
                      _shimmerBox(
                        width: double.infinity,
                        height: 14,
                        radius: 4,
                      ),
                      const SizedBox(height: 8),
                      _shimmerBox(width: 150, height: 14, radius: 4),
                      const SizedBox(height: 16),
                      // Price skeleton
                      _shimmerBox(width: 80, height: 20, radius: 6),
                      const SizedBox(height: 12),
                      // Rating skeleton
                      Row(
                        children: [
                          _shimmerBox(width: 60, height: 14, radius: 4),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.circle,
                            size: 4,
                            color: Color(0xFFF1F5F9),
                          ),
                          const SizedBox(width: 8),
                          _shimmerBox(width: 30, height: 14, radius: 4),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF1F5F9),
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          _shimmerBox(width: 100, height: 14, radius: 4),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Tags skeleton
                      Row(
                        children: [
                          _shimmerBox(width: 100, height: 32, radius: 20),
                          const SizedBox(width: 12),
                          _shimmerBox(width: 80, height: 32, radius: 20),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Add-ons header skeleton
                      _shimmerBox(width: 100, height: 18, radius: 6),
                      const SizedBox(height: 16),
                      // Add-on item skeletons
                      for (int i = 0; i < 3; i++) ...[
                        Row(
                          children: [
                            _shimmerBox(width: 20, height: 20, radius: 6),
                            const SizedBox(width: 13),
                            _shimmerBox(width: 120, height: 14, radius: 4),
                            const Spacer(),
                            _shimmerBox(width: 60, height: 14, radius: 4),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          // App bar buttons skeleton
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            height: kToolbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _shimmerBox(width: 38, height: 38, radius: 19),
                  const Spacer(),
                  _shimmerBox(width: 38, height: 38, radius: 19),
                  const SizedBox(width: 12),
                  _shimmerBox(width: 38, height: 38, radius: 19),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              _shimmerBox(width: 120, height: 56, radius: 20),
              const SizedBox(width: 16),
              Expanded(
                child: _shimmerBox(
                  width: double.infinity,
                  height: 56,
                  radius: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double radius = 8,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ImageSkeletonLoader(width: width, height: height),
    );
  }
}
