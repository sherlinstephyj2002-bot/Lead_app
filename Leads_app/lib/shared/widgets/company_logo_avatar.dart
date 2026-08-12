import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_user_avatar.dart';
import '../models/user_model.dart';

class CompanyLogoAvatar extends ConsumerWidget {
  final String companyId;
  final UserModel? user;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;

  const CompanyLogoAvatar({
    super.key,
    required this.companyId,
    this.user,
    this.radius = 20,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppUserAvatar(
      user: user,
      companyId: companyId,
      radius: radius,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
    );
  }
}
