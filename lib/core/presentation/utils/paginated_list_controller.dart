import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'pagination_scroll.dart';

/// Result of a single paginated fetch. [hasMore] must be set from API meta when
/// the backend exposes pagination; omit only for non-paginated feeds.
class PaginatedPage<T> {
  final List<T> items;
  final bool? hasMore;

  const PaginatedPage({required this.items, this.hasMore});
}

/// Shared infinite-scroll state used across food feeds, lists, and wishlists.
///
/// Prefetches the next page when roughly 60% of the current [pageSize] has
/// been seen (e.g. item 6 of 10), and also when the scroll view is within
/// [pixelPrefetchThreshold] of the bottom. API responses should be cached at
/// the repository layer (see [RestaurantRepository.getFoodTabFeed]).
class PaginatedListController<T> extends ChangeNotifier {
  PaginatedListController({
    required this.fetchPage,
    this.pageSize = 20,
    this.initialPage = 0,
    this.pageIncrement = 1,
    this.prefetchWhenRemaining,
    this.pixelPrefetchThreshold = PaginationScroll.defaultEndThreshold,
    this.itemKey,
  });

  final Future<PaginatedPage<T>> Function(int page) fetchPage;
  final int pageSize;
  final int initialPage;
  final int pageIncrement;
  final double pixelPrefetchThreshold;

  /// When the number of items below the last visible index is at or below this
  /// value, the next page is prefetched. Defaults to 40% of [pageSize]
  /// (6 shown of 10 when page size is 10).
  final int? prefetchWhenRemaining;

  /// Optional stable id for deduplicating appended rows.
  final Object? Function(T item)? itemKey;

  final List<T> items = [];

  int _currentPage = 0;
  int _loadEpoch = 0;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _armedForNextPage = true;
  bool _disposed = false;

  ScrollController? _scrollController;
  VoidCallback? _scrollListener;

  int get currentPage => _currentPage;
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get showFooter => _isLoadingMore || !_hasMore;

  int get _remainingPrefetchThreshold =>
      prefetchWhenRemaining ??
      (pageSize * 0.4).ceil().clamp(2, pageSize - 1);

  void attachScrollController(ScrollController controller) {
    if (_scrollController == controller) return;
    detachScrollController();
    _scrollController = controller;
    _scrollListener = () => _onScroll(controller);
    controller.addListener(_scrollListener!);
  }

  void detachScrollController() {
    if (_scrollController != null && _scrollListener != null) {
      _scrollController!.removeListener(_scrollListener!);
    }
    _scrollController = null;
    _scrollListener = null;
  }

  /// Call from [ListView.builder] / grid delegates when a row becomes visible.
  void onItemVisible(int index) {
    if (!shouldPrefetchForIndex(index)) return;
    unawaited(loadMore());
  }

  bool shouldPrefetchForIndex(int visibleIndex) {
    if (!_hasMore || _isLoadingMore || _isInitialLoading || items.isEmpty) {
      return false;
    }
    if (visibleIndex < 0 || visibleIndex >= items.length) return false;
    final remainingBelow = items.length - 1 - visibleIndex;
    return remainingBelow <= _remainingPrefetchThreshold;
  }

  void _onScroll(ScrollController controller) {
    if (!_hasMore || _isLoadingMore || _isInitialLoading) return;

    final nearEnd = PaginationScroll.wasNearEnd(
      controller,
      threshold: pixelPrefetchThreshold,
    );

    if (!nearEnd) {
      _armedForNextPage = true;
      return;
    }

    if (!_armedForNextPage) return;
    _armedForNextPage = false;
    unawaited(loadMore());
  }

  Future<void> loadInitial({bool notify = true}) async {
    final epoch = ++_loadEpoch;

    _isInitialLoading = true;
    _hasMore = true;
    _currentPage = initialPage;
    _armedForNextPage = true;
    items.clear();
    if (notify) notifyListeners();

    try {
      final page = await fetchPage(_currentPage);
      if (_disposed || epoch != _loadEpoch) return;
      items.addAll(page.items);
      _hasMore = page.hasMore ?? false;
      _isInitialLoading = false;
      notifyListeners();
    } catch (_) {
      if (_disposed || epoch != _loadEpoch) return;
      _isInitialLoading = false;
      _hasMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadInitial();

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _isInitialLoading) return;

    final controller = _scrollController;
    final wasNearEnd = controller != null &&
        PaginationScroll.wasNearEnd(
          controller,
          threshold: pixelPrefetchThreshold,
        );

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + pageIncrement;
      final page = await fetchPage(nextPage);
      if (_disposed) return;

      final batch = page.items;
      _appendUnique(batch);
      _currentPage = nextPage;
      _hasMore = page.hasMore ?? false;
      _isLoadingMore = false;
      notifyListeners();

      // Re-anchor only when more pages remain; skipping on the last page
      // avoids the footer swapping (spinner → end) from nudging scroll up.
      if (wasNearEnd && batch.isNotEmpty && _hasMore) {
        PaginationScroll.maintainAfterPageAppend(
          controller,
          wasNearEnd: true,
        );
      }
    } catch (_) {
      if (_disposed) return;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _appendUnique(List<T> batch) {
    if (itemKey == null) {
      items.addAll(batch);
      return;
    }
    final existing = items.map(itemKey!).toSet();
    for (final item in batch) {
      final key = itemKey!(item);
      if (existing.add(key)) {
        items.add(item);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    detachScrollController();
    super.dispose();
  }
}
