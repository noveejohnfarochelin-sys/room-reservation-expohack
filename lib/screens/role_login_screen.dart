import 'package:flutter/material.dart';
import 'package:room_reservation_expohack/screens/admin_screen.dart';
import 'package:room_reservation_expohack/screens/signatory_screen.dart';
import 'package:room_reservation_expohack/screens/user_home_screen.dart';
import 'package:room_reservation_expohack/services/seed_service.dart';
import 'package:room_reservation_expohack/widgets/common_widgets.dart';

class RoleLoginScreen extends StatefulWidget {
  const RoleLoginScreen({super.key});

  @override
  State<RoleLoginScreen> createState() => _RoleLoginScreenState();
}

class _RoleLoginScreenState extends State<RoleLoginScreen> {
  static const List<String> _signatories = [
    'CCI Dean',
    'COE Dean',
    'GSO Head',
    'University President',
  ];

  String _selectedSignatory = _signatories.first;
  bool _seeding = false;

  Future<void> _seed() async {
    setState(() => _seeding = true);
    String message;
    try {
      message = await SeedService().seedInitialData();
    } catch (e) {
      message = 'Seeding failed: $e';
    }
    if (!mounted) return;
    setState(() => _seeding = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _roleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? extra,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 24, child: Icon(icon)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(subtitle),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (extra != null) ...[const SizedBox(height: 12), extra],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 12),
                Icon(Icons.apartment,
                    size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  'Tech4ISATU',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Smart Campus Facility & Room Booking System',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                _roleCard(
                  icon: Icons.school,
                  title: 'User',
                  subtitle: 'Student / Org Requester',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const UserHomeScreen()),
                  ),
                ),
                _roleCard(
                  icon: Icons.draw,
                  title: 'Signatory',
                  subtitle: 'Dean / President / Office Head',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            SignatoryScreen(signatoryName: _selectedSignatory)),
                  ),
                  extra: LabeledDropdown<String>(
                    label: 'Sign in as',
                    value: _selectedSignatory,
                    items: _signatories
                        .map((s) =>
                            DropdownMenuItem<String>(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedSignatory = v);
                    },
                  ),
                ),
                _roleCard(
                  icon: Icons.admin_panel_settings,
                  title: 'Room Administrator',
                  subtitle: 'Monitor rooms, override bookings, run benchmark',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AdminScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _seeding ? null : _seed,
                  icon: _seeding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload),
                  label: const Text('Seed ISATU Rooms & Signatories'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}