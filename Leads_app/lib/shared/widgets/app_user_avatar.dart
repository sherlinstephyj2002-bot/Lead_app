import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/providers.dart';

class AppUserAvatar extends ConsumerWidget {
  final UserModel? user;
  final String? userId;
  final String? companyId;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  const AppUserAvatar({
    super.key,
    this.user,
    this.userId,
    this.companyId,
    this.radius = 20,
    this.backgroundColor,
    this.iconColor,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Resolve User
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

    // Check Priority 1: Personal Profile Picture
    final personalPictureUrl = targetUser?.profileImageUrl;
    if (personalPictureUrl != null && personalPictureUrl.trim().isNotEmpty) {
      return _buildAvatarContainer(
        context: context,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.grey.shade200,
          backgroundImage: NetworkImage(personalPictureUrl.trim()),
        ),
      );
    }

    // Check Priority 2: Company Logo
    final targetCompanyId = (targetUser?.companyId != null && targetUser!.companyId.isNotEmpty)
        ? targetUser.companyId
        : (companyId ?? authUser?.companyId ?? '');

    if (targetCompanyId.isNotEmpty) {
      final companyAsync = ref.watch(companyStreamProvider(targetCompanyId));
      return companyAsync.when(
        data: (company) {
          final logoUrl = company?.logoUrl;
          if (logoUrl != null && logoUrl.trim().isNotEmpty) {
            return _buildAvatarContainer(
              context: context,
              child: CircleAvatar(
                radius: radius,
                backgroundColor: backgroundColor ?? Colors.grey.shade200,
                backgroundImage: NetworkImage(logoUrl.trim()),
              ),
            );
          }
          return _buildDefaultAvatar(context);
        },
        loading: () => _buildAvatarContainer(
          context: context,
          child: CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor ?? Colors.grey.shade200,
            child: SizedBox(
              width: radius,
              height: radius,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => _buildDefaultAvatar(context),
      );
    }

    // Priority 3: Default WorkTrack Avatar
    return _buildDefaultAvatar(context);
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.primaryColor.withValues(alpha: 0.1);
    final ic = iconColor ?? theme.primaryColor;

    return _buildAvatarContainer(
      context: context,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Icon(
          Icons.person_rounded,
          size: radius * 1.1,
          color: ic,
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
