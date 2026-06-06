import 'dart:async';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../presentation/widgets/image_skeleton_loader.dart';
import '../../../../core/presentation/widgets/full_screen_image_viewer.dart';
import '../../data/models/place_dto.dart';
import 'package:mytogetherapp/features/wishlist/data/repositories/wishlist_repository.dart';

class PlaceDetailPage extends StatefulWidget {
  final PlaceDto place;

  const PlaceDetailPage({
    super.key,
    required this.place,
  });

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _zoomController;
  late AnimationController _entranceController;
  late Animation<double> _zoomAnimation;
  late Animation<double> _entranceOpacity;
  late Animation<Offset> _entranceSlide;
  bool _isScrolled = false;
  late bool _isFavorite;

  // Slideshow state
  late List<String> _allImages;
  int _currentImageIndex = 0;
  Timer? _slideshowTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _isFavorite = widget.place.isFavorite;

    final cover = widget.place.coverImage.isNotEmpty
        ? widget.place.coverImage
        : '';
    _allImages = [
      if (cover.isNotEmpty) cover,
      ...widget.place.galleryUrls,
    ];
    if (_allImages.isEmpty) {
      _allImages = [''];
    }

    // Ken Burns Animation Setup
    _zoomController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _zoomAnimation = Tween<double>(
      begin: 1.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _zoomController, curve: Curves.linear));
    _zoomController.repeat(reverse: true);

    // Entrance Animation Setup
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
          ),
        );
    _entranceController.forward();

    // Slideshow Timer
    _startSlideshow();
  }

  void _startSlideshow() {
    if (_allImages.length > 1) {
      _slideshowTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted) {
          setState(() {
            _currentImageIndex = (_currentImageIndex + 1) % _allImages.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _zoomController.dispose();
    _entranceController.dispose();
    _slideshowTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final next = !_isFavorite;
    setState(() => _isFavorite = next);
    try {
      await WishlistRepository.instance.togglePlace(widget.place.id, next);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = !next);
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final double offset = _scrollController.offset;
      if (offset > 200) {
        if (!_isScrolled) setState(() => _isScrolled = true);
      } else {
        if (_isScrolled) setState(() => _isScrolled = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double expandedHeight = 430.0;
    final double appBarHeight =
        kToolbarHeight + MediaQuery.of(context).padding.top;

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
                // Animated Image Header
                SliverAppBar(
                  expandedHeight: expandedHeight,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        ScaleTransition(
                          scale: _zoomAnimation,
                          child: Hero(
                            tag: 'top_places_${widget.place.displayTitle}',
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 1000),
                              layoutBuilder:
                                  (
                                    Widget? currentChild,
                                    List<Widget> previousChildren,
                                  ) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ...previousChildren,
                                        ?currentChild,
                                      ],
                                    );
                                  },
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                              child: CachedNetworkImage(
                                key: ValueKey(_allImages[_currentImageIndex]),
                                imageUrl: _allImages[_currentImageIndex],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.error,
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        // Top Shadow for readability
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 120,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.4),
                                    Colors.black.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content Section
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _entranceOpacity,
                    child: SlideTransition(
                      position: _entranceSlide,
                      child: Transform.translate(
                        offset: const Offset(0, -60),
                        child: Stack(
                          children: [
                            // Main Content Container
                            Container(
                              margin: const EdgeInsets.only(top: 60),
                              padding: const EdgeInsets.only(
                                top: 20,
                                bottom: 40,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // About Location
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0,
                                    ),
                                    child: Text(
                                      context.tr('place.about_location'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0,
                                    ),
                                    child: Text(
                                      widget.place.displayDescription,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        color: Colors.grey[600],
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  // Photo Gallery
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0,
                                    ),
                                    child: Text(
                                      context.tr('place.photo_gallery'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 200,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.only(
                                        left: 20.0,
                                      ),
                                      scrollDirection: Axis.horizontal,
                                      itemCount: widget.place.galleryUrls.length,
                                      itemBuilder: (context, index) {
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                opaque: false,
                                                barrierDismissible: true,
                                                pageBuilder: (context, _, _) =>
                                                    FullScreenImageViewer(
                                                      imageUrls: widget.place.galleryUrls,
                                                      initialIndex: index,
                                                      heroTagPrefix:
                                                          'gallery_${widget.place.displayTitle}_',
                                                    ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 150,
                                            margin: const EdgeInsets.only(
                                              right: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: Hero(
                                                tag:
                                                    'gallery_${widget.place.displayTitle}_${widget.place.galleryUrls[index]}',
                                                child: CachedNetworkImage(
                                                  imageUrl:
                                                      widget.place.galleryUrls[index],
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      const ImageSkeletonLoader(
                                                        height: 200,
                                                        width: 150,
                                                      ),
                                                  errorWidget:
                                                      (
                                                        context,
                                                        url,
                                                        error,
                                                      ) => Container(
                                                        color: Colors.grey[200],
                                                        child: const Icon(
                                                          Icons.error,
                                                        ),
                                                      ),
                                                ),
                                              ),
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
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Floating Title and View on Map Section
            AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                double scrollOffset = 0.0;
                if (_scrollController.hasClients) {
                  scrollOffset = _scrollController.offset;
                }

                // Calculate position: start at bottom of image, move up with scroll
                const double initialTop = expandedHeight - 50;
                double currentTop = initialTop - scrollOffset;

                // Fade out as it reaches the top
                double opacity = 1.0;
                if (scrollOffset > 150) {
                  opacity = (1.0 - (scrollOffset - 150) / 100).clamp(0.0, 1.0);
                }

                return Stack(
                  children: [
                    // Bottom Fade synchronized with scroll
                    Positioned(
                      top: expandedHeight - 90 - scrollOffset,
                      left: 0,
                      right: 0,
                      height: 140, // More height to ensure deep connection
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.6),
                                Colors.white.withValues(alpha: 0.9),
                                Colors.white.withValues(alpha: 0.95),
                                Colors.white,
                                Colors.white,
                              ],
                              stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Floating Title Section
                    Positioned(
                      top: currentTop,
                      left: 20,
                      right: 20,
                      child: Opacity(
                        opacity: opacity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AutoSizeText(
                                    widget.place.displayTitle,
                                    maxLines: 2,
                                    minFontSize: 16,
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1D1D1F),
                                      height: 1.1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        PhosphorIcons.mapPinFill,
                                        color: AppColors.primary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.place.locationName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(
                                            0xFF1D1D1F,
                                          ).withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (widget.place.formattedHours.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(
                                          PhosphorIcons.clock,
                                          color: Colors.green[600],
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.place.formattedHours,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.green[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(19),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  context.tr('place.view_on_map'),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Custom Floating App Bar (Back/Heart)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                height: appBarHeight,
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
                        child: AutoSizeText(
                          widget.place.displayTitle,
                          maxLines: 1,
                          minFontSize: 14,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildCircleIconButton(
                      icon: _isFavorite
                          ? PhosphorIcons.heartFill
                          : PhosphorIcons.heart,
                      onPressed: _toggleFavorite,
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
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isScrolled,
    Color? iconColorOverride,
  }) {
    final Color iconColor =
        iconColorOverride ?? (isScrolled ? Colors.black : Colors.white);
    final Color backgroundColor = isScrolled
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.3);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon, color: iconColor, size: 24),
        onPressed: onPressed,
      ),
    );
  }
}
