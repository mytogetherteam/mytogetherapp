import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/job_post_dto.dart';
import '../../data/repositories/job_post_repository.dart';

class JobDetailPage extends StatefulWidget {
  final int jobId;

  const JobDetailPage({super.key, required this.jobId});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  JobPostDto? _job;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final job = await JobPostRepository.instance.fetchJob(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _isLoading = false;
        if (job == null) _error = context.tr('jobs.not_found');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = context.tr('jobs.load_error');
      });
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final hasPhone = job?.contactPhone?.trim().isNotEmpty == true;
    final hasLink = job?.applyLink?.trim().isNotEmpty == true;
    final showActions = hasPhone || hasLink;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 8.0, bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                PhosphorIconsRegular.arrowLeft,
                color: Colors.black,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                )
              : job == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      height: 180,
                                      width: double.infinity,
                                      color: Colors.grey.shade100,
                                      child: job.shop?.coverImage.isNotEmpty == true
                                          ? CachedNetworkImage(
                                              imageUrl: job.shop!.coverImage,
                                              fit: BoxFit.cover,
                                              errorWidget: (context, url, error) => Image.asset(
                                                'assets/images/work.png',
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Image.asset(
                                              'assets/images/work.png',
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    if (job.shop != null)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: -36,
                                        child: Center(
                                          child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.white, width: 4),
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: job.shop!.logo.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: job.shop!.logo,
                                                    width: 64,
                                                    height: 64,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, _, _) => _shopFallback(size: 64),
                                                  )
                                                : _shopFallback(size: 64),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                                  child: _buildContent(context, job),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showActions) _buildActionBar(context, job),
                      ],
                    ),
    );
  }

  Widget _buildContent(BuildContext context, JobPostDto job) {
    final shop = job.shop;
    final dateFmt = DateFormat('d MMM yyyy');
    final negotiableLabel = context.tr('jobs.salary_negotiable');
    final jobTypeLabel = job.jobType == JobType.fullTime
        ? context.tr('jobs.full_time')
        : context.tr('jobs.part_time');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shop != null) ...[
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
              child: Text(
                shop.displayName,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          job.title,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(
              jobTypeLabel,
              textColor: AppColors.primary,
              bgColor: AppColors.primary.withValues(alpha: 0.12),
            ),
            _chip(
              job.salaryLabel(negotiableLabel),
              textColor: Colors.white,
              gradient: AppColors.primaryGradient,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          job.description,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.black54,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        if (job.createdAt != null)
          _metaRow(
            PhosphorIconsRegular.clock,
            '${context.tr('jobs.posted')}: ${dateFmt.format(job.createdAt!.toLocal())}',
          ),
        if (job.closingDate != null) ...[
          const SizedBox(height: 8),
          _metaRow(
            PhosphorIconsRegular.calendarBlank,
            '${context.tr('jobs.deadline')}: ${dateFmt.format(job.closingDate!.toLocal())}',
          ),
        ],
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, JobPostDto job) {
    final hasPhone = job.contactPhone?.trim().isNotEmpty == true;
    final hasLink = job.applyLink?.trim().isNotEmpty == true;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (hasPhone)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _launchPhone(job.contactPhone!.trim()),
                icon: const Icon(PhosphorIconsRegular.phone, size: 18),
                label: Text(context.tr('jobs.apply_phone')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (hasPhone && hasLink) const SizedBox(width: 12),
          if (hasLink)
            Expanded(
              child: PrimaryGradientButton(
                onPressed: () => _launchLink(job.applyLink!.trim()),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsRegular.link, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('jobs.apply_link'),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shopFallback({double size = 48}) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade200,
      child: Icon(PhosphorIconsRegular.storefront, size: size * 0.45, color: Colors.grey),
    );
  }

  Widget _chip(String label, {Color? textColor, Color? bgColor, LinearGradient? gradient}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor ?? Colors.white,
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}
