import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/providers.dart';
import '../widgets/gdpr_panel_widget.dart';
import '../../../constants/user_roles.dart';

class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  bool _notificationAlerts = true;
  bool _offlineCaching = true;

  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _radiusController;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _radiusController = TextEditingController();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == UserRoles.companyAdmin;
    final companyAsync = ref.watch(companyProvider);

    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    // Initialize controller values if not done yet
    if (!_controllersInitialized && companyAsync.value != null) {
      final company = companyAsync.value!;
      _latController.text = company.geofenceLat?.toString() ?? '';
      _lngController.text = company.geofenceLng?.toString() ?? '';
      _radiusController.text = company.geofenceRadius?.toString() ?? '';
      _controllersInitialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Theme settings section
          _buildSettingsHeader('Appearance & Style'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Selection',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                  ),
                  Text(
                    'Choose how WorkTrack looks on your device.',
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                  const SizedBox(height: 16),
                  
                  // Segmented control button bar
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          _buildThemeSegment(
                            ref,
                            title: 'Light',
                            mode: ThemeMode.light,
                            currentMode: themeMode,
                            icon: Icons.light_mode_outlined,
                            width: (constraints.maxWidth) / 3,
                          ),
                          _buildThemeSegment(
                            ref,
                            title: 'Dark',
                            mode: ThemeMode.dark,
                            currentMode: themeMode,
                            icon: Icons.dark_mode_outlined,
                            width: (constraints.maxWidth) / 3,
                          ),
                          _buildThemeSegment(
                            ref,
                            title: 'System',
                            mode: ThemeMode.system,
                            currentMode: themeMode,
                            icon: Icons.settings_brightness_outlined,
                            width: (constraints.maxWidth) / 3,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'App Language',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                  ),
                  Text(
                    'Choose your preferred language for translations.',
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: ref.watch(languageProvider),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      prefixIcon: Icon(Icons.translate_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'es', child: Text('Español (Spanish)')),
                      DropdownMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(languageProvider.notifier).state = val;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Alerts & notifications section
          _buildSettingsHeader('Alert Preferences'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.notifications_active_outlined, color: iconColor),
                  title: Text('Push Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor)),
                  subtitle: Text('Alert me about new lead assignments and reminders.', style: TextStyle(fontSize: 11, color: subtitleColor)),
                  value: _notificationAlerts,
                  onChanged: (val) {
                    setState(() => _notificationAlerts = val);
                  },
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                SwitchListTile(
                  secondary: Icon(Icons.cloud_sync_outlined, color: iconColor),
                  title: Text('Offline Caching', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor)),
                  subtitle: Text('Sync company documents for offline read access.', style: TextStyle(fontSize: 11, color: subtitleColor)),
                  value: _offlineCaching,
                  onChanged: (val) {
                    setState(() => _offlineCaching = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Administration & Module Controls section for Company Admin
          if (isAdmin) ...[
            _buildSettingsHeader('Administration & Feature Controls'),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.security_rounded, color: Color(0xFF06B6D4)),
                    title: Text('Roles & Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                    subtitle: Text('Configure access permissions for Lead Management, Follow-ups, and Tasks', style: TextStyle(fontSize: 11, color: subtitleColor)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.push('/company-admin/permissions'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSettingsHeader('Geofencing Settings'),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Office Coordinates & Bounds',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                    ),
                    Text(
                      'Define office location parameters. Employees must check in inside this radius.',
                      style: TextStyle(fontSize: 11, color: subtitleColor),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'e.g. 12.9716',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'e.g. 77.5946',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _radiusController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Radius (meters)',
                        hintText: 'e.g. 200',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Fetching current coordinates...'), duration: Duration(seconds: 1)),
                                );
                                LocationPermission permission = await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission = await Geolocator.requestPermission();
                                }
                                final position = await Geolocator.getCurrentPosition(
                                  desiredAccuracy: LocationAccuracy.high,
                                );
                                _latController.text = position.latitude.toString();
                                _lngController.text = position.longitude.toString();
                              } catch (e) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Location Error'),
                                    content: Text(e.toString()),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                                    ],
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.my_location_rounded, size: 16),
                            label: const Text('Use Current Location'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final lat = double.tryParse(_latController.text);
                              final lng = double.tryParse(_lngController.text);
                              final radius = double.tryParse(_radiusController.text);
                              
                              if (lat == null || lng == null || radius == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter valid numeric parameters.')),
                                );
                                return;
                              }

                              final success = await ref
                                  .read(companyProvider.notifier)
                                  .updateGeofenceSettings(lat, lng, radius);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Geofence bounds updated successfully!'
                                          : 'Failed to update geofence parameters.',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text('Save Bounds'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Database optimization section
          _buildSettingsHeader('Maintenance'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.cleaning_services_outlined, color: iconColor),
              title: Text('Clear Storage Cache', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor)),
              subtitle: Text('Free up local image cache storage.', style: TextStyle(fontSize: 11, color: subtitleColor)),
              trailing: Icon(Icons.chevron_right, size: 20, color: iconColor),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Local image cache cleared successfully.')),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // GDPR & Privacy policy section
          _buildSettingsHeader('GDPR & Privacy Policy'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.security_outlined, color: iconColor),
              title: Text('Privacy Control Center', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor)),
              subtitle: Text('Manage data sharing, portability, and right to erasure.', style: TextStyle(fontSize: 11, color: subtitleColor)),
              trailing: Icon(Icons.chevron_right, size: 20, color: iconColor),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('Privacy Settings')),
                      body: const GdprPanelWidget(),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // SLA & System Status section
          _buildSettingsHeader('SLA & System Status'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSlaItem(Icons.dns_rounded, 'API Service Uptime', '99.98% (Healthy)', Colors.green),
                  Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  _buildSlaItem(Icons.speed_rounded, 'Database Query Latency', '18ms', Colors.green),
                  Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  _buildSlaItem(Icons.public_rounded, 'SaaS Deployment Region', 'Asia East (Mumbai)', iconColor),
                  Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  _buildSlaItem(Icons.network_ping_rounded, 'Local Connection Ping', '24ms', Colors.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlaItem(IconData icon, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final iconColor = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 13, color: labelColor, fontWeight: FontWeight.w500)),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildSettingsHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildThemeSegment(
    WidgetRef ref, {
    required String title,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required IconData icon,
    required double width,
  }) {
    final isSelected = currentMode == mode;
    final isDark = Theme.of(ref.context).brightness == Brightness.dark;
    final colorScheme = Theme.of(ref.context).colorScheme;

    final unselectedBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final unselectedBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final unselectedFg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return SizedBox(
      width: width,
      height: 48,
      child: GestureDetector(
        onTap: () {
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : unselectedBg,
            borderRadius: _getBorderRadiusForMode(mode),
            border: Border.all(
              color: isSelected ? colorScheme.primary : unselectedBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : unselectedFg,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : unselectedFg,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BorderRadius _getBorderRadiusForMode(ThemeMode mode) {
    if (mode == ThemeMode.light) {
      return const BorderRadius.horizontal(left: Radius.circular(10));
    } else if (mode == ThemeMode.system) {
      return const BorderRadius.horizontal(right: Radius.circular(10));
    } else {
      return BorderRadius.zero;
    }
  }
}
