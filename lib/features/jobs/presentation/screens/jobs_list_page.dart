import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:mytogetherapp/core/presentation/utils/paginated_list_controller.dart';
import 'package:mytogetherapp/core/presentation/widgets/pagination_list_footer.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../data/models/job_post_dto.dart';
import '../../data/repositories/job_post_repository.dart';
import '../widgets/job_card.dart';
import 'job_detail_page.dart';

class JobsListPage extends StatefulWidget {
  const JobsListPage({super.key});

  @override
  State<JobsListPage> createState() => _JobsListPageState();
}

class _JobsListPageState extends State<JobsListPage> {
  static const int _pageSize = 20;

  late final PaginatedListController<JobPostDto> _pagination;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  JobType? _selectedJobType;
  String _searchQuery = '';
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _pagination = PaginatedListController<JobPostDto>(
      pageSize: _pageSize,
      initialPage: 1,
      itemKey: (job) => job.id,
      fetchPage: _fetchPage,
    )..addListener(_onPaginationChanged);
    _pagination.attachScrollController(_scrollController);
    _scrollController.addListener(_onScroll);
    _pagination.loadInitial();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final scrolled = _scrollController.position.pixels > 165;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  Future<PaginatedPage<JobPostDto>> _fetchPage(int page) async {
    final feed = await JobPostRepository.instance.fetchJobs(
      page: page,
      size: _pageSize,
      search: _searchQuery.isEmpty ? null : _searchQuery,
      jobType: _selectedJobType,
    );
    return PaginatedPage(items: feed.items, hasMore: feed.hasMore);
  }

  Future<void> _refresh() => _pagination.refresh();

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (_searchQuery == value.trim()) return;
      setState(() => _searchQuery = value.trim());
      _pagination.refresh();
    });
  }

  void _onFilterChanged(JobType? jobType) {
    if (_selectedJobType == jobType) return;
    setState(() => _selectedJobType = jobType);
    _pagination.refresh();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _pagination
      ..removeListener(_onPaginationChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _l(String en, String mm, String th) =>
      LocaleController.instance.localized(en: en, mm: mm, th: th);

  @override
  Widget build(BuildContext context) {
    final jobs = _pagination.items;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (_isScrolled
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              edgeOffset: MediaQuery.of(context).padding.top + 40,
              color: AppColors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(context),
                  ),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: context.tr('jobs.filter_all'),
                            selected: _selectedJobType == null,
                            onTap: () => _onFilterChanged(null),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: context.tr('jobs.full_time'),
                            selected: _selectedJobType == JobType.fullTime,
                            onTap: () => _onFilterChanged(JobType.fullTime),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: context.tr('jobs.part_time'),
                            selected: _selectedJobType == JobType.partTime,
                            onTap: () => _onFilterChanged(JobType.partTime),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_pagination.isInitialLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (jobs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIconsRegular.briefcase,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('jobs.empty'),
                              style: AppFonts.poppins(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemCount:
                            jobs.length + (_pagination.showFooter ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index >= jobs.length) {
                            return PaginationListFooter(
                              isLoading: _pagination.isLoadingMore,
                              showEndMessage: !_pagination.hasMore,
                            );
                          }
                          _pagination.onItemVisible(index);
                          final job = jobs[index];
                          return JobCard(
                            job: job,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      JobDetailPage(jobId: job.id),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildFloatingTopBar(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingTopBar(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.only(top: top, left: 12, right: 16),
      height: top + 56,
      decoration: BoxDecoration(
        color: _isScrolled ? Colors.white : Colors.transparent,
        border: _isScrolled
            ? Border(
                bottom: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isScrolled
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsRegular.arrowLeft,
                color: _isScrolled ? Colors.black : Colors.white,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isScrolled ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _l(
                    'Jobs in Thailand',
                    'ထိုင်းနိုင်ငံ အလုပ်အကိုင်များ',
                    'งานในประเทศไทย',
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final headerHeight = (isIOS ? 255.0 : 240.0) + top;

    return SizedBox(
      width: double.infinity,
      height: headerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/work.png',
            width: double.infinity,
            height: headerHeight,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.30),
                  Colors.black.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 115,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.58, 1.0],
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    const Color(0xFFF9FAFB).withValues(alpha: 0.78),
                    const Color(0xFFF9FAFB),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 56, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                _buildSearch(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.magnifyingGlass,
            color: Colors.grey.shade500,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: AppFonts.poppins(
                color: const Color(0xFF1E293B),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: context.tr('jobs.search_hint'),
                hintStyle: AppFonts.poppins(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, child) {
              if (value.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
                child: const Icon(
                  PhosphorIconsFill.xCircle,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? null : Colors.white,
          gradient: selected ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(24),
          border: selected
              ? null
              : Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppFonts.poppins(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
