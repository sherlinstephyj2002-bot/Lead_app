import 'package:flutter/material.dart';

/// Centralized responsive design utility for WorkTrack application.
/// Provides responsive breakpoints, mobile font scaling, and adaptive padding
/// without altering desktop layouts.
class AppResponsive {
  // Breakpoint Constants
  static const double mobileMax = 599.0;
  static const double tabletMax = 1023.0;

  /// Returns true if current viewport width is mobile (< 600px)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= mobileMax;
  }

  /// Returns true if current viewport width is tablet (600px - 1023px)
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w > mobileMax && w <= tabletMax;
  }

  /// Returns true if current viewport width is desktop (>= 1024px)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > tabletMax;
  }

  /// Scales font size proportionally for smaller screens while keeping desktop size 100% untouched.
  /// Desktop (>= 1024px) -> exact desktopSize
  /// Mobile (< 600px) -> proportional scale (~85% of desktopSize) with min limit
  static double fontSize(
    BuildContext context,
    double desktopSize, {
    double? mobileSize,
    double minSize = 10.0,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024.0) return desktopSize;

    final targetMobileSize = mobileSize ?? (desktopSize * 0.85);

    if (width <= 360.0) {
      return targetMobileSize.clamp(minSize, desktopSize);
    } else if (width < 600.0) {
      final ratio = (width - 360.0) / (600.0 - 360.0);
      return (targetMobileSize + (desktopSize * 0.9 - targetMobileSize) * ratio)
          .clamp(minSize, desktopSize);
    } else {
      // Tablet range (600 - 1023)
      final ratio = (width - 600.0) / (1024.0 - 600.0);
      return (desktopSize * 0.9 + (desktopSize - desktopSize * 0.9) * ratio)
          .clamp(minSize, desktopSize);
    }
  }

  /// Adaptive horizontal padding for container padding
  static double horizontalPadding(
    BuildContext context, {
    double desktop = 24.0,
    double mobile = 14.0,
  }) {
    return isMobile(context) ? mobile : desktop;
  }

  /// Adaptive vertical padding
  static double verticalPadding(
    BuildContext context, {
    double desktop = 24.0,
    double mobile = 14.0,
  }) {
    return isMobile(context) ? mobile : desktop;
  }

  /// Adaptive card border radius
  static double borderRadius(
    BuildContext context, {
    double desktop = 16.0,
    double mobile = 12.0,
  }) {
    return isMobile(context) ? mobile : desktop;
  }

  /// Grid column count calculator
  static int gridColumns(
    BuildContext context, {
    int desktop = 4,
    int tablet = 2,
    int mobile = 1,
  }) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1024.0) return desktop;
    if (w >= 600.0) return tablet;
    return mobile;
  }
}
