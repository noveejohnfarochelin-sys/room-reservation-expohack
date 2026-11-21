// UniSpace (ISATU) – Flutter UI in the "StayNest" style.
// FIREBASE VERSION: every screen reads and writes Cloud Firestore through the
// data layer (BookingModel, RoomModel, BookingAlgorithmService, FirestoreServer,
// SeedService). No in-memory / mock data is used.
// Demo logins: student/student, student2/student2, admin/admin
// Tip: CCI > Room 101 already has bookings today – try 10:00-11:00 to see conflict suggestions.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:room_reservation_expohack/firebase_options.dart';
import 'package:room_reservation_expohack/services/booking_algorithm_service.dart';
import 'package:room_reservation_expohack/services/firestore_server.dart';
import 'package:room_reservation_expohack/services/seed_service.dart';

/* ───────────────────────── theme ───────────────────────── */

class C {
  static const blue = Color(0xFF1F4FD8);
  static const navy = Color(0xFF0B1B4D);
  static const ink = Color(0xFF0F172A);
  static const mut = Color(0xFF64748B);
  static const line = Color(0xFFE5EAF3);
  static const bg = Color(0xFFEFF3FB);
  static const tint = Color(0xFFEAF0FF);
  static const free = Color(0xFFDDF4EA);
  static const freeInk = Color(0xFF0A5A43);
  static const pend = Color(0xFFFFF1C7);
  static const pendInk = Color(0xFF6B4B00);
  static const busy = Color(0xFFFDE4DA);
  static const busyInk = Color(0xFF8A2F10);
}

const int kOpen = BookingAlgorithmService.operatingStart;
const int kClose = BookingAlgorithmService.operatingEnd;
const int kStep = BookingAlgorithmService.slotStep;

/* ───────────────────────── helpers ───────────────────────── */

String pad(int n) => n.toString().padLeft(2, '0');

String fmt(int m) {
  final h = m ~/ 60;
  return '${((h + 11) % 12) + 1}:${pad(m % 60)} ${h < 12 ? 'AM' : 'PM'}';
}

String iso(DateTime d) => '${d.year}-${pad(d.month)}-${pad(d.day)}';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
const _wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String longDate(String s) {
  final d = DateTime.parse(s);
  return '${_wd[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';
}

String shortDate(String s) {
  final d = DateTime.parse(s);
  return '${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';
}

String todayLong() {
  final d = DateTime.now();
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

IconData kindIcon(String kind) {
  switch (kind) {
    case 'Laboratory':
      return Icons.computer_rounded;
    case 'Studio':
      return Icons.architecture_rounded;
    case 'Workshop':
      return Icons.construction_rounded;
    case 'Meeting room':
      return Icons.groups_rounded;
    case 'Study room':
      return Icons.menu_book_rounded;
    case 'Gym':
      return Icons.fitness_center_rounded;
    case 'Outdoor stage':
      return Icons.stadium_outlined;
    case 'Facility':
      return Icons.meeting_room_outlined;
    default:
      return Icons.school_outlined;
  }
}

/* ───────────────────────── building colors ───────────────────────── */
// CEA orange · CCI green · COE yellow · CIT blue · CGBE gray · Library purple · Campus facilities teal/rose

Color accentFor(String code) {
  switch (code) {
    case 'CEA':
      return const Color(0xFFEA580C);
    case 'CCI':
      return const Color(0xFF16A34A);
    case 'COE':
      return const Color(0xFFCA8A04);
    case 'CIT':
      return const Color(0xFF2563EB);
    case 'CGBE':
      return const Color(0xFF64748B);
    case 'LIB':
      return const Color(0xFF7C3AED);
    case 'GRAND':
      return const Color(0xFFE11D48);
    case 'MEC':
    case 'FAC':
      return const Color(0xFF0D9488);
    default:
      return C.blue;
  }
}

List<Color> gradFor(String code) {
  switch (code) {
    case 'CEA':
      return const [Color(0xFFC2410C), Color(0xFFFB923C)];
    case 'CCI':
      return const [Color(0xFF166534), Color(0xFF4ADE80)];
    case 'COE':
      return const [Color(0xFFA16207), Color(0xFFFACC15)];
    case 'CIT':
      return const [Color(0xFF1E3A8A), Color(0xFF3B82F6)];
    case 'CGBE':
      return const [Color(0xFF334155), Color(0xFF94A3B8)];
    case 'LIB':
      return const [Color(0xFF5B21B6), Color(0xFFA78BFA)];
    case 'GRAND':
      return const [Color(0xFF9F1239), Color(0xFFFB7185)];
    case 'MEC':
    case 'FAC':
      return const [Color(0xFF0F766E), Color(0xFF2DD4BF)];
    default:
      return const [Color(0xFF0B1B4D), Color(0xFF2A62F0)];
  }
}

String buildingLabel(String code) => code == 'LIB' ? 'Library' : code;

IconData buildingIcon(String code) =>
    code == 'LIB' ? Icons.local_library_rounded : Icons.apartment_rounded;

class HeaderBanner extends StatelessWidget {
  final String code;
  final IconData icon;
  final String title;
  final String subtitle;
  const HeaderBanner({super.key, required this.code, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: gradFor(code), begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(children: [
        Positioned(right: -10, bottom: -30, child: Icon(icon, size: 130, color: Colors.white.withAlpha(40))),
        Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(225), fontSize: 13)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class TagChip extends StatelessWidget {
  final String text;
  final Color color;
  const TagChip(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

/* ───────────────────────── API (Firestore-backed) ───────────────────────── */

class Api {
  static String? token;
  static Map<String, dynamic>? user;
  static final navKey = GlobalKey<NavigatorState>();

  static bool get isAdmin => user?['role'] == 'admin';

  static Future<void> load() async {}
  static Future<void> save() async {}

  static Future<void> logout() async {
    token = null;
    user = null;
    navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (r) => false,
    );
  }

  static Future<Resp> call(String method, String path, {Map<String, dynamic>? body}) async {
    try {
      return await FirestoreServer.handle(method, path, body ?? {}, token);
    } catch (e) {
      debugPrint('Api.call $method $path failed: $e');
      return Resp(500, {'error': 'Could not reach the database. Please try again.'});
    }
  }

  static Future<void> openLetter(String id) async {
    final b = await FirestoreServer.bookingById(id);
    final ctx = navKey.currentContext;
    if (b == null || ctx == null || !ctx.mounted) return;
    final ref = id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
    final text = 'Reference: US-$ref\n\n'
        '${todayLong()}\n\n'
        '${b['addressee']}\nIloilo Science and Technology University\n\n'
        'Dear Sir/Madam:\n\n'
        'I respectfully request to use ${b['room_name']} (${b['college']}) on '
        '${longDate(b['date'])}, ${fmt(b['start_min'])} – ${fmt(b['end_min'])}, for ${b['purpose']}, '
        'with approximately ${b['attendees']} attendees, under ${b['organization']}.\n\n'
        'Your kind approval of this request will be highly appreciated. Thank you.\n\n'
        'Respectfully yours,\n\n${b['requester_name']}\n${b['organization']}';
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Request letter'),
        content: SingleChildScrollView(
          child: Text(text, style: const TextStyle(fontFamily: 'serif', height: 1.55, fontSize: 13.5)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
      ),
    );
  }
}

/* ───────────────────────── app ───────────────────────── */

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    final msg = await SeedService().seedInitialData();
    debugPrint('SeedService: $msg');
  } catch (e) {
    debugPrint('SeedService failed: $e');
  }
  await Api.load();
  runApp(const UniSpaceApp());
}

class UniSpaceApp extends StatelessWidget {
  const UniSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniSpace · ISATU',
      debugShowCheckedModeBanner: false,
      navigatorKey: Api.navKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: C.blue, primary: C.blue),
        scaffoldBackgroundColor: C.bg,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C.blue, width: 1.6),
          ),
        ),
      ),
      home: Api.token != null ? const HomePage() : const LoginPage(),
    );
  }
}

/* ───────────────────────── shared widgets ───────────────────────── */

void goHome(BuildContext c) => Navigator.of(c).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (r) => false,
    );

void goMine(BuildContext c, {bool admin = false}) => Navigator.of(c).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MyRequestsPage(admin: admin)),
      (r) => r.isFirst,
    );

BoxDecoration cardDeco({double radius = 18}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: C.line),
      boxShadow: const [BoxShadow(color: Color(0x0F1F4FD8), blurRadius: 18, offset: Offset(0, 6))],
    );

class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool outlined;
  final bool busy;
  final bool small;
  const Btn(this.label,
      {super.key, this.onTap, this.icon, this.outlined = false, this.busy = false, this.small = false});

  @override
  Widget build(BuildContext context) {
    final h = small ? 38.0 : 48.0;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final child = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? C.blue : Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: small ? 13 : 15)),
            ],
          );
    if (outlined) {
      return OutlinedButton(
        onPressed: busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, h),
          padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20),
          foregroundColor: C.ink,
          side: const BorderSide(color: C.line),
          shape: shape,
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        minimumSize: Size(0, h),
        padding: EdgeInsets.symmetric(horizontal: small ? 14 : 22),
        backgroundColor: C.blue,
        foregroundColor: Colors.white,
        shape: shape,
      ),
      child: child,
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  final String kind; // good | warn | bad
  const StatusChip(this.text, this.kind, {super.key});

  @override
  Widget build(BuildContext context) {
    final bg = kind == 'good' ? C.free : kind == 'warn' ? C.pend : C.busy;
    final fg = kind == 'good' ? C.freeInk : kind == 'warn' ? C.pendInk : C.busyInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class Alert extends StatelessWidget {
  final String text;
  final String kind; // good | warn | bad
  const Alert(this.text, this.kind, {super.key});

  @override
  Widget build(BuildContext context) {
    final bg = kind == 'good' ? C.free : kind == 'warn' ? C.pend : C.busy;
    final fg = kind == 'good' ? C.freeInk : kind == 'warn' ? C.pendInk : C.busyInk;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 13, height: 1.45, fontWeight: FontWeight.w600)),
    );
  }
}

class RGrid extends StatelessWidget {
  final List<Widget> children;
  final double minW;
  final double gap;
  const RGrid({super.key, required this.children, this.minW = 220, this.gap = 14});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (c, box) {
      final cols = ((box.maxWidth + gap) / (minW + gap)).floor().clamp(1, 6);
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
      ),
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
}

class Crumb extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const Crumb(this.label, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_back_rounded, size: 18, color: C.blue),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: C.blue, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class Shell extends StatelessWidget {
  final Widget child;
  final String active;
  const Shell({super.key, required this.child, this.active = ''});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 820;
    final name = (Api.user?['name'] ?? 'Guest').toString().split(' ').first;

    Widget navItem(String id, String label, VoidCallback onTap) {
      final on = active == id;
      return InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: on ? C.blue : Colors.transparent, width: 2)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? C.blue : C.ink)),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Container(
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.line))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Row(children: [
                  InkWell(
                    onTap: () => goHome(context),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('UniSpace',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: C.navy, height: 1.1)),
                        Text('Book campus spaces with ease', style: TextStyle(fontSize: 10, color: C.mut)),
                      ]),
                    ]),
                  ),
                  const Spacer(),
                  if (wide) ...[
                    navItem('home', 'Home', () => goHome(context)),
                    navItem('mine', 'My Requests', () => goMine(context)),
                    if (Api.isAdmin) navItem('admin', 'Admin', () => goMine(context, admin: true)),
                    const SizedBox(width: 16),
                  ],
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'home') goHome(context);
                      if (v == 'mine') goMine(context);
                      if (v == 'admin') goMine(context, admin: true);
                      if (v == 'out') Api.logout();
                    },
                    itemBuilder: (_) => [
                      if (!wide) const PopupMenuItem(value: 'home', child: Text('Home')),
                      if (!wide) const PopupMenuItem(value: 'mine', child: Text('My Requests')),
                      if (!wide && Api.isAdmin) const PopupMenuItem(value: 'admin', child: Text('Admin')),
                      const PopupMenuItem(value: 'out', child: Text('Sign out')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.person_rounded, size: 18, color: C.blue),
                        const SizedBox(width: 6),
                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: C.mut),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

/* ───────────────────────── login ───────────────────────── */

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final user = TextEditingController(text: 'student');
  final pass = TextEditingController(text: 'student');
  String? error;
  bool busy = false;

  Future<void> _login() async {
    setState(() {
      busy = true;
      error = null;
    });
    final r = await Api.call('POST', '/login', body: {'username': user.text, 'password': pass.text});
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        busy = false;
        error = r.error;
      });
      return;
    }
    Api.token = r.data['token'];
    Api.user = Map<String, dynamic>.from(r.data['user']);
    await Api.save();
    if (!mounted) return;
    goHome(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1B4D), Color(0xFF1F4FD8), Color(0xFF4F8BFF)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: cardDeco(radius: 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.apartment_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text('UniSpace',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.navy)),
                  ]),
                  const SizedBox(height: 22),
                  const Text('Sign in', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Book ISATU spaces without double-booking.', style: TextStyle(color: C.mut)),
                  const SizedBox(height: 18),
                  TextField(
                    controller: user,
                    decoration: const InputDecoration(
                        labelText: 'Username', prefixIcon: Icon(Icons.person_outline_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pass,
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                    decoration: const InputDecoration(
                        labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                  ),
                  if (error != null) Alert(error!, 'bad'),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: Btn('Sign in', onTap: _login, busy: busy)),
                  const SizedBox(height: 12),
                  const Text('Demo: student / student · student2 / student2 · admin / admin',
                      style: TextStyle(fontSize: 12, color: C.mut)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── home ───────────────────────── */

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const StatTile({super.key, required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withAlpha(22), Colors.white),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withAlpha(38), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$value', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.1, color: C.ink)),
            Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.mut)),
          ]),
        ),
      ]),
    );
  }
}

class AnalyticsCard extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final bool wide;
  const AnalyticsCard({super.key, required this.stats, required this.wide});

  static const _amber = Color(0xFFF59E0B);
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFEF4444);

  int _n(String k) => (stats?[k] as int?) ?? 0;

  Widget _title(String t, {bool live = false}) {
    return Row(children: [
      const Icon(Icons.insights_rounded, color: C.blue, size: 20),
      const SizedBox(width: 8),
      Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const Spacer(),
      if (live)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: C.free, borderRadius: BorderRadius.circular(99)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 8, color: _green),
            SizedBox(width: 5),
            Text('Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: C.freeInk)),
          ]),
        ),
    ]);
  }

  Widget _tiles() {
    return Column(children: [
      Row(children: [
        Expanded(child: StatTile(icon: Icons.event_note_rounded, label: 'Total bookings', value: _n('total'), color: C.blue)),
        const SizedBox(width: 8),
        Expanded(child: StatTile(icon: Icons.hourglass_top_rounded, label: 'Pending', value: _n('pending'), color: _amber)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: StatTile(icon: Icons.check_circle_rounded, label: 'Approved', value: _n('approved'), color: _green)),
        const SizedBox(width: 8),
        Expanded(child: StatTile(icon: Icons.today_rounded, label: 'Booked today', value: _n('today'), color: const Color(0xFF7C3AED))),
      ]),
    ]);
  }

  Widget _dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontSize: 11, color: C.mut)),
      ]);

  Widget _split() {
    final a = _n('approved'), p = _n('pending'), r = _n('rejected');
    final t = a + p + r;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Request status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(t == 0 ? 'No requests yet' : '${(a * 100 / t).round()}% approved',
            style: const TextStyle(fontSize: 11, color: C.mut)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 10,
          child: t == 0
              ? Container(color: C.line)
              : Row(children: [
                  if (a > 0) Expanded(flex: a, child: Container(color: _green)),
                  if (p > 0) Expanded(flex: p, child: Container(color: _amber)),
                  if (r > 0) Expanded(flex: r, child: Container(color: _red)),
                ]),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 12, runSpacing: 4, children: [
        _dot(_green, 'Approved $a'),
        _dot(_amber, 'Pending $p'),
        _dot(_red, 'Rejected $r'),
      ]),
    ]);
  }

  Widget _chart(double barMax) {
    final groups = ((stats?['groups'] as List?) ?? const []).cast<Map<String, dynamic>>();
    var maxV = 1;
    for (final g in groups) {
      if ((g['total'] as int) > maxV) maxV = g['total'] as int;
    }
    return SizedBox(
      height: barMax + 46,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final g in groups)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${g['total']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Builder(builder: (_) {
                final t = g['total'] as int, p = g['pending'] as int;
                final color = accentFor(g['code'].toString());
                final h = t == 0 ? 3.0 : (t / maxV * barMax).clamp(8.0, barMax).toDouble();
                final ph = t == 0 ? 0.0 : h * p / t;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: wide ? 28 : 20,
                    height: h,
                    color: t == 0 ? C.line : color,
                    child: Column(children: [
                      if (ph > 0) Container(height: ph, color: Colors.white.withAlpha(110)),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 5),
              Text(g['code'].toString(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.mut)),
            ]),
          ),
      ]),
    );
  }

  Widget _chartLegend() => Wrap(spacing: 14, children: [
        _dot(C.ink, 'Booked (solid)'),
        _dot(Colors.black26, 'Pending (faded top)'),
      ]);

  @override
  Widget build(BuildContext context) {
    final deco = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: Color(0x261F4FD8), blurRadius: 30, offset: Offset(0, 12))],
    );
    if (wide) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: deco,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 5,
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _title('Booking analytics', live: true),
              _tiles(),
              _split(),
            ]),
          ),
          Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 20), color: C.line),
          Expanded(
            flex: 6,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bookings per building', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              _chart(100),
              const SizedBox(height: 8),
              _chartLegend(),
            ]),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: deco,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Booking analytics', live: true),
        const SizedBox(height: 12),
        _tiles(),
        const SizedBox(height: 14),
        _split(),
        const SizedBox(height: 16),
        const Text('Bookings per building', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),
        _chart(90),
        const SizedBox(height: 8),
        _chartLegend(),
      ]),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> colleges = [];
  List<Map<String, dynamic>> facilities = [];
  Map<String, dynamic>? stats;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rs = await Future.wait([
      Api.call('GET', '/colleges'),
      Api.call('GET', '/facilities'),
      Api.call('GET', '/stats'),
    ]);
    if (!mounted) return;
    if (!rs[0].ok) {
      setState(() {
        loading = false;
        error = rs[0].error;
      });
      return;
    }
    setState(() {
      colleges = List<Map<String, dynamic>>.from(rs[0].data as List);
      facilities = rs[1].ok ? List<Map<String, dynamic>>.from(rs[1].data as List) : [];
      stats = rs[2].ok ? Map<String, dynamic>.from(rs[2].data as Map) : null;
      loading = false;
    });
  }

  Widget _hero(bool wide) {
    return Container(
      height: wide ? 320 : 230,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1B4D), Color(0xFF1F4FD8), Color(0xFF4F8BFF)],
        ),
      ),
      child: Stack(children: [
        Positioned(
            right: -30,
            bottom: -40,
            child: Icon(Icons.apartment_rounded, size: wide ? 360 : 230, color: Colors.white.withAlpha(28))),
        Positioned(
            right: 180,
            top: -80,
            child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(14)))),
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 44 : 22, wide ? 36 : 26, 22, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome to UniSpace',
                style: TextStyle(color: Colors.white, fontSize: wide ? 17 : 15, fontWeight: FontWeight.w300)),
            const SizedBox(height: 4),
            Text('Book Your Campus Space',
                style: TextStyle(
                    color: Colors.white, fontSize: wide ? 42 : 28, fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                'Rooms, labs, the library, the gym and the grandstand — all in one place, with zero double-booking.',
                style: TextStyle(color: Colors.white.withAlpha(220), fontSize: wide ? 14 : 12.5, height: 1.5),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _features() {
    const items = [
      [Icons.verified_outlined, 'Zero Double-Booking', 'Conflicts are blocked instantly'],
      [Icons.description_outlined, 'Auto-filled Letter', 'Request letter ready in seconds'],
      [Icons.event_available_outlined, 'Live Availability', 'See free slots in real time'],
      [Icons.task_alt_rounded, 'Quick Approval', 'Track your request status'],
    ];
    return RGrid(
      minW: 230,
      gap: 12,
      children: [
        for (final it in items)
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: C.tint, shape: BoxShape.circle),
              child: Icon(it[0] as IconData, color: C.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it[1] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 2),
                Text(it[2] as String, style: const TextStyle(fontSize: 11.5, color: C.mut)),
              ]),
            ),
          ]),
      ],
    );
  }

  Widget _collegeCard(Map<String, dynamic> c) {
    final code = c['code'].toString();
    final g = gradFor(code);
    final label = buildingLabel(code);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RoomsPage(collegeId: c['id'].toString(), code: code)))
          .then((_) => _load()),
      child: Container(
        decoration: cardDeco(),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Stack(children: [
              Positioned(
                  right: -14,
                  bottom: -18,
                  child: Icon(buildingIcon(code), size: 110, color: Colors.white.withAlpha(46))),
              Center(
                child: Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(code == 'LIB' ? 'University Library' : 'College of $code',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${c['rooms']} rooms & facilities', style: const TextStyle(fontSize: 12, color: C.mut)),
              const SizedBox(height: 2),
              Text('Open 8:00 AM – 5:00 PM',
                  style: TextStyle(fontSize: 11.5, color: accentFor(code), fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _facilityCard(Map<String, dynamic> f) {
    final code = f['code'].toString();
    final g = gradFor(code);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RoomPage(roomId: f['id'].toString())))
          .then((_) => _load()),
      child: Container(
        decoration: cardDeco(),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 120,
              decoration: BoxDecoration(gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Icon(kindIcon(f['kind'].toString()), color: Colors.white, size: 52),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TagChip('Standalone · ${f['kind']}', accentFor(code)),
                  const SizedBox(height: 8),
                  Text(f['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(f['blurb'].toString(), style: const TextStyle(fontSize: 12.5, color: C.mut, height: 1.4)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.groups_rounded, size: 16, color: C.mut),
                    const SizedBox(width: 6),
                    Text('Up to ${f['capacity']} people',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, color: accentFor(code)),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Shell(
      active: 'home',
      child: PageBody(children: [
        if (wide) ...[
          Stack(clipBehavior: Clip.none, children: [
            _hero(true),
            Positioned(left: 24, right: 24, bottom: -110, height: 270, child: AnalyticsCard(stats: stats, wide: true)),
          ]),
          const SizedBox(height: 134),
        ] else ...[
          _hero(false),
          const SizedBox(height: 12),
          AnalyticsCard(stats: stats, wide: false),
          const SizedBox(height: 20),
        ],
        _features(),
        const SizedBox(height: 28),
        const Text('Colleges & Library', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Choose a building to see its rooms and facilities.', style: TextStyle(color: C.mut, fontSize: 13)),
        const SizedBox(height: 14),
        if (loading)
          const Loading()
        else if (error != null)
          Alert(error!, 'bad')
        else
          RGrid(minW: 190, children: [for (final c in colleges) _collegeCard(c)]),
        const SizedBox(height: 28),
        const Text('Campus Facilities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Standalone venues you can book directly.', style: TextStyle(color: C.mut, fontSize: 13)),
        const SizedBox(height: 14),
        if (!loading && facilities.isNotEmpty)
          RGrid(minW: 400, gap: 14, children: [for (final f in facilities) _facilityCard(f)]),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withAlpha(190), borderRadius: BorderRadius.circular(16)),
          child: const Row(children: [
            Icon(Icons.school_rounded, color: C.blue),
            SizedBox(width: 10),
            Expanded(
              child: Text('Iloilo Science and Technology University · 30-minute slots · 8:00 AM – 5:00 PM',
                  style: TextStyle(fontSize: 12.5, color: C.mut, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/* ───────────────────────── rooms in a college ───────────────────────── */

class RoomsPage extends StatefulWidget {
  final String collegeId;
  final String code;
  final DateTime? date;
  final int? start;
  final int? end;
  final int? guests;
  const RoomsPage({super.key, required this.collegeId, required this.code, this.date, this.start, this.end, this.guests});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rooms = [];
  final Map<String, String> avail = {};

  bool get filtered => widget.start != null && widget.end != null;
  String get dateStr => iso(widget.date ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.call('GET', '/colleges/${widget.collegeId}/rooms?date=$dateStr');
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        loading = false;
        error = r.error;
      });
      return;
    }
    final list = List<Map<String, dynamic>>.from(r.data as List);
    if (filtered) {
      await Future.wait(list.map((room) async {
        final d = await Api.call('GET', '/rooms/${room['id']}/day?date=$dateStr');
        final busy = (d.data is Map ? (d.data['busy'] as List? ?? []) : []);
        final taken = busy.any((b) => widget.start! < (b['end_min'] as int) && widget.end! > (b['start_min'] as int));
        final small = widget.guests != null && (room['capacity'] as int) < widget.guests!;
        avail[room['id'] as String] = small ? 'small' : (taken ? 'busy' : 'ok');
      }));
      const order = {'ok': 0, 'small': 1, 'busy': 2};
      list.sort((a, b) => order[avail[a['id']]]!.compareTo(order[avail[b['id']]]!));
    }
    if (!mounted) return;
    setState(() {
      rooms = list;
      loading = false;
    });
  }

  Widget _chip(Map<String, dynamic> r) {
    if (filtered) {
      switch (avail[r['id']]) {
        case 'ok':
          return const StatusChip('Available', 'good');
        case 'small':
          return const StatusChip('Too small', 'warn');
        default:
          return const StatusChip('Booked then', 'bad');
      }
    }
    switch (r['status']) {
      case 'free':
        return const StatusChip('Free today', 'good');
      case 'partial':
        return const StatusChip('Partly booked', 'warn');
      default:
        return const StatusChip('Fully booked', 'bad');
    }
  }

  Widget _roomCard(Map<String, dynamic> r, int i) {
    final g = gradFor(widget.code);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RoomPage(
          roomId: r['id'].toString(),
          date: widget.date,
          start: avail[r['id']] == 'ok' ? widget.start : null,
          end: avail[r['id']] == 'ok' ? widget.end : null,
        ),
      )),
      child: Container(
        decoration: cardDeco(),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Icon(kindIcon(r['kind'].toString()), color: Colors.white, size: 44),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${r['kind']} · capacity ${r['capacity']}', style: const TextStyle(fontSize: 12, color: C.mut)),
              const SizedBox(height: 10),
              _chip(r),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shell(
      child: PageBody(children: [
        const Crumb('Back'),
        HeaderBanner(
          code: widget.code,
          icon: buildingIcon(widget.code),
          title: '${buildingLabel(widget.code)} rooms and facilities',
          subtitle: loading ? 'Loading…' : '${rooms.length} rooms & facilities · pick one to see its calendar',
        ),
        const SizedBox(height: 16),
        if (loading)
          const Loading()
        else if (error != null)
          Alert(error!, 'bad')
        else
          RGrid(minW: 230, children: [for (var i = 0; i < rooms.length; i++) _roomCard(rooms[i], i)]),
      ]),
    );
  }
}

/* ───────────────────────── room calendar + slots ───────────────────────── */

class RoomPage extends StatefulWidget {
  final String roomId;
  final DateTime? date;
  final int? start;
  final int? end;
  const RoomPage({super.key, required this.roomId, this.date, this.start, this.end});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  Map<String, dynamic>? room;
  Color get accent => accentFor((room?['code'] ?? '').toString());
  late DateTime month;
  Map<String, dynamic> status = {};
  String? pickDate;
  int? start;
  int? end;
  List<List<int>> busy = [];
  bool loadingDay = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final d = widget.date ?? DateTime.now();
    month = DateTime(d.year, d.month, 1);
    if (widget.date != null) pickDate = iso(widget.date!);
    start = widget.start;
    end = widget.end;
    _init();
  }

  Future<void> _init() async {
    final r = await Api.call('GET', '/rooms/${widget.roomId}');
    if (!mounted) return;
    if (!r.ok) {
      setState(() => error = r.error);
      return;
    }
    setState(() => room = Map<String, dynamic>.from(r.data));
    await _loadCal();
    if (pickDate != null) await _loadDay();
  }

  Future<void> _loadCal() async {
    final m = '${month.year}-${pad(month.month)}';
    final r = await Api.call('GET', '/rooms/${widget.roomId}/calendar?month=$m');
    if (!mounted) return;
    setState(() => status = r.data is Map ? Map<String, dynamic>.from(r.data) : {});
  }

  Future<void> _loadDay() async {
    if (pickDate == null) return;
    setState(() => loadingDay = true);
    final r = await Api.call('GET', '/rooms/${widget.roomId}/day?date=$pickDate');
    if (!mounted) return;
    final list = <List<int>>[];
    if (r.data is Map) {
      for (final b in (r.data['busy'] as List)) {
        list.add([b['start_min'] as int, b['end_min'] as int]);
      }
    }
    setState(() {
      busy = list;
      loadingDay = false;
      if (start != null && end != null && _rangeBusy(start!, end!)) {
        start = null;
        end = null;
      }
    });
  }

  bool _rangeBusy(int a, int b) => busy.any((x) => a < x[1] && b > x[0]);
  bool _slotBusy(int s) => _rangeBusy(s, s + kStep);

  void _shiftMonth(int n) {
    setState(() => month = DateTime(month.year, month.month + n, 1));
    _loadCal();
  }

  void _pickDay(String ds) {
    setState(() {
      pickDate = ds;
      start = null;
      end = null;
    });
    _loadDay();
  }

  void _tapSlot(int s) {
    setState(() {
      if (start == null || end != null || s < start!) {
        start = s;
        end = null;
      } else if (_rangeBusy(start!, s + kStep)) {
        start = s;
        end = null;
      } else {
        end = s + kStep;
      }
    });
  }

  Widget _cell(int d, String today) {
    final ds = '${month.year}-${pad(month.month)}-${pad(d)}';
    final st = status[ds] as Map<String, dynamic>?;
    final state = st?['state'];
    final past = ds.compareTo(today) < 0;
    final full = state == 'full';
    final sel = ds == pickDate;
    final isToday = ds == today;
    final bg = sel ? accent : full ? C.busy : state == 'partial' ? C.pend : Colors.white;
    return Opacity(
      opacity: past ? .4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: (past || full) ? null : () => _pickDay(ds),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isToday ? accent : C.line, width: isToday ? 2 : 1),
          ),
          child: Text('$d',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : full ? C.busyInk : C.ink)),
        ),
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3), border: Border.all(color: C.line)),
        ),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontSize: 12, color: C.mut)),
      ]);

  Widget _calendarPanel() {
    final today = iso(DateTime.now());
    final offset = month.weekday % 7; // Sunday first
    final days = DateTime(month.year, month.month + 1, 0).day;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton.outlined(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
          Text('${_months[month.month - 1]} ${month.year}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          IconButton.outlined(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.05,
          children: [
            for (final w in const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
              Center(child: Text(w, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.mut))),
            for (var i = 0; i < offset; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++) _cell(d, today),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 6, children: [
          _legend(Colors.white, 'Available'),
          _legend(C.pend, 'Partly booked'),
          _legend(C.busy, 'Fully booked'),
          _legend(accent, 'Selected'),
        ]),
      ]),
    );
  }

  Widget _slotsPanel() {
    final ready = start != null && end != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(),
      child: pickDate == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Pick a day to see the time slots.', style: TextStyle(color: C.mut))),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(longDate(pickDate!), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Tap a start time, then tap the last slot you need.',
                  style: TextStyle(fontSize: 12, color: C.mut)),
              const SizedBox(height: 12),
              if (loadingDay)
                const Loading()
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.1,
                  children: [
                    for (var s = kOpen; s < kClose; s += kStep) _slot(s),
                  ],
                ),
              if (ready) Alert('${fmt(start!)} – ${fmt(end!)}', 'good'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Btn('Book now',
                    icon: Icons.event_available_rounded,
                    onTap: ready
                        ? () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => BookingFormPage(room: room!, date: pickDate!, start: start!, end: end!),
                            ))
                        : null),
              ),
            ]),
    );
  }

  Widget _slot(int s) {
    final b = _slotBusy(s);
    final sel = start != null && s >= start! && s < (end ?? start! + kStep);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: b ? null : () => _tapSlot(s),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? accent : b ? C.busy : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? accent : b ? C.busy : C.line),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(fmt(s),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : b ? C.busyInk : C.ink)),
          if (b) const Text('booked', style: TextStyle(fontSize: 10, color: C.busyInk)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Shell(
      child: PageBody(children: [
        const Crumb('Back to rooms'),
        if (error != null)
          Alert(error!, 'bad')
        else if (room == null)
          const Loading()
        else ...[
          HeaderBanner(
            code: (room!['code'] ?? '').toString(),
            icon: kindIcon(room!['kind'].toString()),
            title: room!['name'].toString(),
            subtitle: '${room!['college']} · ${room!['kind']} · capacity ${room!['capacity']}',
          ),
          const SizedBox(height: 16),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _calendarPanel()),
              const SizedBox(width: 16),
              Expanded(child: _slotsPanel()),
            ])
          else ...[
            _calendarPanel(),
            const SizedBox(height: 16),
            _slotsPanel(),
          ],
        ],
      ]),
    );
  }
}

/* ───────────────────────── booking form + letter preview ───────────────────────── */

class BookingFormPage extends StatefulWidget {
  final Map<String, dynamic> room;
  final String date;
  final int start;
  final int end;
  const BookingFormPage({super.key, required this.room, required this.date, required this.start, required this.end});

  @override
  State<BookingFormPage> createState() => _BookingFormPageState();
}

class _BookingFormPageState extends State<BookingFormPage> {
  late Map<String, dynamic> room = widget.room;
  late int start = widget.start;
  late int end = widget.end;
  late final name = TextEditingController(text: (Api.user?['name'] ?? '').toString());
  final org = TextEditingController();
  final purpose = TextEditingController();
  final att = TextEditingController();
  String? error;
  Map<String, dynamic>? suggestions;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [name, org, purpose, att]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [name, org, purpose, att]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
      suggestions = null;
    });
    final r = await Api.call('POST', '/bookings', body: {
      'room_id': room['id'],
      'date': widget.date,
      'start_min': start,
      'end_min': end,
      'requester_name': name.text,
      'organization': org.text,
      'purpose': purpose.text,
      'attendees': int.tryParse(att.text.trim()) ?? 0,
    });
    if (!mounted) return;
    if (r.status == 201) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MyRequestsPage(justSent: true)),
        (route) => route.isFirst,
      );
      return;
    }
    setState(() {
      busy = false;
      if (r.status == 409 && r.data is Map) {
        suggestions = Map<String, dynamic>.from(r.data['suggestions'] ?? {});
      } else {
        error = r.error;
      }
    });
  }

  Future<void> _useRoom(String id) async {
    final r = await Api.call('GET', '/rooms/$id');
    if (!mounted || !r.ok) return;
    setState(() {
      room = Map<String, dynamic>.from(r.data);
      suggestions = null;
    });
  }

  InlineSpan _ph(String v, String p) => v.trim().isNotEmpty
      ? TextSpan(text: v.trim(), style: const TextStyle(fontWeight: FontWeight.w700))
      : TextSpan(
          text: '[$p]',
          style: const TextStyle(fontWeight: FontWeight.w700, backgroundColor: C.pend),
        );

  Widget _letter() {
    const b = TextStyle(fontWeight: FontWeight.w700);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.line),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontFamily: 'serif', fontSize: 13.5, height: 1.6, color: Colors.black),
          children: [
            TextSpan(text: '${todayLong()}\n\n'),
            TextSpan(text: '${room['addressee']}\nIloilo Science and Technology University\n\n'),
            const TextSpan(text: 'Dear Sir/Madam:\n\n'),
            const TextSpan(text: 'I respectfully request to use '),
            TextSpan(text: '${room['name']} (${room['college']})', style: b),
            const TextSpan(text: ' on '),
            TextSpan(text: '${longDate(widget.date)}, ${fmt(start)} – ${fmt(end)}', style: b),
            const TextSpan(text: ', for '),
            _ph(purpose.text, 'purpose'),
            const TextSpan(text: ', with approximately '),
            _ph(att.text, 'attendees'),
            const TextSpan(text: ' attendees, under '),
            _ph(org.text, 'organization'),
            const TextSpan(text: '.\n\nYour kind approval of this request will be highly appreciated. Thank you.\n\nRespectfully yours,\n\n'),
            _ph(name.text, 'full name'),
            const TextSpan(text: '\n'),
            _ph(org.text, 'organization'),
          ],
        ),
      ),
    );
  }

  Widget _suggestions() {
    final s = suggestions!;
    final same = s['sameRoom'] as Map<String, dynamic>?;
    final others = (s['otherRooms'] as List? ?? []).cast<Map<String, dynamic>>();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.pend, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Conflict blocked. ${fmt(start)} – ${fmt(end)} is already taken.',
            style: const TextStyle(color: C.pendInk, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 10),
        if (same != null)
          Btn('Use nearest free slot: ${fmt(same['start_min'] as int)} – ${fmt(same['end_min'] as int)}',
              small: true,
              onTap: () => setState(() {
                    start = same['start_min'] as int;
                    end = same['end_min'] as int;
                    suggestions = null;
                  }))
        else
          const Text('No other free slot of that length today in this room.',
              style: TextStyle(color: C.pendInk, fontSize: 13)),
        for (final o in others) ...[
          const SizedBox(height: 8),
          Btn('Same time in ${o['name']}', small: true, outlined: true, onTap: () => _useRoom(o['id'].toString())),
        ],
      ]),
    );
  }

  Widget _formPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name *')),
        const SizedBox(height: 12),
        TextField(controller: org, decoration: const InputDecoration(labelText: 'Organization / department *')),
        const SizedBox(height: 12),
        TextField(controller: purpose, decoration: const InputDecoration(labelText: 'Purpose of use *')),
        const SizedBox(height: 12),
        TextField(
          controller: att,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Number of attendees * (max ${room['capacity']})'),
        ),
        if (error != null) Alert(error!, 'bad'),
        if (suggestions != null) _suggestions(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Btn('Generate letter and submit', icon: Icons.send_rounded, onTap: _submit, busy: busy),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final preview = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('LETTER PREVIEW — fills in as you type',
            style: TextStyle(fontSize: 11, color: C.mut, fontWeight: FontWeight.w700, letterSpacing: .6)),
      ),
      _letter(),
    ]);
    return Shell(
      child: PageBody(children: [
        const Crumb('Back to calendar'),
        const Text('Complete your request', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        Alert('${room['name']} · ${room['college']} · ${longDate(widget.date)} · ${fmt(start)} – ${fmt(end)}', 'good'),
        const SizedBox(height: 8),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _formPanel()),
            const SizedBox(width: 16),
            Expanded(child: preview),
          ])
        else ...[
          _formPanel(),
          const SizedBox(height: 16),
          preview,
        ],
      ]),
    );
  }
}

/* ───────────────────────── my requests / admin ───────────────────────── */

class MyRequestsPage extends StatefulWidget {
  final bool admin;
  final bool justSent;
  const MyRequestsPage({super.key, this.admin = false, this.justSent = false});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.call('GET', widget.admin ? '/bookings' : '/bookings/mine');
    if (!mounted) return;
    setState(() {
      loading = false;
      if (r.ok) {
        list = List<Map<String, dynamic>>.from(r.data as List);
        error = null;
      } else {
        error = r.error;
      }
    });
  }

  Future<void> _decide(String id, String status) async {
    await Api.call('PATCH', '/bookings/$id', body: {'status': status});
    _load();
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset demo data'),
        content: const Text('Delete all bookings?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await Api.call('POST', '/demo/reset', body: {});
      _load();
    }
  }

  Widget _card(Map<String, dynamic> b) {
    final st = b['status'].toString();
    final kind = st == 'approved' ? 'good' : st == 'pending' ? 'warn' : 'bad';
    final id = b['id'].toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: accentFor((b['code'] ?? '').toString()).withAlpha(34), borderRadius: BorderRadius.circular(12)),
            child: Icon(kindIcon('Facility'), color: accentFor((b['code'] ?? '').toString())),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b['room_name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text('${b['college']}${widget.admin ? ' · ${b['requester_name']}' : ''}',
                  style: const TextStyle(color: C.mut, fontSize: 12.5)),
            ]),
          ),
          StatusChip(st, kind),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 15, color: C.mut),
          const SizedBox(width: 6),
          Text(shortDate(b['date'].toString()), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 14),
          const Icon(Icons.schedule_rounded, size: 15, color: C.mut),
          const SizedBox(width: 6),
          Text('${fmt(b['start_min'] as int)} – ${fmt(b['end_min'] as int)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (widget.admin && st == 'pending') ...[
            Btn('Approve', small: true, icon: Icons.check_rounded, onTap: () => _decide(id, 'approved')),
            Btn('Reject', small: true, outlined: true, icon: Icons.close_rounded, onTap: () => _decide(id, 'rejected')),
          ],
          Btn('Letter', small: true, outlined: true, icon: Icons.picture_as_pdf_outlined, onTap: () => Api.openLetter(id)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shell(
      active: widget.admin ? 'admin' : 'mine',
      child: PageBody(children: [
        Text(widget.admin ? 'All requests' : 'My requests',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (widget.justSent)
          const Alert('Request sent. The slot is held on the calendar while the approver reviews your letter.', 'good'),
        const SizedBox(height: 8),
        if (loading)
          const Loading()
        else if (error != null)
          Alert(error!, 'bad')
        else if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('Nothing here yet.', style: TextStyle(color: C.mut))),
          )
        else
          RGrid(minW: 340, children: [for (final b in list) _card(b)]),
        if (widget.admin) ...[
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerLeft, child: Btn('Reset demo data', small: true, outlined: true, onTap: _reset)),
        ],
      ]),
    );
  }
}
