import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

/// Settings screen that lets the user review and manage the runtime
/// permissions the app relies on (notifications and location).
///
/// Works on both iOS and Android via `permission_handler`. When a permission is
/// already granted or permanently denied, the action button deep-links into the
/// OS settings page; otherwise it triggers the native permission prompt.
class AppPermissionsPage extends StatefulWidget {
  const AppPermissionsPage({super.key});

  @override
  State<AppPermissionsPage> createState() => _AppPermissionsPageState();
}

class _AppPermissionsPageState extends State<AppPermissionsPage>
    with WidgetsBindingObserver {
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when the user returns from the OS settings screen so the UI
    // reflects any changes they made there.
    if (state == AppLifecycleState.resumed) {
      _checkPermissions(silent: true);
    }
  }

  Future<void> _checkPermissions({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    if (kIsWeb) {
      final geoPerm = await Geolocator.checkPermission();
      final locationGranted = geoPerm == LocationPermission.always ||
          geoPerm == LocationPermission.whileInUse;

      if (mounted) {
        setState(() {
          _locationStatus =
              locationGranted ? PermissionStatus.granted : PermissionStatus.denied;
          // Browser push permissions are managed outside the native permission API.
          _notificationStatus = PermissionStatus.granted;
          _isLoading = false;
        });
      }
      return;
    }

    final notification = await Permission.notification.status;
    final location = await Permission.location.status;

    if (mounted) {
      setState(() {
        _notificationStatus = notification;
        _locationStatus = location;
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePermission(
    Permission permission,
    PermissionStatus status,
    void Function(PermissionStatus) onUpdated,
  ) async {
    if (kIsWeb) {
      if (permission == Permission.location) {
        await LocationService().getCurrentPosition(requestPermissionIfDenied: true);
        await _checkPermissions(silent: true);
      }
      return;
    }

    // Already granted or blocked by the user -> the only way forward is the
    // OS settings screen.
    if (status.isGranted ||
        status.isPermanentlyDenied ||
        status.isRestricted) {
      await openAppSettings();
      return;
    }

    final result = await permission.request();
    if (result.isPermanentlyDenied) {
      await openAppSettings();
    }
    if (mounted) onUpdated(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('permissions.title'),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('permissions.manage_access'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('permissions.control_desc'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!kIsWeb)
                    _buildPermissionCard(
                      icon: PhosphorIconsRegular.bellRinging,
                      title: context.tr('permissions.notifications_title'),
                      description: context.tr('permissions.notifications_desc'),
                      status: _notificationStatus,
                      onActionPressed: () => _handlePermission(
                        Permission.notification,
                        _notificationStatus,
                        (s) => setState(() => _notificationStatus = s),
                      ),
                    ),
                  if (!kIsWeb) const SizedBox(height: 16),
                  _buildPermissionCard(
                    icon: PhosphorIconsRegular.mapPin,
                    title: context.tr('permissions.location_title'),
                    description: context.tr('permissions.location_desc'),
                    status: _locationStatus,
                    onActionPressed: () => _handlePermission(
                      Permission.location,
                      _locationStatus,
                      (s) => setState(() => _locationStatus = s),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required PermissionStatus status,
    required VoidCallback onActionPressed,
  }) {
    final bool isGranted = status.isGranted;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isGranted
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: PhosphorIcon(
                  icon,
                  size: 24,
                  color: isGranted
                      ? AppColors.primary
                      : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusChip(isGranted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          PrimaryGradientButton(
            onPressed: onActionPressed,
            height: 48,
            borderRadius: BorderRadius.circular(12),
            child: Text(
              isGranted
                  ? context.tr('permissions.open_settings')
                  : context.tr('permissions.allow_access'),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool isGranted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGranted ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGranted
                ? PhosphorIconsFill.checkCircle
                : PhosphorIconsFill.xCircle,
            size: 14,
            color: isGranted ? const Color(0xFF15803D) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Text(
            isGranted
                ? context.tr('permissions.allowed')
                : context.tr('permissions.not_allowed'),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isGranted
                  ? const Color(0xFF15803D)
                  : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
