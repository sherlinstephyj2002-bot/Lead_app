import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';

class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> _articles = [
    {
      'category': 'Getting Started',
      'title': 'How do I invite employees?',
      'content': 'To invite employees to your company, go to the More tab, click on "Employees", and click "Invite Employee". Let them know they should register with the EXACT company name you configured. Once they self-register, you will see them in your employees list and can upgrade their roles.'
    },
    {
      'category': 'Getting Started',
      'title': 'How to set up your profile?',
      'content': 'Go to the More tab, click on My Profile. You can edit your Full Name, Phone Number, Email, and Organization Name. Tap the "Save Details" button to update your profile instantly in Firebase Auth and Firestore.'
    },
    {
      'category': 'Geofencing & Attendance',
      'title': 'What is geofencing check-in?',
      'content': 'Geofencing restricts check-ins to authorized locations (e.g. office coordinates). When checking in, the app checks if your current GPS coordinates fall within the geofencing radius set by your administrator. If you are outside the radius, check-in is blocked.'
    },
    {
      'category': 'Geofencing & Attendance',
      'title': 'How to apply for leaves?',
      'content': 'Navigate to the Attendance tab, switch to the "Leaves" page, and tap the floating "+" button. Fill in the leave type, dates range, and reason. Once submitted, your Company Admin will receive a notification to approve or reject the request.'
    },
    {
      'category': 'Managing Leads',
      'title': 'How to import leads from CSV?',
      'content': 'Go to the Leads tab, tap the Actions menu button (top-right), and click "Import CSV". Pick your `.csv` file. Ensure your CSV has headers like "name", "phone", "email", and "requirement" so the fields are parsed correctly.'
    },
    {
      'category': 'Billing & SaaS Plans',
      'title': 'How do I upgrade my subscription?',
      'content': 'Go to the More tab, select "Subscription", and click "Upgrade Plan". Complete the checkout form. Once payment completes, your plan updates to Pro/Enterprise in real-time, unlocking admin reports and attendance logs.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isWide = MediaQuery.of(context).size.width >= 720;

    final filteredArticles = _articles.where((art) {
      final q = _searchQuery.toLowerCase();
      return art['title']!.toLowerCase().contains(q) ||
          art['content']!.toLowerCase().contains(q) ||
          art['category']!.toLowerCase().contains(q);
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppTranslations.translate('help_center', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 900 : double.infinity),
          child: Column(
            children: [
              // Search Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                color: Theme.of(context).colorScheme.primary,
                child: Column(
                  children: [
                    const Text(
                      'How can we help you today?',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? Theme.of(context).cardColor : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
                              decoration: const InputDecoration(
                                hintText: 'Search topics, articles, and FAQs...',
                                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                filled: false,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B), size: 20),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Article List
              Expanded(
                child: filteredArticles.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 60),
                          Icon(Icons.search_off_rounded, size: 64, color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'No matching articles found.',
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 15),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredArticles.length,
                        itemBuilder: (ctx, index) {
                          final art = filteredArticles[index];
                          final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
                          final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
                          final bodyColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
                          final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            color: cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: borderCol),
                            ),
                            child: ExpansionTile(
                              title: Text(
                                art['title']!,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                              ),
                              subtitle: Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  art['category']!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              backgroundColor: cardBg,
                              collapsedBackgroundColor: cardBg,
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              expandedAlignment: Alignment.topLeft,
                              children: [
                                Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                const SizedBox(height: 12),
                                Text(
                                  art['content']!,
                                  style: TextStyle(fontSize: 13, color: bodyColor, height: 1.5),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
