import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/features/cart/data/saved_card_service.dart';
import 'package:mytogetherapp/features/order/presentation/screens/order_history_page.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentMethodsPage()),
    );
  }

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final SavedCardService _cardService = SavedCardService.instance;

  @override
  void initState() {
    super.initState();
    _cardService.addListener(_onServiceUpdate);
    _cardService.loadCards();
  }

  @override
  void dispose() {
    _cardService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final defaultCard = _cardService.defaultCard;
    final cards = _cardService.cards;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.caretLeft, color: Colors.black87, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('profile.payment_methods'),
          style: AppFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsFill.shieldCheck, color: Color(0xFF10B981), size: 22),
            tooltip: 'Security Info',
            onPressed: () => _showSecurityInfoDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────────────────
            // 1. TOP VIP VIRTUAL CARD (GRABPAY STYLE)
            // ─────────────────────────────────────────────────────────
            _buildVipPaymentCard(defaultCard),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────
            // 2. DEFAULT PAYMENT CHANNEL SELECTOR
            // ─────────────────────────────────────────────────────────
            _buildDefaultChannelSelector(),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────
            // 3. CREDIT / DEBIT CARDS SECTION
            // ─────────────────────────────────────────────────────────
            _buildCardsSection(cards),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────
            // 4. MOBILE BANKING & E-WALLETS
            // ─────────────────────────────────────────────────────────
            _buildEWalletsSection(),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────
            // 5. CHECKOUT & SECURITY PREFERENCES (GRAB STYLE)
            // ─────────────────────────────────────────────────────────
            _buildPreferencesSection(),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────
            // 6. TRANSACTION HISTORY LINK
            // ─────────────────────────────────────────────────────────
            _buildHistoryShortcut(),
            const SizedBox(height: 28),

            // ─────────────────────────────────────────────────────────
            // 7. TRUST & COMPLIANCE FOOTER
            // ─────────────────────────────────────────────────────────
            _buildSecurityFooter(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. VIP VIRTUAL CARD ARTWORK
  // ─────────────────────────────────────────────────────────────
  Widget _buildVipPaymentCard(SavedCard? defaultCard) {
    final activeChannel = _cardService.defaultChannel;
    final isCardActive = activeChannel == 'CARD';

    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF0B1329),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Stack(
        children: [
          // Background ambient rings
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Brand & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          PhosphorIconsFill.shieldCheck,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'MyTogether Pay',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '1-TAP AUTO-CUT',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Middle: Chip graphic & Contactless
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 16,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    PhosphorIconsBold.broadcast,
                    color: Colors.white60,
                    size: 20,
                  ),
                ],
              ),

              // Bottom row: Active Payment details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCardActive
                            ? (defaultCard != null ? defaultCard.maskedDisplay : '•••• •••• •••• 4242')
                            : (activeChannel == 'PROMPTPAY'
                                ? 'PromptPay (Thai QR)'
                                : activeChannel == 'TRUEMONEY'
                                    ? 'TrueMoney (${_cardService.trueMoneyPhone ?? 'Linked'})'
                                    : 'Cash on Delivery'),
                        style: GoogleFonts.sourceCodePro(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCardActive
                            ? (defaultCard?.holderName ?? 'PRIMARY CARD')
                            : 'DEFAULT CHECKOUT METHOD',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  if (isCardActive && defaultCard != null)
                    _buildCardBrandMiniLogo(defaultCard.brand)
                  else
                    const Icon(PhosphorIconsFill.checkCircle, color: Color(0xFF10B981), size: 28),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. DEFAULT CHANNEL SELECTOR
  // ─────────────────────────────────────────────────────────────
  Widget _buildDefaultChannelSelector() {
    final active = _cardService.defaultChannel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Preferred Payment Method',
                style: AppFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                'Auto-Selected at Checkout',
                style: AppFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildChannelChip(
                keyName: 'CARD',
                label: 'Cards',
                icon: PhosphorIconsFill.creditCard,
                isSelected: active == 'CARD',
              ),
              const SizedBox(width: 8),
              _buildChannelChip(
                keyName: 'PROMPTPAY',
                label: 'PromptPay',
                icon: PhosphorIconsFill.qrCode,
                isSelected: active == 'PROMPTPAY',
              ),
              const SizedBox(width: 8),
              _buildChannelChip(
                keyName: 'TRUEMONEY',
                label: 'TrueMoney',
                icon: PhosphorIconsFill.wallet,
                isSelected: active == 'TRUEMONEY',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelChip({
    required String keyName,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => _cardService.setDefaultChannel(keyName),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. CREDIT / DEBIT CARDS SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardsSection(List<SavedCard> cards) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Cards (Credit / Debit)',
                    style: AppFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${cards.length} SAVED',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _openAddCardModal(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIconsBold.plus, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Add Card',
                        style: AppFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (cards.isEmpty)
            _buildEmptyCardsPlaceholder()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final card = cards[index];
                return _buildSavedCardItem(card);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCardsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(PhosphorIconsLight.creditCard, size: 36, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text(
            'No saved cards yet',
            style: AppFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Save your Visa, Mastercard or JCB for instant 1-tap checkout.',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCardItem(SavedCard card) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: card.isDefault ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: card.isDefault ? AppColors.primary.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          width: card.isDefault ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          _buildCardBrandTileIcon(card.brand),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      card.maskedDisplay,
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    if (card.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DEFAULT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${card.holderName} • Expires ${card.expiryDisplay}',
                  style: AppFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(PhosphorIconsRegular.dotsThreeVertical, size: 20, color: Color(0xFF64748B)),
            onSelected: (value) {
              if (value == 'default') {
                _cardService.setDefault(card.id);
                _cardService.setDefaultChannel('CARD');
                AppDialog.showToast(context, 'Set as default card ✓');
              } else if (value == 'delete') {
                _confirmDeleteCard(context, card);
              }
            },
            itemBuilder: (context) => [
              if (!card.isDefault)
                const PopupMenuItem(
                  value: 'default',
                  child: Row(
                    children: [
                      Icon(PhosphorIconsRegular.checkCircle, size: 18, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text('Set as Default'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(PhosphorIconsRegular.trash, size: 18, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Remove Card', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCard(BuildContext context, SavedCard card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Card',
          style: AppFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to remove card ending in ${card.last4}?',
          style: AppFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cardService.removeCard(card.id);
              AppDialog.showToast(context, 'Card removed');
            },
            child: Text('Remove', style: AppFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. MOBILE BANKING & E-WALLETS SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildEWalletsSection() {
    final trueMoneyPhone = _cardService.trueMoneyPhone;
    final allowCod = _cardService.allowCod;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Online Wallets & Mobile Banking',
            style: AppFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),

          // PromptPay
          _buildWalletTile(
            title: 'PromptPay (Thai QR)',
            subtitle: 'Any Thai banking app • Instant auto-check',
            badgeText: 'CONNECTED',
            badgeColor: const Color(0xFF003D6B),
            iconWidget: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF003D6B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(PhosphorIconsFill.qrCode, color: Colors.white, size: 22),
              ),
            ),
            trailingAction: Text(
              'Active',
              style: AppFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF10B981),
              ),
            ),
            onTap: () {
              _cardService.setDefaultChannel('PROMPTPAY');
              AppDialog.showToast(context, 'PromptPay set as preferred checkout method ✓');
            },
          ),
          const SizedBox(height: 12),

          // TrueMoney Wallet
          _buildWalletTile(
            title: 'TrueMoney Wallet',
            subtitle: trueMoneyPhone != null && trueMoneyPhone.isNotEmpty
                ? 'Linked: $trueMoneyPhone'
                : 'Direct debit from TrueMoney wallet',
            badgeText: trueMoneyPhone != null ? 'LINKED' : 'WALLET',
            badgeColor: const Color(0xFFFF8200),
            iconWidget: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8200), Color(0xFFFFA726)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(PhosphorIconsFill.wallet, color: Colors.white, size: 22),
              ),
            ),
            trailingAction: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF8200)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _openLinkTrueMoneyModal(context),
              child: Text(
                trueMoneyPhone != null ? 'Edit' : 'Link',
                style: AppFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFFF8200)),
              ),
            ),
            onTap: () => _openLinkTrueMoneyModal(context),
          ),
          const SizedBox(height: 12),

          // Cash on Delivery
          _buildWalletTile(
            title: 'Cash on Delivery (COD)',
            subtitle: 'Pay cash when food arrives (where shop allows)',
            badgeText: 'CASH',
            badgeColor: const Color(0xFF059669),
            iconWidget: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Center(
                child: Icon(PhosphorIconsFill.money, color: Color(0xFF059669), size: 22),
              ),
            ),
            trailingAction: Switch(
              value: allowCod,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
              onChanged: (val) {
                _cardService.setAllowCod(val);
                AppDialog.showToast(context, val ? 'COD enabled' : 'COD disabled');
              },
            ),
            onTap: () {
              _cardService.setAllowCod(!allowCod);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWalletTile({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Widget iconWidget,
    required Widget trailingAction,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: AppFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailingAction,
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. PREFERENCES & SECURITY SETTINGS
  // ─────────────────────────────────────────────────────────────
  Widget _buildPreferencesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security & Checkout Preferences',
            style: AppFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          // 1-Tap Quick Checkout
          _buildPreferenceSwitchRow(
            title: '1-Tap Express Checkout',
            subtitle: 'Skip manual confirmation for food orders under ฿500',
            icon: PhosphorIconsFill.lightning,
            value: _cardService.quickCheckoutUnder500,
            onChanged: (val) => _cardService.setQuickCheckoutUnder500(val),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // Biometric / PIN Protection
          _buildPreferenceSwitchRow(
            title: 'Biometric / PIN Confirmation',
            subtitle: 'Require Face ID or Fingerprint before card auto-debit',
            icon: PhosphorIconsFill.fingerprint,
            value: _cardService.requireBiometric,
            onChanged: (val) => _cardService.setRequireBiometric(val),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // Digital Email Receipt
          _buildPreferenceSwitchRow(
            title: 'Digital E-Receipt via Email',
            subtitle: 'Send official Omise payment slips to your account email',
            icon: PhosphorIconsFill.receipt,
            value: _cardService.emailReceipt,
            onChanged: (val) => _cardService.setEmailReceipt(val),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSwitchRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF334155)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. HISTORY SHORTCUT
  // ─────────────────────────────────────────────────────────────
  Widget _buildHistoryShortcut() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(PhosphorIconsFill.clockCounterClockwise, size: 20, color: Color(0xFF334155)),
        ),
        title: Text(
          'Payment & Order History',
          style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        subtitle: Text(
          'View past receipts, auto-cuts and transactions',
          style: AppFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
        ),
        trailing: const Icon(PhosphorIconsRegular.caretRight, size: 18, color: Color(0xFF94A3B8)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 7. SECURITY GUARANTEE FOOTER
  // ─────────────────────────────────────────────────────────────
  Widget _buildSecurityFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsFill.lockKey, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                '256-Bit SSL Bank Grade Encryption',
                style: AppFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Powered by Omise Gateway • PCI DSS Level 1 Certified.\nCard details are tokenized securely and never stored raw on device.',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPER ICONS
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardBrandTileIcon(CardBrand brand) {
    Color bg = const Color(0xFF1E3A8A);
    String label = 'VISA';

    switch (brand) {
      case CardBrand.visa:
        bg = const Color(0xFF1E3A8A);
        label = 'VISA';
        break;
      case CardBrand.mastercard:
        bg = const Color(0xFFEB001B);
        label = 'MC';
        break;
      case CardBrand.jcb:
        bg = const Color(0xFF0F766E);
        label = 'JCB';
        break;
      default:
        bg = const Color(0xFF334155);
        label = 'CARD';
    }

    return Container(
      width: 44,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildCardBrandMiniLogo(CardBrand brand) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white30),
      ),
      child: Text(
        brand.name.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MODAL 1: ADD NEW CARD (GRAB STYLE INTERACTIVE)
  // ─────────────────────────────────────────────────────────────
  void _openAddCardModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddCardBottomSheet(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MODAL 2: LINK TRUEMONEY PHONE
  // ─────────────────────────────────────────────────────────────
  void _openLinkTrueMoneyModal(BuildContext context) {
    final controller = TextEditingController(text: _cardService.trueMoneyPhone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFF8200),
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsFill.wallet, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Link TrueMoney Wallet',
              style: AppFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your 10-digit TrueMoney registered phone number for 1-tap checkout.',
              style: AppFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                hintText: '08X-XXX-XXXX',
                prefixIcon: const Icon(PhosphorIconsRegular.phone, size: 20, color: Color(0xFFFF8200)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF8200), width: 1.8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.length >= 9) {
                _cardService.setTrueMoneyPhone(text);
                _cardService.setDefaultChannel('TRUEMONEY');
                Navigator.pop(ctx);
                AppDialog.showToast(context, 'TrueMoney linked successfully! ✓');
              } else {
                AppDialog.showToast(context, 'Please enter a valid phone number', isError: true);
              }
            },
            child: Text('Save', style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSecurityInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(PhosphorIconsFill.shieldCheck, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 8),
            Text('Omise Gateway Security', style: AppFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'MyTogether adheres to PCI DSS Level 1 requirements. Your sensitive card data (CVV, cardholder info) is tokenized with bank-grade 256-bit AES encryption.\n\nRaw card details are never saved on local storage or accessible to third parties.',
          style: AppFonts.poppins(fontSize: 12.5, color: const Color(0xFF475569), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Understood', style: AppFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ADD NEW CARD SHEET (INTERACTIVE REAL-TIME PREVIEW)
// ─────────────────────────────────────────────────────────────
class _AddCardBottomSheet extends StatefulWidget {
  const _AddCardBottomSheet();

  @override
  State<_AddCardBottomSheet> createState() => _AddCardBottomSheetState();
}

class _AddCardBottomSheetState extends State<_AddCardBottomSheet> {
  final _cardNumberController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  CardBrand _detectedBrand = CardBrand.generic;
  bool _setAsDefault = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_onNumberChanged);
    _holderNameController.addListener(() => setState(() {}));
    _expiryController.addListener(() => setState(() {}));
    _cvvController.addListener(() => setState(() {}));
  }

  void _onNumberChanged() {
    final clean = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final brand = SavedCardService.detectBrand(clean);
    if (brand != _detectedBrand) {
      setState(() => _detectedBrand = brand);
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _holderNameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final cleanNumber = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final holder = _holderNameController.text.trim();
    final expiry = _expiryController.text.replaceAll('/', '').trim();
    final cvv = _cvvController.text.trim();

    if (cleanNumber.length < 15) {
      AppDialog.showToast(context, 'Please enter a valid 16-digit card number', isError: true);
      return;
    }
    if (holder.isEmpty) {
      AppDialog.showToast(context, 'Please enter cardholder name', isError: true);
      return;
    }
    if (expiry.length < 4) {
      AppDialog.showToast(context, 'Please enter valid expiration date (MM/YY)', isError: true);
      return;
    }
    if (cvv.length < 3) {
      AppDialog.showToast(context, 'Please enter valid 3-digit CVV', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final month = expiry.substring(0, 2);
    final year = expiry.substring(2);

    await SavedCardService.instance.saveCard(
      cardNumber: cleanNumber,
      holderName: holder,
      expiryMonth: month,
      expiryYear: year,
      setAsDefault: _setAsDefault,
    );

    if (_setAsDefault) {
      await SavedCardService.instance.setDefaultChannel('CARD');
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      AppDialog.showToast(context, 'Card added securely! ✓');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Credit / Debit Card',
                  style: AppFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ─────────────────────────────────────────────────────
            // LIVE CARD PREVIEW
            // ─────────────────────────────────────────────────────
            _buildInteractiveCardPreview(),
            const SizedBox(height: 20),

            // Card Number
            _buildLabel('Card Number'),
            TextField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
                _CardNumberInputFormatter(),
              ],
              decoration: _inputDecoration(
                hint: '4000 1234 5678 9010',
                prefixIcon: PhosphorIconsRegular.creditCard,
              ),
            ),
            const SizedBox(height: 14),

            // Cardholder Name
            _buildLabel('Cardholder Name'),
            TextField(
              controller: _holderNameController,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDecoration(
                hint: 'JOHN DOE',
                prefixIcon: PhosphorIconsRegular.user,
              ),
            ),
            const SizedBox(height: 14),

            // Expiry & CVV
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Expiry Date'),
                      TextField(
                        controller: _expiryController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          _CardExpiryInputFormatter(),
                        ],
                        decoration: _inputDecoration(
                          hint: 'MM/YY',
                          prefixIcon: PhosphorIconsRegular.calendar,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('CVV / CVC'),
                      TextField(
                        controller: _cvvController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: _inputDecoration(
                          hint: '•••',
                          prefixIcon: PhosphorIconsRegular.lockSimple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Set as default checkbox
            Row(
              children: [
                Checkbox(
                  value: _setAsDefault,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _setAsDefault = val ?? true),
                ),
                Text(
                  'Set as default payment method',
                  style: AppFonts.poppins(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Save Button
            PrimaryGradientButton(
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _handleSave,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsFill.shieldCheck, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Save Card Securely',
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveCardPreview() {
    final rawNumber = _cardNumberController.text.trim();
    final displayNumber = rawNumber.isNotEmpty ? rawNumber : '•••• •••• •••• ••••';
    final holder = _holderNameController.text.trim();
    final displayHolder = holder.isNotEmpty ? holder.toUpperCase() : 'YOUR NAME';
    final expiry = _expiryController.text.trim();
    final displayExpiry = expiry.isNotEmpty ? expiry : 'MM/YY';

    return Container(
      width: double.infinity,
      height: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _detectedBrand == CardBrand.visa
                ? const Color(0xFF1E3A8A)
                : _detectedBrand == CardBrand.mastercard
                    ? const Color(0xFF991B1B)
                    : const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(PhosphorIconsBold.broadcast, color: Colors.white70, size: 20),
              Text(
                _detectedBrand.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Text(
            displayNumber,
            style: GoogleFonts.sourceCodePro(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CARD HOLDER', style: TextStyle(color: Colors.white60, fontSize: 8)),
                  Text(
                    displayHolder,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('EXPIRES', style: TextStyle(color: Colors.white60, fontSize: 8)),
                  Text(
                    displayExpiry,
                    style: GoogleFonts.sourceCodePro(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: AppFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INPUT FORMATTERS
// ─────────────────────────────────────────────────────────────
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
