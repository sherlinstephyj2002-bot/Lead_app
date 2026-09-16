import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/providers.dart';
import '../utils/avatar_utils.dart';

class AppUserAvatar extends ConsumerWidget {
  final UserModel? user;
  final String? userId;
  final String? companyId;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;
  final double? fontSize;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  const AppUserAvatar({
    super.key,
    this.user,
    this.userId,
    this.companyId,
    this.name,
    this.radius = 20,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
    this.fontSize,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authProvider).user;
    UserModel? targetUser = user;

    if (targetUser == null && userId != null && userId!.isNotEmpty) {
      if (authUser != null && authUser.uid == userId) {
        targetUser = authUser;
      }
    }

    if (targetUser == null && (userId == null || userId!.isEmpty) && (companyId == null || companyId!.isEmpty)) {
      targetUser = authUser;
    }

    // Explicit name parameter has top priority if provided directly
    String? displayName = name;
    if (displayName == null || displayName.trim().isEmpty) {
      displayName = targetUser?.name;
    }

    // If company avatar requested specifically or user missing name, look up company
    final targetCompanyId = (targetUser?.companyId != null && targetUser!.companyId.isNotEmpty)
        ? targetUser.companyId
        : (companyId ?? authUser?.companyId ?? '');

    if ((displayName == null || displayName.trim().isEmpty) && targetCompanyId.isNotEmpty) {
      final companyAsync = ref.watch(companyStreamProvider(targetCompanyId));
      return companyAsync.when(
        data: (company) {
          final compName = company?.name ?? 'Company';
          return _buildInitialsAvatar(context, compName);
        },
        loading: () => _buildInitialsAvatar(context, 'U'),
        error: (_, _) => _buildInitialsAvatar(context, 'WorkTrack'),
      );
    }

    final effectiveName = displayName ?? authUser?.name ?? authUser?.companyName ?? '';
    return _buildInitialsAvatar(context, effectiveName);
  }

  Widget _buildInitialsAvatar(BuildContext context, String rawName) {
    final initials = getInitials(rawName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? getAvatarColor(rawName, isDark: isDark);
    final fg = textColor ?? Colors.white;
    final computedFontSize = fontSize ?? (initials.length > 1 ? radius * 0.75 : radius * 0.85);

    return _buildAvatarContainer(
      context: context,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Text(
          initials,
          style: TextStyle(
            color: fg,
            fontSize: computedFontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: initials.length > 1 ? -0.5 : 0.0,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarContainer({required BuildContext context, required Widget child}) {
    Widget avatarWidget = child;

    if (showBorder) {
      avatarWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.white.withValues(alpha: 0.5),
            width: borderWidth,
          ),
        ),
        child: child,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
