import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/ess_provider.dart';
import '../../../shared/widgets/app_user_avatar.dart';

class ESSHeaderCard extends ConsumerWidget {
  const ESSHeaderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(essProvider);
    final profile = state.profile;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B4CF0), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335B4CF0),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Employee Photo Avatar
              const AppUserAvatar(
                radius: 32,
                showBorder: true,
                borderColor: Colors.white,
                borderWidth: 2.5,
              ),
              const SizedBox(width: 16),

              // Title & Basic Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            profile.employeeId,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.designation} • ${profile.department}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFFC7D2FE), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.supervisor_account_rounded, size: 14, color: Color(0xFFA5B4FC)),
                        const SizedBox(width: 4),
                        Text(
                          'Manager: ${profile.reportingManager}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFE0E7FF)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // View Profile Button
              OutlinedButton.icon(
                onPressed: () => context.push('/ess/profile'),
                icon: const Icon(Icons.person_outline_rounded, size: 16),
                label: const Text('My Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),

          // Meta Footer Info Row
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _buildMetaTag(Icons.location_on_outlined, profile.branch),
              _buildMetaTag(Icons.schedule_rounded, profile.shift),
              _buildMetaTag(Icons.verified_user_rounded, profile.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFFC7D2FE)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
