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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('jobs.title'),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
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
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: _buildContent(context, job),
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
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: shop.logo.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: shop.logo,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _shopFallback(),
                      )
                    : _shopFallback(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shop.displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
            _infoChip(jobTypeLabel, AppColors.primary),
            _infoChip(job.salaryLabel(negotiableLabel), const Color(0xFF059669)),
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

  Widget _shopFallback() {
    return Container(
      width: 48,
      height: 48,
      color: Colors.grey.shade200,
      child: Icon(PhosphorIconsRegular.storefront, size: 22, color: Colors.grey),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
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
