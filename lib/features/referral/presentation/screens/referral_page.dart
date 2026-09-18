import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/referral_model.dart';
import '../../data/referral_service.dart';
import '../widgets/enter_friend_code_card.dart';
import '../widgets/promote_code_card.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReferralPage()),
    );
  }

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  bool _isLoading = true;
  UserReferralStatus? _status;
  List<ReferredFriend> _friends = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await ReferralService.instance.getStatus();
      List<ReferredFriend> friends = [];
      if (status.myCode != null && status.myCode!.usedCount > 0) {
        friends = await ReferralService.instance.getMyReferrals();
      }

      if (!mounted) return;
      setState(() {
        _status = status;
        _friends = friends;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Referral & Promote Code',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIcons.warningCircle,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Try Again',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card 1: Your Personal Promote Code
                        PromoteCodeCard(
                          myCode: _status?.myCode,
                          onCodeUpdated: _loadData,
                        ),
                        const SizedBox(height: 20),

                        // Card 2: Friend's Referral Code Input / Claimed Info
                        EnterFriendCodeCard(
                          claimedReferral: _status?.claimedReferral,
                          canClaim: _status?.canClaim ?? false,
                          isProgramActive: _status?.isProgramActive ?? false,
                          onClaimSuccess: _loadData,
                        ),
                        const SizedBox(height: 24),

                        // Section 3: Friends who joined
                        if (_friends.isNotEmpty) ...[
                          const Text(
                            'Friends Who Joined',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _friends.length,
                              separatorBuilder: (ctx, idx) =>
                                  Divider(height: 1, color: Colors.grey.shade100),
                              itemBuilder: (ctx, idx) {
                                final friend = _friends[idx];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.1),
                                    backgroundImage: friend.profileUrl != null
                                        ? NetworkImage(friend.profileUrl!)
                                        : null,
                                    child: friend.profileUrl == null
                                        ? Text(
                                            friend.name.isNotEmpty
                                                ? friend.name[0].toUpperCase()
                                                : 'F',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    friend.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: friend.joinedAt != null
                                      ? Text(
                                          'Joined ${friend.joinedAt!.day}/${friend.joinedAt!.month}/${friend.joinedAt!.year}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        )
                                      : null,
                                  trailing: const Icon(
                                    PhosphorIcons.checkCircleFill,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Section 4: How It Works
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(PhosphorIcons.info,
                                      size: 18, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text(
                                    'How Referral Works',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildStep(
                                number: '1',
                                title: 'Share Your Code',
                                description:
                                    'Share your custom promote code with friends via chat or social media.',
                              ),
                              const SizedBox(height: 12),
                              _buildStep(
                                number: '2',
                                title: 'Friend Joins & Applies',
                                description:
                                    'When your friend registers or enters your code in their profile, you both get connected.',
                              ),
                              const SizedBox(height: 12),
                              _buildStep(
                                number: '3',
                                title: 'Enjoy Rewards & Coupons',
                                description:
                                    'Earn exclusive restaurant and shop discount coupons directly in Saved Coupons!',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
