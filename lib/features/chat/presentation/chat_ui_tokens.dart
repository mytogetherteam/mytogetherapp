import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared chat visual language for MyTogether (matched with MyShop).
abstract final class ChatUiTokens {
  static const double messageBodySize = 15;
  static const double metaSize = 11;
  static const double headerTitleSize = 16;
  static const double headerSubtitleSize = 12;
  static const double composerSize = 15;
  static const double hintSize = 12;

  static const double bubbleRadius = 18;
  static const double bubbleTailRadius = 6;
  static const double composerRadius = 24;
  static const double imageRadius = 16;
  static const double maxBubbleWidthFactor = 0.78;

  static const double gapSameSender = 7;
  static const double gapNewSender = 14;
  static const double composerActionSize = 44;

  static const Color screenBg = Color(0xFFF7F8FA);
  static const Color incomingBubble = Color(0xFFF3F4F6);
  static const Color incomingBubbleDark = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color composerFill = Color(0xFFF1F5F9);
  static const Color hairline = Color(0xFFE8ECF0);

  static TextStyle messageBody({required Color color}) => GoogleFonts.poppins(
        fontSize: messageBodySize,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: color,
      );

  static TextStyle meta({Color color = textMuted}) => GoogleFonts.poppins(
        fontSize: metaSize,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle headerTitle({required Color color}) => GoogleFonts.poppins(
        fontSize: headerTitleSize,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle headerSubtitle({Color color = textMuted}) =>
      GoogleFonts.poppins(
        fontSize: headerSubtitleSize,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle composer({Color? color}) => GoogleFonts.poppins(
        fontSize: composerSize,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle hint({Color color = textSecondary}) => GoogleFonts.poppins(
        fontSize: hintSize,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: color,
      );

  static BorderRadius bubbleRadiusFor({required bool isMine}) =>
      BorderRadius.only(
        topLeft: const Radius.circular(bubbleRadius),
        topRight: const Radius.circular(bubbleRadius),
        bottomLeft: Radius.circular(isMine ? bubbleRadius : bubbleTailRadius),
        bottomRight: Radius.circular(isMine ? bubbleTailRadius : bubbleRadius),
      );

  static Color incomingSurface(Brightness brightness) =>
      brightness == Brightness.dark ? incomingBubbleDark : incomingBubble;
}
