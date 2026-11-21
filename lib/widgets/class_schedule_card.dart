import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:room_reservation_expohack/main.dart';
import 'package:room_reservation_expohack/models/class_schedule_model.dart';
import 'package:room_reservation_expohack/services/firestore_server.dart';
import 'package:room_reservation_expohack/services/schedule_pdf_parser.dart';

/// Admin card: upload a class-schedule PDF, download a sample, review / clear imported blocks.
class ClassSchedulesCard extends StatefulWidget {
  final VoidCallback? onChanged;
  const ClassSchedulesCard({super.key, this.onChanged});

  @override
  State<ClassSchedulesCard> createState() => _ClassSchedulesCardState();
}

class _ClassSchedulesCardState extends State<ClassSchedulesCard> {
  static const _auto = 'Auto-detect';
  static const _buildings = [_auto, 'CEA', 'CCI', 'COE', 'CIT', 'CGBE', 'LIB'];
  static const _dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  List<ClassScheduleModel> items = [];
  bool loading = true;
  bool busy = false;
  bool expanded = false;
  String building = _auto;
  String? msg;
  String msgKind = 'good';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.call('GET', '/class-schedules');
    if (!mounted) return;
    setState(() {
      loading = false;
      if (r.ok) {
        items = [
          for (final m in (r.data as List))
            ClassScheduleModel.fromMap(Map<String, dynamic>.from(m as Map), (m['id'] ?? '').toString())
        ];
      } else {
        msg = r.error;
        msgKind = 'bad';
      }
    });
  }

  void _say(String text, String kind) => setState(() {
        msg = text;
        msgKind = kind;
      });

  /* ── upload ── */

  Future<void> _upload() async {
    setState(() {
      busy = true;
      msg = null;
    });
    try {
      final PlatformFile? file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
      if (file == null) {
        if (mounted) setState(() => busy = false);
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      final text = SchedulePdfParser.extractText(bytes);
      final rooms = await FirestoreServer.rooms();
      final res = SchedulePdfParser.parse(text, rooms, collegeOverride: building == _auto ? null : building);
      if (!mounted) return;
      if (res.error != null) {
        setState(() => busy = false);
        _say(res.error!, 'bad');
        return;
      }

      var replace = true;
      final perRoom = res.perRoom;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, setD) => AlertDialog(
            title: Text('Import ${res.entries.length} class blocks?'),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Building: ${res.collegeCode}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final e in perRoom.entries)
                  Text('• ${e.key}: ${e.value} block${e.value == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13)),
                if (res.skipped.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('${res.skipped.length} line(s) skipped:',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: C.busyInk, fontSize: 12.5)),
                  for (final s in res.skipped.take(4))
                    Text(s, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.mut)),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: replace,
                  onChanged: (v) => setD(() => replace = v ?? true),
                  title: const Text('Replace existing schedule for this building', style: TextStyle(fontSize: 13)),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Import')),
            ],
          ),
        ),
      );
      if (ok != true) {
        if (mounted) setState(() => busy = false);
        return;
      }

      final r = await Api.call('POST', '/class-schedules/import', body: {
        'college_code': res.collegeCode,
        'replace': replace,
        'entries': [for (final e in res.entries) e.toMap()],
      });
      if (!mounted) return;
      setState(() => busy = false);
      if (!r.ok) {
        _say(r.error, 'bad');
        return;
      }
      _say(
        'Imported ${r.data['imported']} class blocks for ${res.collegeCode}'
        '${replace ? ' (previous schedule replaced)' : ''}. Rooms are now blocked during class periods.'
        '${res.skipped.isEmpty ? '' : ' ${res.skipped.length} line(s) skipped.'}',
        'good',
      );
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      _say('Could not read that PDF: $e', 'bad');
    }
  }

  /* ── sample PDF ── */

  Future<Uint8List> _buildSamplePdf() async {
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final lines = SchedulePdfParser.sampleCciLines;
    final doc = pw.Document(title: 'Sample CCI class schedule', author: 'UniSpace');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        for (var i = 0; i < lines.length; i++)
          if (lines[i].isEmpty)
            pw.SizedBox(height: 8)
          else
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(lines[i],
                  style: pw.TextStyle(font: i < 3 ? bold : regular, fontSize: i < 3 ? 11 : 9)),
            ),
      ],
    ));
    return doc.save();
  }

  Future<void> _sample() async {
    try {
      final bytes = await _buildSamplePdf();
      await Printing.sharePdf(bytes: bytes, filename: 'UniSpace-Sample-CCI-Schedule.pdf');
    } catch (e) {
      if (mounted) _say('Could not create the sample PDF: $e', 'bad');
    }
  }

    /* ── load the sample straight into Firestore (no PDF) ── */

  Future<void> _loadSample() async {
    setState(() {
      busy = true;
      msg = null;
    });
    try {
      final rooms = await FirestoreServer.rooms();
      final res = SchedulePdfParser.parse(
        SchedulePdfParser.sampleCciLines.join('\n'),
        rooms,
        collegeOverride: 'CCI',
      );
      if (res.error != null) {
        if (mounted) setState(() => busy = false);
        _say(res.error!, 'bad');
        return;
      }
      final r = await Api.call('POST', '/class-schedules/import', body: {
        'college_code': 'CCI',
        'replace': true,
        'entries': [for (final e in res.entries) e.toMap()],
      });
      if (!mounted) return;
      setState(() => busy = false);
      if (!r.ok) {
        _say(r.error, 'bad');
        return;
      }
      _say(
        'Loaded ${r.data['imported']} sample CCI class blocks (previous CCI schedule replaced). '
        'Rooms are now blocked during class periods.',
        'good',
      );
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      _say('Could not load the sample schedule: $e', 'bad');
    }
  }

  /* ── clear ── */

  Future<void> _clear() async {
    final code = building == _auto ? null : building;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear class schedules'),
        content: Text(code == null
            ? 'Delete ALL imported class blocks? Rooms will no longer be blocked for classes.'
            : 'Delete the imported class blocks of $code?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await Api.call('DELETE', '/class-schedules', body: {'college_code': code ?? ''});
    if (!mounted) return;
    if (!r.ok) {
      _say(r.error, 'bad');
      return;
    }
    _say('Cleared ${r.data['deleted']} class block(s).', 'good');
    await _load();
    widget.onChanged?.call();
  }

  /* ── ui ── */

  Widget _picker() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: building,
            items: [
              for (final b in _buildings)
                DropdownMenuItem(
                  value: b,
                  child: Text(b == _auto ? 'Building: $b' : 'Building: ${bldName(b)}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => building = v);
            },
          ),
        ),
      );

  Widget _list() {
    final shown = building == _auto ? items : items.where((c) => c.collegeCode == building).toList();
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
      child: shown.isEmpty
          ? const Text('No class blocks for this building.', style: TextStyle(fontSize: 12.5, color: C.mut))
          : SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final c in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text.rich(
                      TextSpan(style: const TextStyle(fontSize: 12.5), children: [
                        TextSpan(text: '${c.roomName} · ', style: const TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: '${_dayShort[(c.dayOfWeek - 1).clamp(0, 6)]} ${fmt(c.startMin)} – ${fmt(c.endMin)} · '),
                        TextSpan(text: c.label.replaceFirst('Class · ', ''), style: const TextStyle(color: C.mut)),
                      ]),
                    ),
                  ),
              ]),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_view_week_rounded, color: C.blue, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Class Schedules (PDF)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: C.navy)),
          ),
          StatusChip(loading ? 'Loading…' : '${items.length} class blocks', items.isEmpty ? 'warn' : 'good'),
        ]),
        const SizedBox(height: 6),
        const Text(
          'Upload a recurring weekly class schedule. Rooms are blocked automatically during class periods '
          'on the calendar, in booking checks and in the smart conflict resolver.',
          style: TextStyle(fontSize: 12.5, color: C.mut, height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _picker(),
          Btn('Upload Schedule PDF', icon: Icons.upload_file_rounded, busy: busy, onTap: _upload),
                    Btn('Load Sample CCI Schedule', icon: Icons.playlist_add_rounded, busy: busy, onTap: _loadSample),
                    Btn('Download Sample CCI PDF', outlined: true, icon: Icons.download_rounded, onTap: _sample),
          if (items.isNotEmpty)
            Btn('Clear Schedules', outlined: true, icon: Icons.delete_outline_rounded, onTap: _clear),
        ]),
        if (msg != null) Alert(msg!, msgKind),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => setState(() => expanded = !expanded),
            icon: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            label: Text(expanded ? 'Hide imported classes' : 'Show imported classes (${items.length})'),
          ),
          if (expanded) _list(),
        ],
      ]),
    );
  }
}