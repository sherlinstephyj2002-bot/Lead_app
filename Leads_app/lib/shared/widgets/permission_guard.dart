import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:worktrack/shared/providers/permissions_provider.dart';

class PermissionGuard extends ConsumerWidget {
  final String? permission;
  final List<String>? permissions;
  final bool requireAll;
  final Widget child;

  const PermissionGuard({
    super.key,
    this.permission,
    this.permissions,
    this.requireAll = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(permissionServiceProvider);
    final permissionsAsync = ref.watch(userPermissionsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Guard against loading state
    if (permissionsAsync.isLoading) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    bool allowed = false;
    if (permission != null) {
      allowed = service.hasPermission(permission!);
    } else if (permissions != null) {
      allowed = requireAll
          ? permissions!.every((p) => service.hasPermission(p))
          : service.hasAnyPermission(permissions!);
    } else {
      allowed = true;
    }

    if (!allowed) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: titleColor),
            onPressed: () => Navigator.maybeOf(context)?.pop(),
          ),
          title: Text('Access Denied', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2), width: 2),
                  ),
                  child: const Icon(
                    Icons.gpp_bad_rounded,
                    size: 64,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You do not have permission to access this feature. Please contact your company administrator to request access.',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      // Fallback if we cannot pop
                      try {
                        Navigator.of(context).pushReplacementNamed('/main');
                      } catch (_) {}
                    }
                  },
                  icon: const Icon(Icons.home_rounded, size: 18),
                  label: const Text('Back to Home'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return child;
  }
}
