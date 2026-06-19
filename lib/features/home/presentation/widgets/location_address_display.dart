import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/location/location_display_util.dart';

/// Shows a location address with optional coordinates beneath it.
class LocationAddressDisplay extends StatelessWidget {
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool showCoordinates;
  final TextStyle? addressStyle;
  final TextStyle? coordinatesStyle;
  final int addressMaxLines;

  const LocationAddressDisplay({
    super.key,
    this.address,
    this.latitude,
    this.longitude,
    this.showCoordinates = true,
    this.addressStyle,
    this.coordinatesStyle,
    this.addressMaxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final readableAddress = LocationDisplayUtil.readableAddress(address);
    final hasCoords = latitude != null && longitude != null;
    final coordsText = hasCoords
        ? LocationDisplayUtil.formatCoordinates(latitude!, longitude!)
        : null;

    final defaultAddressStyle = GoogleFonts.poppins(
      fontSize: 12,
      color: Colors.grey.shade600,
      height: 1.4,
    );
    final defaultCoordsStyle = GoogleFonts.poppins(
      fontSize: 11,
      color: Colors.grey.shade400,
      height: 1.3,
    );

    if (readableAddress == null && coordsText == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (readableAddress != null)
          Text(
            readableAddress,
            style: addressStyle ?? defaultAddressStyle,
            maxLines: addressMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        if (showCoordinates &&
            coordsText != null &&
            (readableAddress != null || coordsText.isNotEmpty)) ...[
          if (readableAddress != null) const SizedBox(height: 3),
          Text(
            coordsText,
            style: coordinatesStyle ?? defaultCoordsStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
