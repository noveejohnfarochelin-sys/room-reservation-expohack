// UniSpace (ISATU) – Flutter UI in the "StayNest" style + Smart Conflict Resolver.
// FIREBASE VERSION: all data comes from Cloud Firestore through BookingModel, RoomModel,
// BookingAlgorithmService, FirestoreServer and SeedService. Letters can be downloaded as PDF.
// Demo logins: student/student, student2/student2, admin/admin (or use the 1-tap buttons).
// Tip: pick CCI > Room 101, choose today on the calendar, keep 10:00-11:00 and submit to see the smart conflict resolver.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

/* ───────────────────────── signatures ───────────────────────── */

/// Who still has to sign a request (deans / librarian / GSO head / president).
class SignatureChips extends StatelessWidget {
  final Map<String, dynamic> b;
  const SignatureChips(this.b, {super.key});

  @override
  Widget build(BuildContext context) {
    final req = List<String>.from(b['required_signatories'] ?? const <String>[]);
    final done = List<String>.from(b['approved_by'] ?? const <String>[]);
    if (req.isEmpty) return const SizedBox.shrink();
    final live = b['status'] == 'pending' || b['status'] == 'approved';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Required signatures', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.mut)),
      const SizedBox(height: 5),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in req)
          StatusChip(done.contains(s) ? '$s ✓' : (live ? '$s · waiting' : s), done.contains(s) ? 'good' : (live ? 'warn' : 'bad')),
      ]),
    ]);
  }
}

/* ───────────────────────── logo ───────────────────────── */

/// UniSpace logo: [full] = mark + wordmark + tagline, otherwise the U-door mark only.
class Logo extends StatelessWidget {
  final double height;
  final bool full;
  const Logo({super.key, this.height = 38, this.full = false});

  @override
  Widget build(BuildContext context) => Image.asset(
        full ? 'assets/images/unispace_logo.png' : 'assets/images/unispace_mark.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.apartment_rounded, color: C.blue, size: height),
      );
}

/* ───────────────────────── API (Firestore-backed) ───────────────────────── */

class Api {
  static String? token;
  static Map<String, dynamic>? user;
  static final navKey = GlobalKey<NavigatorState>();

  static bool get isAdmin => user?['role'] == 'admin'; // handles rooms & bookings, never signs
  static bool get isSignatory => user?['role'] == 'signatory'; // deans, librarian, GSO head, president
  static String get signatory => (user?['signatory'] ?? '').toString();

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

  static String _ref(String id) => 'US-${(id.length > 8 ? id.substring(0, 8) : id).toUpperCase()}';

  static String _time(Map<String, dynamic> b) => '${fmt(b['start_min'])} – ${fmt(b['end_min'])}';

  /// Builds the request letter as an A4 PDF and either saves it or opens the print dialog.
  static Future<void> _letterPdf(Map<String, dynamic> b, String id, {required bool print}) async {
    // The built-in PDF fonts have no en dash, so the PDF uses a plain hyphen.
    String t(String v) => v.replaceAll('–', '-');
    final regular = pw.Font.times();
    final bold = pw.Font.timesBold();
    final base = pw.TextStyle(font: regular, fontSize: 12, lineSpacing: 4);
    final strong = pw.TextStyle(font: bold, fontSize: 12, lineSpacing: 4);

    pw.MemoryImage? mark;
    try {
      final d = await rootBundle.load('assets/images/unispace_mark.png');
      mark = pw.MemoryImage(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
    } catch (_) {}

    final doc = pw.Document(title: 'Request letter ${_ref(id)}', author: 'UniSpace');
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(64, 64, 64, 64),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          if (mark != null) pw.Image(mark!, height: 34),
          if (mark != null) pw.SizedBox(width: 8),
          pw.Text('UniSpace', style: pw.TextStyle(font: bold, fontSize: 16)),
          pw.Spacer(),
          pw.Text('Reference: ${_ref(id)}', style: base),
        ]),
        pw.Divider(thickness: 0.6),
        pw.SizedBox(height: 10),
        pw.SizedBox(height: 18),
        pw.Text(todayLong(), style: base),
        pw.SizedBox(height: 18),
        pw.Text('${b['addressee']}', style: strong),
        pw.Text('Iloilo Science and Technology University', style: base),
        pw.SizedBox(height: 18),
        pw.Text('Dear Sir/Madam:', style: base),
        pw.SizedBox(height: 14),
        pw.RichText(
          text: pw.TextSpan(style: base, children: [
            const pw.TextSpan(text: 'I respectfully request to use '),
            pw.TextSpan(text: t('${b['room_name']} (${b['college']})'), style: strong),
            const pw.TextSpan(text: ' on '),
            pw.TextSpan(text: t('${longDate(b['date'])}, ${_time(b)}'), style: strong),
            pw.TextSpan(
                text: t(', for ${b['purpose']}, with approximately ${b['attendees']} attendees, '
                    'under ${b['organization']}.')),
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.Text('Your kind approval of this request will be highly appreciated. Thank you.', style: base),
        pw.SizedBox(height: 22),
        pw.Text('Respectfully yours,', style: base),
        pw.SizedBox(height: 36),
        pw.Text(t('${b['requester_name']}'), style: strong),
        pw.Text(t('${b['organization']}'), style: base),
      ]),
    ));

    if (print) {
      await Printing.layoutPdf(name: 'UniSpace-${_ref(id)}.pdf', onLayout: (_) => doc.save());
    } else {
      await Printing.sharePdf(bytes: await doc.save(), filename: 'UniSpace-${_ref(id)}.pdf');
    }
  }

  static Future<void> openLetter(String id) async {
    final b = await FirestoreServer.bookingById(id);
    final ctx = navKey.currentContext;
    if (b == null || ctx == null || !ctx.mounted) return;
    final text = 'Reference: ${_ref(id)}\n\n'
        '${todayLong()}\n\n'
        '${b['addressee']}\nIloilo Science and Technology University\n\n'
        'Dear Sir/Madam:\n\n'
        'I respectfully request to use ${b['room_name']} (${b['college']}) on '
        '${longDate(b['date'])}, ${_time(b)}, for ${b['purpose']}, '
        'with approximately ${b['attendees']} attendees, under ${b['organization']}.\n\n'
        'Your kind approval of this request will be highly appreciated. Thank you.\n\n'
        'Respectfully yours,\n\n${b['requester_name']}\n${b['organization']}';
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Official Request Letter'),
        content: SingleChildScrollView(
          child: Text(text, style: const TextStyle(fontFamily: 'serif', height: 1.55, fontSize: 13.5)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
          TextButton.icon(
            onPressed: () => _letterPdf(b, id, print: true),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print'),
          ),
          FilledButton.icon(
            onPressed: () => _letterPdf(b, id, print: false),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── app ───────────────────────── */

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    debugPrint('SeedService: ${await SeedService().seedInitialData()}');
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

void goAdmin(BuildContext c) => Navigator.of(c).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminPage()),
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
    final fullName = (Api.user?['name'] ?? 'Guest').toString();
    final name = Api.isSignatory ? fullName : fullName.split(' ').first;

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
                      const Logo(height: 38),
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
                    if (Api.isAdmin || Api.isSignatory)
                      navItem('admin', Api.isAdmin ? 'Admin Console' : 'Approvals', () => goAdmin(context))
                    else
                      navItem('mine', 'My Requests', () => goMine(context)),
                    const SizedBox(width: 16),
                  ],
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'home') goHome(context);
                      if (v == 'mine') goMine(context);
                      if (v == 'admin') goAdmin(context);
                      if (v == 'out') Api.logout();
                    },
                    itemBuilder: (_) => [
                      if (!wide) const PopupMenuItem(value: 'home', child: Text('Home')),
                      if (!wide && !Api.isAdmin && !Api.isSignatory) const PopupMenuItem(value: 'mine', child: Text('My Requests')),
                      if (!wide && (Api.isAdmin || Api.isSignatory))
                        PopupMenuItem(value: 'admin', child: Text(Api.isAdmin ? 'Admin Console' : 'Approvals')),
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

  Future<void> _login([String? preset]) async {
    if (preset != null) {
      user.text = preset;
      pass.text = preset;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final r = await Api.call('POST', '/login', body: {'username': user.text.trim(), 'password': pass.text.trim()});
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
    if (Api.isAdmin || Api.isSignatory) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminPage()),
        (route) => false,
      );
    } else {
      goHome(context);
    }
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
                  const Center(child: Logo(height: 160, full: true)),
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
                  const SizedBox(height: 16),
                  const Text('Quick demo accounts (1-tap sign in) · other usernames: coe_dean, cit_dean, cgbe_dean · password = username',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.mut)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Btn('Student 1', small: true, outlined: true, onTap: () => _login('student')),
                    Btn('Student 2', small: true, outlined: true, onTap: () => _login('student2')),
                    Btn('Room Admin', small: true, outlined: true, onTap: () => _login('admin')),
                    Btn('CCI Dean', small: true, outlined: true, onTap: () => _login('cci_dean')),
                    Btn('CEA Dean', small: true, outlined: true, onTap: () => _login('cea_dean')),
                    Btn('Librarian', small: true, outlined: true, onTap: () => _login('librarian')),
                    Btn('GSO Head', small: true, outlined: true, onTap: () => _login('gso')),
                    Btn('President', small: true, outlined: true, onTap: () => _login('president')),
                  ]),
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
              Text('Open ${fmt(kOpen)} – ${fmt(kClose)}',
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
          child: Row(children: [
            const Icon(Icons.school_rounded, color: C.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Iloilo Science and Technology University · 30-minute slots · ${fmt(kOpen)} – ${fmt(kClose)}',
                  style: const TextStyle(fontSize: 12.5, color: C.mut, fontWeight: FontWeight.w600)),
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

/* ───────────────────────── room: calendar + schedule + booking form + letter ───────────────────────── */

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
  late String roomId = widget.roomId;
  Map<String, dynamic>? room;
  Color get accent => accentFor((room?['code'] ?? '').toString());
  late DateTime month;
  Map<String, dynamic> status = {};
  String? pickDate;
  late int start = widget.start ?? 9 * 60;
  late int end = widget.end ?? (widget.start ?? 9 * 60) + 60;
  List<Map<String, dynamic>> busyList = [];
  List<List<int>> freeList = [];
  bool loadingDay = false;
  String? error;

  Map<String, dynamic>? suggestions;
  String? formError;
  bool submitting = false;
  bool fromSuggestion = false;

  late final name = TextEditingController(text: (Api.user?['name'] ?? '').toString());
  final org = TextEditingController(text: 'ISATU Student Organization');
  final purpose = TextEditingController(text: 'Club Assembly & Planning');
  final att = TextEditingController(text: '25');

  @override
  void initState() {
    super.initState();
    final d = widget.date ?? DateTime.now();
    month = DateTime(d.year, d.month, 1);
    if (widget.date != null) pickDate = iso(widget.date!);
    for (final c in [name, org, purpose, att]) {
      c.addListener(() => setState(() {}));
    }
    _init();
  }

  @override
  void dispose() {
    for (final c in [name, org, purpose, att]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    final r = await Api.call('GET', '/rooms/$roomId');
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
    final r = await Api.call('GET', '/rooms/$roomId/calendar?month=$m');
    if (!mounted) return;
    setState(() => status = r.data is Map ? Map<String, dynamic>.from(r.data) : {});
  }

  Future<void> _loadDay() async {
    if (pickDate == null) return;
    setState(() => loadingDay = true);
    final r = await Api.call('GET', '/rooms/$roomId/day?date=$pickDate');
    if (!mounted) return;
    setState(() {
      loadingDay = false;
      if (r.data is Map) {
        busyList = List<Map<String, dynamic>>.from((r.data['busy'] as List).map((e) => Map<String, dynamic>.from(e)));
        freeList = [for (final w in (r.data['free'] as List)) [w[0] as int, w[1] as int]];
      }
    });
  }

  void _shiftMonth(int n) {
    setState(() => month = DateTime(month.year, month.month + n, 1));
    _loadCal();
  }

  void _pickDay(String ds) {
    setState(() {
      pickDate = ds;
      suggestions = null;
      formError = null;
    });
    _loadDay();
  }

  Future<void> _submit() async {
    if (pickDate == null) return;
    setState(() {
      submitting = true;
      formError = null;
      suggestions = null;
    });
    final r = await Api.call('POST', '/bookings', body: {
      'room_id': room!['id'],
      'date': pickDate,
      'start_min': start,
      'end_min': end,
      'requester_name': name.text,
      'organization': org.text,
      'purpose': purpose.text,
      'attendees': int.tryParse(att.text.trim()) ?? 0,
      'from_suggestion': fromSuggestion,
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
      submitting = false;
      fromSuggestion = false;
      formError = r.error;
      if (r.status == 409 && r.data is Map) {
        suggestions = Map<String, dynamic>.from(r.data['suggestions'] ?? {});
      }
    });
  }

  void _applyTime(int s, int e) {
    setState(() {
      start = s;
      end = e;
      fromSuggestion = true;
      formError = null;
      suggestions = null;
    });
    _submit();
  }

  Future<void> _applyRoom(String id) async {
    final r = await Api.call('GET', '/rooms/$id');
    if (!mounted || !r.ok) return;
    setState(() {
      room = Map<String, dynamic>.from(r.data);
      roomId = id;
      fromSuggestion = true;
      formError = null;
      suggestions = null;
    });
    await _loadCal();
    await _loadDay();
    _submit();
  }

  /* ── calendar ── */

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

  /* ── schedule (open windows + booked / pending events) ── */

  Widget _schedulePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Schedule · ${shortDate(pickDate!)}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: C.navy)),
        const SizedBox(height: 10),
        if (loadingDay)
          const Loading()
        else ...[
          const Text('Open Windows:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.mut)),
          const SizedBox(height: 6),
          if (freeList.isEmpty)
            const StatusChip('No free windows on this date', 'bad')
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final w in freeList)
                ActionChip(
                  backgroundColor: C.free,
                  side: BorderSide.none,
                  label: Text('${fmt(w[0])} – ${fmt(w[1])}',
                      style: const TextStyle(color: C.freeInk, fontWeight: FontWeight.w700, fontSize: 12)),
                  onPressed: () => setState(() {
                    start = w[0];
                    end = (w[0] + 60 <= w[1]) ? w[0] + 60 : w[1];
                    formError = null;
                    suggestions = null;
                  }),
                ),
            ]),
          const SizedBox(height: 12),
          const Text('Occupied / Pending Slots:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.mut)),
          const SizedBox(height: 6),
          if (busyList.isEmpty)
            const Text('No events booked for this day yet.', style: TextStyle(fontSize: 12.5, color: C.mut))
          else
            for (final b in busyList)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  StatusChip(b['status'] == 'approved' ? 'Approved' : 'Pending',
                      b['status'] == 'approved' ? 'bad' : 'warn'),
                  const SizedBox(width: 8),
                  Text('${fmt(b['start_min'] as int)} – ${fmt(b['end_min'] as int)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('(${b['purpose']})',
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.mut, fontSize: 12.5)),
                  ),
                ]),
              ),
        ],
      ]),
    );
  }

  /* ── smart conflict resolver ── */

  Widget _suggestionsPanel() {
    final s = suggestions!;
    final same = s['sameRoom'] as Map<String, dynamic>?;
    final blocked = s['blockedBy'] as Map<String, dynamic>?;
    final others = (s['otherRooms'] as List? ?? []).cast<Map<String, dynamic>>();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.blue, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome_rounded, color: C.blue, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text('Smart Conflict Resolver (1-Tap Fix)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.navy)),
          ),
        ]),
        if (blocked != null) ...[
          const SizedBox(height: 6),
          Text(
            'Blocked by ${blocked['status']} booking '
            '(${fmt(blocked['start_min'] as int)} – ${fmt(blocked['end_min'] as int)}: ${blocked['purpose']}).',
            style: const TextStyle(fontSize: 12.5, color: C.mut),
          ),
        ],
        const SizedBox(height: 12),
        if (same != null) ...[
          const Text('Nearest free time in this room:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ActionChip(
            avatar: const Icon(Icons.schedule_rounded, size: 16, color: C.blue),
            backgroundColor: C.tint,
            side: BorderSide.none,
            label: Text('Book ${fmt(same['start_min'] as int)} – ${fmt(same['end_min'] as int)} here',
                style: const TextStyle(fontWeight: FontWeight.w800, color: C.blue)),
            onPressed: () => _applyTime(same['start_min'] as int, same['end_min'] as int),
          ),
          const SizedBox(height: 10),
        ],
        if (others.isNotEmpty) ...[
          const Text('Capacity-ranked rooms free at your exact time:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in others)
              ActionChip(
                avatar: const Icon(Icons.meeting_room_rounded, size: 16, color: C.freeInk),
                backgroundColor: C.free,
                side: BorderSide.none,
                label: Text('${o['name']} (${o['fit_label']})',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: C.freeInk, fontSize: 12.5)),
                onPressed: () => _applyRoom(o['id'].toString()),
              ),
          ]),
        ] else if (same == null)
          const Text('No rooms in this college fit your attendee count at this slot. Try another date.',
              style: TextStyle(fontSize: 12.5, color: C.mut)),
      ]),
    );
  }

  /* ── request reservation form ── */

  Widget _formPanel() {
    final times = <int>[for (var t = kOpen; t <= kClose; t += kStep) t];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Request Reservation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.navy)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: start,
              decoration: const InputDecoration(labelText: 'Start Time'),
              items: [for (final t in times.where((t) => t < kClose)) DropdownMenuItem(value: t, child: Text(fmt(t)))],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    start = v;
                    if (end <= start) end = start + kStep;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: end,
              decoration: const InputDecoration(labelText: 'End Time'),
              items: [for (final t in times.where((t) => t > start)) DropdownMenuItem(value: t, child: Text(fmt(t)))],
              onChanged: (v) {
                if (v != null) setState(() => end = v);
              },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Requester Full Name')),
        const SizedBox(height: 12),
        TextField(controller: org, decoration: const InputDecoration(labelText: 'College / Student Organization')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 2,
            child: TextField(controller: purpose, decoration: const InputDecoration(labelText: 'Activity / Purpose')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: att,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Attendees'),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        if (formError != null) Alert(formError!, 'bad'),
        if (suggestions != null) _suggestionsPanel(),
        const SizedBox(height: 12),
        Btn('Submit Booking Request',
            icon: Icons.check_circle_outline_rounded, busy: submitting, onTap: _submit),
      ]),
    );
  }

  /* ── letter preview (fills in as you type) ── */

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
            TextSpan(text: '${room!['addressee']}\nIloilo Science and Technology University\n\n'),
            const TextSpan(text: 'Dear Sir/Madam:\n\n'),
            const TextSpan(text: 'I respectfully request to use '),
            TextSpan(text: '${room!['name']} (${room!['college']})', style: b),
            const TextSpan(text: ' on '),
            TextSpan(text: '${longDate(pickDate!)}, ${fmt(start)} – ${fmt(end)}', style: b),
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

  Widget _letterSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('LETTER PREVIEW — fills in as you type',
              style: TextStyle(fontSize: 11, color: C.mut, fontWeight: FontWeight.w700, letterSpacing: .6)),
        ),
        _letter(),
      ]);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final right = pickDate == null
        ? Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            decoration: cardDeco(),
            child: const Center(
              child: Text('Pick a day on the calendar to see what is booked and to request this room.',
                  textAlign: TextAlign.center, style: TextStyle(color: C.mut)),
            ),
          )
        : Column(children: [_schedulePanel(), const SizedBox(height: 16), _formPanel()]);
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
            subtitle: '${room!['college']} · ${room!['kind']} · Capacity: ${room!['capacity']} people',
          ),
          const SizedBox(height: 16),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _calendarPanel()),
              const SizedBox(width: 16),
              Expanded(child: right),
            ])
          else ...[
            _calendarPanel(),
            const SizedBox(height: 16),
            right,
          ],
          if (pickDate != null) ...[const SizedBox(height: 16), _letterSection()],
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
    final nearCap = b['near_capacity'] == true;
    final contention = b['has_contention'] == true;
    final ac = accentFor((b['code'] ?? '').toString());
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(ac.withAlpha(16), Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ac.withAlpha(90)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 7, color: ac),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                  style: TextStyle(color: ac, fontWeight: FontWeight.w700, fontSize: 12.5)),
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
        const SizedBox(height: 10),
        Text(
          '${b['purpose']} · ${b['organization']} (${b['requester_name']}) · '
          '${b['attendees']}/${b['room_capacity']} pax',
          style: const TextStyle(fontSize: 12.5, color: C.mut),
        ),
        const SizedBox(height: 10),
        SignatureChips(b),
        if (widget.admin && (nearCap || contention)) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (nearCap) const StatusChip('Near Capacity (>=85%)', 'warn'),
            if (contention) const StatusChip('Slot Contention Alert', 'bad'),
          ]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Btn('Letter', small: true, outlined: true, icon: Icons.picture_as_pdf_outlined, onTap: () => Api.openLetter(id)),
        ]),
      ]),
            ),
          ),
        ]),
      ),
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
          Column(children: [for (final b in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: _card(b))]),
        if (widget.admin) ...[
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerLeft, child: Btn('Reset demo data', small: true, outlined: true, onTap: _reset)),
        ],
      ]),
    );
  }
}

/* ───────────────────────── admin console ───────────────────────── */

String bldName(String code) {
  switch (code) {
    case 'MEC':
      return 'Gym';
    case 'GRAND':
      return 'Grandstand';
    default:
      return buildingLabel(code);
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Map<String, dynamic>> all = [];
  Map<String, dynamic>? stats;
  bool loading = true;
  String? error;
  String tab = 'pending';
  String bld = 'ALL';
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? pickDay;
  final search = TextEditingController();

  static const _codes = ['ALL', 'CEA', 'CCI', 'COE', 'CIT', 'CGBE', 'LIB', 'MEC', 'GRAND'];

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rs = await Future.wait([Api.call('GET', '/bookings'), Api.call('GET', '/stats')]);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (rs[0].ok) {
        all = List<Map<String, dynamic>>.from(rs[0].data as List);
        error = null;
      } else {
        error = rs[0].error;
      }
      stats = rs[1].ok ? Map<String, dynamic>.from(rs[1].data as Map) : null;
    });
  }

  int _count(String st) => st == 'all' ? all.length : all.where((b) => b['status'] == st).length;

  List<Map<String, dynamic>> get _filtered {
    final q = search.text.trim().toLowerCase();
    return all.where((b) {
      if (tab != 'all' && b['status'] != tab) return false;
      if (bld != 'ALL' && b['code'] != bld) return false;
      if (pickDay != null && b['date'] != pickDay) return false;
      if (q.isEmpty) return true;
      final hay = '${b['requester_name']} ${b['purpose']} ${b['room_name']} ${b['organization']}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  bool _iSigned(Map<String, dynamic> b) => List<String>.from(b['approved_by'] ?? const <String>[]).contains(Api.signatory);

  int get _awaitingMe => all.where((b) => b['status'] == 'pending' && !_iSigned(b)).length;

  Future<void> _decide(Map<String, dynamic> b, String status) async {
    if (status == 'cancelled') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Cancel booking'),
          content: Text('Cancel ${b['room_name']} on ${shortDate(b['date'].toString())} and free the slot?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel booking')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (status == 'approved' && b['has_contention'] == true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Slot contention'),
          content: const Text('Another pending or approved request overlaps this slot. Approve anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Approve anyway')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final r = await Api.call('PATCH', '/bookings/${b['id']}', body: {'status': status});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.ok ? 'Request ${Api._ref(b['id'].toString())} marked $status.' : r.error)),
    );
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

  Map<String, List<Map<String, dynamic>>> _byDay() {
    final m = '${month.year}-${pad(month.month)}-';
    final out = <String, List<Map<String, dynamic>>>{};
    for (final bk in all) {
      if (bk['status'] == 'rejected') continue;
      if (bld != 'ALL' && bk['code'] != bld) continue;
      final d = bk['date'].toString();
      if (!d.startsWith(m)) continue;
      out.putIfAbsent(d, () => []).add(bk);
    }
    for (final l in out.values) {
      l.sort((x, y) => (x['start_min'] as int).compareTo(y['start_min'] as int));
    }
    return out;
  }

  Widget _calChip(Map<String, dynamic> b) {
    final ac = accentFor((b['code'] ?? '').toString());
    final appr = b['status'] == 'approved';
    final onSolid = ac.computeLuminance() > .4 ? C.ink : Colors.white;
    final t = fmt(b['start_min'] as int).replaceAll(':00', '');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: appr ? ac : ac.withAlpha(30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: ac),
      ),
      child: Text('$t ${b['room_name']}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: appr ? onSolid : C.ink)),
    );
  }

  Widget _calLegend(Widget swatch, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        swatch,
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontSize: 12, color: C.mut)),
      ]);

  Widget _calendar(bool big) {
    final today = iso(DateTime.now());
    final byDay = _byDay();
    final offset = month.weekday % 7; // Sunday first
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + days) / 7).ceil();
    final cellH = big ? 118.0 : 64.0;

    Widget cell(int idx) {
      final d = idx - offset + 1;
      if (d < 1 || d > days) return const SizedBox.shrink();
      final ds = '${month.year}-${pad(month.month)}-${pad(d)}';
      final items = byDay[ds] ?? const <Map<String, dynamic>>[];
      final sel = ds == pickDay;
      final isToday = ds == today;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          pickDay = sel ? null : ds;
          if (pickDay != null) tab = 'all';
        }),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: sel ? C.tint : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (sel || isToday) ? C.blue : C.line, width: (sel || isToday) ? 1.8 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('$d',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: isToday ? C.blue : C.ink)),
              const Spacer(),
              if (!big && items.isNotEmpty)
                Text('${items.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: C.mut)),
            ]),
            const SizedBox(height: 3),
            if (big) ...[
              for (final b in items.take(3)) _calChip(b),
              if (items.length > 3)
                Text('+${items.length - 3} more',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.mut)),
            ] else
              Wrap(spacing: 3, runSpacing: 3, children: [
                for (final b in items.take(6))
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentFor((b['code'] ?? '').toString()),
                    ),
                  ),
              ]),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_month_rounded, color: C.blue, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Booking calendar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ),
          IconButton.outlined(
            onPressed: () => setState(() => month = DateTime(month.year, month.month - 1, 1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('${_months[month.month - 1]} ${month.year}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          IconButton.outlined(
            onPressed: () => setState(() => month = DateTime(month.year, month.month + 1, 1)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (final w in const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
            Expanded(
              child: Center(
                child: Text(w, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.mut)),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SizedBox(
              height: cellH,
              child: Row(children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: cell(r * 7 + c))),
              ]),
            ),
          ),
        const SizedBox(height: 6),
        Wrap(spacing: 16, runSpacing: 6, children: [
          _calLegend(
              Container(
                width: 14,
                height: 10,
                decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(3)),
              ),
              'Approved'),
          _calLegend(
              Container(
                width: 14,
                height: 10,
                decoration: BoxDecoration(
                  color: C.blue.withAlpha(30),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: C.blue),
                ),
              ),
              'Pending'),
          const Text('Colors = building · tap a day to filter the list below',
              style: TextStyle(fontSize: 12, color: C.mut)),
        ]),
      ]),
    );
  }

  Widget _filters() {
    const tabs = [
      ['pending', 'Pending'],
      ['approved', 'Approved'],
      ['rejected', 'Rejected'],
      ['all', 'All'],
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: search,
          decoration: const InputDecoration(
            hintText: 'Search requester, room, purpose or organization…',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in tabs)
            ChoiceChip(
              label: Text('${t[1]} · ${_count(t[0])}', style: const TextStyle(fontWeight: FontWeight.w700)),
              selected: tab == t[0],
              selectedColor: C.tint,
              onSelected: (_) => setState(() => tab = t[0]),
            ),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final code in _codes)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: code == 'ALL' ? null : Icon(Icons.circle, size: 10, color: accentFor(code)),
                  label: Text(code == 'ALL' ? 'All buildings' : bldName(code),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  selected: bld == code,
                  selectedColor: code == 'ALL' ? C.tint : accentFor(code).withAlpha(40),
                  onSelected: (_) => setState(() => bld = code),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> b) {
    final st = b['status'].toString();
    final kind = st == 'approved' ? 'good' : st == 'pending' ? 'warn' : 'bad';
    final code = (b['code'] ?? '').toString();
    final ac = accentFor(code);
    final att = (b['attendees'] as int?) ?? 0;
    final cap = (b['room_capacity'] as int?) ?? 1;
    final ratio = cap == 0 ? 0.0 : (att / cap).clamp(0.0, 1.0).toDouble();
    final nearCap = b['near_capacity'] == true;
    final contention = b['has_contention'] == true;
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(ac.withAlpha(16), Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ac.withAlpha(90)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 7, color: ac),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: ac.withAlpha(34), borderRadius: BorderRadius.circular(12)),
                    child: Icon(buildingIcon(code), color: ac),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b['room_name'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('${bldName(code)} · ${b['requester_name']}',
                          style: TextStyle(color: ac, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ]),
                  ),
                  StatusChip(st, kind),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 14, runSpacing: 4, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_today_rounded, size: 15, color: C.mut),
                    const SizedBox(width: 6),
                    Text(shortDate(b['date'].toString()),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.schedule_rounded, size: 15, color: C.mut),
                    const SizedBox(width: 6),
                    Text('${fmt(b['start_min'] as int)} – ${fmt(b['end_min'] as int)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ]),
                const SizedBox(height: 8),
                Text('${b['purpose']} · ${b['organization']}',
                    style: const TextStyle(fontSize: 12.5, color: C.mut)),
                const SizedBox(height: 10),
                Row(children: [
                  Text('$att / $cap people', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: C.line,
                        color: nearCap ? C.busyInk : ac,
                      ),
                    ),
                  ),
                ]),
                if (nearCap || contention) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (nearCap) const StatusChip('Near Capacity (>=85%)', 'warn'),
                    if (contention) const StatusChip('Slot Contention Alert', 'bad'),
                  ]),
                ],
                const SizedBox(height: 10),
                SignatureChips(b),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (Api.isSignatory) ...[
                    if (st == 'pending' && !_iSigned(b)) ...[
                      Btn('Approve', small: true, icon: Icons.check_rounded, onTap: () => _decide(b, 'approved')),
                      Btn('Reject',
                          small: true, outlined: true, icon: Icons.close_rounded, onTap: () => _decide(b, 'rejected')),
                    ] else if (st == 'approved' || st == 'rejected' || (st == 'pending' && _iSigned(b)))
                      Btn('Undo my decision',
                          small: true, outlined: true, icon: Icons.undo_rounded, onTap: () => _decide(b, 'pending')),
                  ] else if (Api.isAdmin && (st == 'pending' || st == 'approved'))
                    Btn('Cancel booking',
                        small: true, outlined: true, icon: Icons.event_busy_rounded, onTap: () => _decide(b, 'cancelled')),
                  Btn('Letter',
                      small: true,
                      outlined: true,
                      icon: Icons.description_outlined,
                      onTap: () => Api.openLetter(b['id'].toString())),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _todayCard() {
    final today = iso(DateTime.now());
    final items = all.where((b) => b['date'] == today && b['status'] == 'approved').toList()
      ..sort((a, b) => (a['start_min'] as int).compareTo(b['start_min'] as int));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.today_rounded, color: C.blue, size: 20),
          SizedBox(width: 8),
          Text('Approved today', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Text('Nothing approved for today yet.', style: TextStyle(fontSize: 12.5, color: C.mut))
        else
          for (final b in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.circle, size: 10, color: accentFor((b['code'] ?? '').toString())),
                const SizedBox(width: 8),
                SizedBox(
                  width: 112,
                  child: Text('${fmt(b['start_min'] as int)} – ${fmt(b['end_min'] as int)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                Expanded(
                  child: Text('${b['room_name']} · ${b['purpose']}',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.mut)),
                ),
              ]),
            ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 980;
    final list = _filtered;
    final main = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Requests · ${list.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      _filters(),
      if (pickDay != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              avatar: const Icon(Icons.event_rounded, size: 16, color: C.blue),
              label: Text('Showing ${longDate(pickDay!)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              onDeleted: () => setState(() => pickDay = null),
            ),
          ),
        ),
      const SizedBox(height: 14),
      if (list.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: cardDeco(),
          child: const Center(child: Text('No requests match these filters.', style: TextStyle(color: C.mut))),
        )
      else
        for (final b in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: _card(b)),
    ]);
    final side = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnalyticsCard(stats: stats, wide: false),
      const SizedBox(height: 16),
      _todayCard(),
      if (Api.isAdmin) ...[
        const SizedBox(height: 16),
        Btn('Reset demo data', small: true, outlined: true, icon: Icons.refresh_rounded, onTap: _reset),
      ],
    ]);
    return Shell(
      active: 'admin',
      child: PageBody(children: [
        HeaderBanner(
          code: 'CIT',
          icon: Api.isAdmin ? Icons.admin_panel_settings_rounded : Icons.draw_rounded,
          title: Api.isAdmin ? 'Admin Console' : 'Approvals · ${Api.signatory}',
          subtitle: loading
              ? 'Loading…'
              : Api.isAdmin
                  ? '${_count('pending')} request(s) waiting for the signatories'
                  : '$_awaitingMe request(s) waiting for your signature',
        ),
        if (Api.isAdmin)
          const Alert(
              'Room admins manage the rooms and bookings. Requests are approved by the signatories '
              '(deans, University Librarian, GSO Head and, above 100 attendees, the University President).',
              'warn'),
        const SizedBox(height: 16),
        if (loading)
          const Loading()
        else if (error != null)
          Alert(error!, 'bad')
        else ...[
          _calendar(MediaQuery.of(context).size.width >= 760),
          const SizedBox(height: 20),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 7, child: main),
              const SizedBox(width: 16),
              SizedBox(width: 360, child: side),
            ])
          else ...[
            side,
            const SizedBox(height: 16),
            main,
          ],
        ],
      ]),
    );
  }
}