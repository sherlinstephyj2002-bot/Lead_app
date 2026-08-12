import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ESSSettingsScreen extends ConsumerWidget {
  const ESSSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5B4CF0), Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        title: const Text(
          'Employee Account Settings',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('SECURITY & CREDENTIALS', 'Manage password & authentication', isDark),
                const SizedBox(height: 12),
                _buildCardContainer(
                  context: context,
                  isDark: isDark,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFF5B4CF0)),
                      title: const Text('Change Account Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Update your login password'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => context.push('/change-password'),
                    ),
                    _buildDivider(isDark),
                    ListTile(
                      leading: const Icon(Icons.devices_rounded, color: Color(0xFF5B4CF0)),
                      title: const Text('Logged In Devices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('2 Active Sessions (Chrome Web & Android)'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('PREFERENCES & SYSTEM', 'App theme & alert notifications', isDark),
                const SizedBox(height: 12),
                _buildCardContainer(
                  context: context,
                  isDark: isDark,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_none_rounded, color: Color(0xFF5B4CF0)),
                      title: const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Configure email & in-app alerts'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => context.push('/notification-settings'),
                    ),
                    _buildDivider(isDark),
                    ListTile(
                      leading: const Icon(Icons.language_rounded, color: Color(0xFF5B4CF0)),
                      title: const Text('Language & Regional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('English (US)'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFF5B4CF0)),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required BuildContext context, required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, indent: 56, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
  }
}
