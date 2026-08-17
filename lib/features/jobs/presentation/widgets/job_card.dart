import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../data/models/job_post_dto.dart';

class JobCard extends StatelessWidget {
  final JobPostDto job;
  final VoidCallback? onTap;

  const JobCard({super.key, required this.job, this.onTap});

  @override
  Widget build(BuildContext context) {
    final shop = job.shop;
    final negotiableLabel = context.tr('jobs.salary_negotiable');
    final jobTypeLabel = job.jobType == JobType.fullTime
        ? context.tr('jobs.full_time')
        : context.tr('jobs.part_time');
    final dateFmt = DateFormat('d MMM yyyy');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shop != null) ...[
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: shop.logo.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: shop.logo,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => _shopFallback(),
                              )
                            : _shopFallback(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          shop.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip(
                                jobTypeLabel,
                                textColor: AppColors.primary,
                                bgColor: AppColors.primary.withValues(alpha: 0.1),
                              ),
                              _chip(
                                job.salaryLabel(negotiableLabel),
                                textColor: Colors.white,
                                gradient: AppColors.primaryGradient,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (job.closingDate != null) ...[
                  const SizedBox(height: 14),
                  Divider(color: Colors.grey.shade100, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.clock,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${context.tr('jobs.deadline')}: ${dateFmt.format(job.closingDate!.toLocal())}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shopFallback() {
    return Container(
      width: 36,
      height: 36,
      color: Colors.grey.shade200,
      child: Icon(PhosphorIconsRegular.storefront, size: 18, color: Colors.grey),
    );
  }

  Widget _chip(String label, {Color? textColor, Color? bgColor, LinearGradient? gradient}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor ?? Colors.white,
        ),
      ),
    );
  }
}
