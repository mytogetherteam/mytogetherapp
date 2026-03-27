import 'package:flutter/material.dart';

class SkeletonReviewCard extends StatelessWidget {
  const SkeletonReviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, color: Colors.grey[200]),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 12, color: Colors.grey[200]),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 250,
            color: Colors.grey[200],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: double.infinity, height: 12, color: Colors.grey[200]),
                const SizedBox(height: 8),
                Container(width: double.infinity, height: 12, color: Colors.grey[200]),
                const SizedBox(height: 8),
                Container(width: 200, height: 12, color: Colors.grey[200]),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(width: 80, height: 10, color: Colors.grey[200]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
