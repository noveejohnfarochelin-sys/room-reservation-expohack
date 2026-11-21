import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:room_reservation_expohack/models/booking_model.dart';
import 'package:room_reservation_expohack/models/room_model.dart';
import 'package:room_reservation_expohack/services/booking_algorithm_service.dart';
import 'package:room_reservation_expohack/widgets/common_widgets.dart';

/// Shows the Smart Alternative Recommender. Returns true if a booking was made.
///
/// When [draft] is provided, alternatives are booked in one tap using the
/// draft's details. Otherwise the booking form opens pre-filled.
Future<bool> showSmartAlternativeDialog({
  required BuildContext context,
  required RoomModel targetRoom,
  required String bookingDate,
  required int startTime,
  required int endTime,
  required int attendeeCount,
  required List<String> requiredEquipment,
  BookingModel? draft,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _SmartAlternativeDialog(
      targetRoom: targetRoom,
      bookingDate: bookingDate,
      startTime: startTime,
      endTime: endTime,
      attendeeCount: attendeeCount,
      requiredEquipment: requiredEquipment,
      draft: draft,
    ),
  );
  return result ?? false;
}

class _SmartAlternativeDialog extends StatefulWidget {
  final RoomModel targetRoom;
  final String bookingDate;
  final int startTime;
  final int endTime;
  final int attendeeCount;
  final List<String> requiredEquipment;
  final BookingModel? draft;

  const _SmartAlternativeDialog({
    required this.targetRoom,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.attendeeCount,
    required this.requiredEquipment,
    required this.draft,
  });

  @override
  State<_SmartAlternativeDialog> createState() =>
      _SmartAlternativeDialogState();
}

class _SmartAlternativeDialogState extends State<_SmartAlternativeDialog> {
  final BookingAlgorithmService _service = BookingAlgorithmService();
  late Future<AlternativeRecommendation> _future;
  late int _attendees;
  late final TextEditingController _attendeeCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _attendees = widget.attendeeCount;
    _attendeeCtrl = TextEditingController(text: '$_attendees');
    _load();
  }

  @override
  void dispose() {
    _attendeeCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _future = _service.getSmartAlternatives(
      targetRoom: widget.targetRoom,
      bookingDate: widget.bookingDate,
      startTime: widget.startTime,
      endTime: widget.endTime,
      attendeeCount: _attendees,
      requiredEquipment: widget.requiredEquipment,
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitDraft(BookingModel booking) async {
    setState(() => _busy = true);
    try {
      await _service.createBookingAtomic(booking);
      if (!mounted) return;
      final sigs = BookingAlgorithmService.effectiveSignatories(
          booking.requiredSignatories, booking.attendeeCount);
      _snack('Booked ${booking.roomName}! Awaiting approval from: '
          '${sigs.join(', ')}');
      Navigator.of(context).pop(true);
    } on BookingConflictException catch (e) {
      if (!mounted) return;
      _snack('That option was just taken. ${e.message}');
      setState(() {
        _busy = false;
        _load();
      });
    } catch (e) {
      if (!mounted) return;
      _snack('Booking failed: $e');
      setState(() => _busy = false);
    }
  }

  Future<void> _bookRoom(RoomModel room) async {
    final draft = widget.draft;
    if (draft == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => BookingFormDialog(
          room: room,
          bookingDate: widget.bookingDate,
          initialStart: widget.startTime,
          initialEnd: widget.endTime,
        ),
      );
      if (ok == true && mounted) Navigator.of(context).pop(true);
      return;
    }
    await _submitDraft(draft.copyWith(
      roomId: room.id,
      roomName: room.name,
      departmentName: room.departmentName,
      requiredSignatories: room.requiredSignatories,
    ));
  }

  Future<void> _bookSlot(TimeSlotOption slot) async {
    final draft = widget.draft;
    if (draft == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => BookingFormDialog(
          room: widget.targetRoom,
          bookingDate: widget.bookingDate,
          initialStart: slot.startTime,
          initialEnd: slot.endTime,
        ),
      );
      if (ok == true && mounted) Navigator.of(context).pop(true);
      return;
    }
    await _submitDraft(
        draft.copyWith(startTime: slot.startTime, endTime: slot.endTime));
  }

  Widget _roomCard(RoomModel room) {
    final waste = room.capacity - _attendees;
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('${room.departmentName}\n'
                '${room.capacity} seats • $waste spare seats\n'
                '${room.equipment.join(', ')}'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _busy ? null : () => _bookRoom(room),
                child: const Text('Book Alternative Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotCard(TimeSlotOption slot) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.schedule),
            const SizedBox(width: 8),
            Expanded(
                child: Text(slot.label,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            FilledButton.tonal(
              onPressed: _busy ? null : () => _bookSlot(slot),
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Smart Alternatives'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Requested: ${widget.targetRoom.name}\n'
                  '${widget.bookingDate} • '
                  '${formatMinutes(widget.startTime)} - ${formatMinutes(widget.endTime)}'),
              const SizedBox(height: 12),
              TextField(
                controller: _attendeeCtrl,
                enabled: widget.draft == null,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of attendees',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null && n > 0) {
                    setState(() {
                      _attendees = n;
                      _load();
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<AlternativeRecommendation>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Text('Could not load alternatives: ${snap.error}');
                  }
                  final rec = snap.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Best-Fit Rooms (same time)',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      if (rec.bestFitRooms.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                              'No other room is free with enough capacity and equipment.'),
                        )
                      else
                        ...rec.bestFitRooms.map(_roomCard),
                      const SizedBox(height: 12),
                      Text('Nearest Free Time Slots (${widget.targetRoom.name})',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      if (rec.nearestFreeSlots.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No free slot of that length on this day.'),
                        )
                      else
                        ...rec.nearestFreeSlots.map(_slotCard),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class BookingFormDialog extends StatefulWidget {
  final RoomModel room;
  final String bookingDate; // YYYY-MM-DD
  final int initialStart;
  final int initialEnd;

  const BookingFormDialog({
    super.key,
    required this.room,
    required this.bookingDate,
    required this.initialStart,
    required this.initialEnd,
  });

  @override
  State<BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends State<BookingFormDialog> {
  static const List<String> _roles = [
    'President',
    'Secretary',
    'Officer',
    'Faculty/Staff',
  ];

  final BookingAlgorithmService _service = BookingAlgorithmService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _eventCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _orgCtrl = TextEditingController();
  final TextEditingController _attendeesCtrl = TextEditingController();

  late int _start;
  late int _end;
  String _role = 'Officer';
  final Set<String> _equipment = <String>{};
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start = (widget.initialStart.clamp(
                BookingAlgorithmService.operatingStart,
                BookingAlgorithmService.operatingEnd - 30)
            as num)
        .toInt();
    _start = (_start ~/ 30) * 30;
    _end = widget.initialEnd;
    if (_end <= _start) _end = _start + 60;
    if (_end > BookingAlgorithmService.operatingEnd) {
      _end = BookingAlgorithmService.operatingEnd;
    }
    _end = (_end ~/ 30) * 30;
    if (_end <= _start) _end = _start + 30;
  }

  @override
  void dispose() {
    _eventCtrl.dispose();
    _nameCtrl.dispose();
    _orgCtrl.dispose();
    _attendeesCtrl.dispose();
    super.dispose();
  }

  List<int> get _startOptions => [
        for (var m = BookingAlgorithmService.operatingStart;
            m <= BookingAlgorithmService.operatingEnd - 30;
            m += 30)
          m
      ];

  List<int> get _endOptions => [
        for (var m = _start + 30; m <= BookingAlgorithmService.operatingEnd; m += 30)
          m
      ];

  String get _prettyDate {
    try {
      return DateFormat('EEE, MMM d, yyyy')
          .format(DateFormat('yyyy-MM-dd').parse(widget.bookingDate));
    } catch (_) {
      return widget.bookingDate;
    }
  }

  BookingModel _buildDraft() {
    return BookingModel(
      id: '',
      roomId: widget.room.id,
      roomName: widget.room.name,
      departmentName: widget.room.departmentName,
      eventName: _eventCtrl.text.trim(),
      requesterName: _nameCtrl.text.trim(),
      organization: _orgCtrl.text.trim(),
      requesterRole: _role,
      bookingDate: widget.bookingDate,
      startTime: _start,
      endTime: _end,
      attendeeCount: int.parse(_attendeesCtrl.text.trim()),
      includedEquipment: _equipment.toList(),
      status: 'pending',
      requiredSignatories: widget.room.requiredSignatories,
      approvedBy: const <String>[],
      createdAt: DateTime.now(),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = _buildDraft();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _service.createBookingAtomic(draft);
      if (!mounted) return;
      final sigs = BookingAlgorithmService.effectiveSignatories(
          draft.requiredSignatories, draft.attendeeCount);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Reservation submitted! Required signatories: ${sigs.join(', ')}'),
        duration: const Duration(seconds: 5),
      ));
      Navigator.of(context).pop(true);
    } on BookingConflictException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
      final booked = await showSmartAlternativeDialog(
        context: context,
        targetRoom: widget.room,
        bookingDate: widget.bookingDate,
        startTime: draft.startTime,
        endTime: draft.endTime,
        attendeeCount: draft.attendeeCount,
        requiredEquipment: draft.includedEquipment,
        draft: draft,
      );
      if (booked && mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit reservation: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final endOptions = _endOptions;
    return AlertDialog(
      title: const Text('Book a Room'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.room.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text('${widget.room.departmentName} • Capacity ${widget.room.capacity}'),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.event, size: 16),
                  const SizedBox(width: 6),
                  Text(_prettyDate),
                ]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LabeledDropdown<int>(
                        label: 'Start',
                        value: _start,
                        items: _startOptions
                            .map((m) => DropdownMenuItem<int>(
                                value: m, child: Text(formatMinutes(m))))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _start = v;
                            if (_end <= _start) {
                              _end = (_start + 60)
                                  .clamp(_start + 30,
                                      BookingAlgorithmService.operatingEnd)
                                  .toInt();
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LabeledDropdown<int>(
                        label: 'End',
                        value: endOptions.contains(_end) ? _end : endOptions.first,
                        items: endOptions
                            .map((m) => DropdownMenuItem<int>(
                                value: m, child: Text(formatMinutes(m))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _end = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _eventCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Event Name', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Event name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Person Name', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _orgCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Organization',
                      border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Organization is required'
                      : null,
                ),
                const SizedBox(height: 12),
                LabeledDropdown<String>(
                  label: 'Position / Role',
                  value: _role,
                  items: _roles
                      .map((r) =>
                          DropdownMenuItem<String>(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _role = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _attendeesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Number of Attendees',
                      border: OutlineInputBorder()),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter a valid number';
                    if (n > widget.room.capacity) {
                      return 'Exceeds room capacity (${widget.room.capacity})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text('Equipment Inclusions',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                if (widget.room.equipment.isEmpty)
                  const Text('No equipment listed for this room.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: widget.room.equipment.map((e) {
                      return FilterChip(
                        label: Text(e),
                        selected: _equipment.contains(e),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _equipment.add(e);
                          } else {
                            _equipment.remove(e);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit Reservation'),
        ),
      ],
    );
  }
}