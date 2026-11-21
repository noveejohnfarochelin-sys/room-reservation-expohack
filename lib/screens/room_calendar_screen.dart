import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:room_reservation_expohack/models/booking_model.dart';
import 'package:room_reservation_expohack/models/room_model.dart';
import 'package:room_reservation_expohack/services/booking_algorithm_service.dart';
import 'package:room_reservation_expohack/widgets/booking_form_dialog.dart';

enum _DayStatus { available, pending, full }

final DateFormat _dateKeyFormat = DateFormat('yyyy-MM-dd');

class RoomCalendarScreen extends StatefulWidget {
  final RoomModel room;
  const RoomCalendarScreen({super.key, required this.room});

  @override
  State<RoomCalendarScreen> createState() => _RoomCalendarScreenState();
}

class _RoomCalendarScreenState extends State<RoomCalendarScreen> {
  static const double _wideBreakpoint = 700;
  static const List<String> _weekdays = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat'
  ];

  final BookingAlgorithmService _service = BookingAlgorithmService();
  late final Stream<List<BookingModel>> _stream;
  late DateTime _focusedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _stream = _service.streamBookingsForRoom(widget.room.id);
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  _DayStatus _statusFor(List<BookingModel> bookings, String dateKey) {
    final active = bookings
        .where((b) =>
            b.bookingDate == dateKey && BookingAlgorithmService.isActive(b.status))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    var cursor = BookingAlgorithmService.operatingStart;
    var covered = false;
    for (final b in active) {
      if (b.startTime > cursor) break;
      if (b.endTime > cursor) cursor = b.endTime;
      if (cursor >= BookingAlgorithmService.operatingEnd) {
        covered = true;
        break;
      }
    }
    if (covered) return _DayStatus.full;
    if (active.any((b) => b.status == 'pending')) return _DayStatus.pending;
    return _DayStatus.available;
  }

  Color _fg(_DayStatus s) {
    switch (s) {
      case _DayStatus.available:
        return Colors.green.shade700;
      case _DayStatus.pending:
        return Colors.amber.shade800;
      case _DayStatus.full:
        return Colors.red.shade700;
    }
  }

  Color _bg(_DayStatus s) {
    switch (s) {
      case _DayStatus.available:
        return Colors.green.shade50;
      case _DayStatus.pending:
        return Colors.amber.shade50;
      case _DayStatus.full:
        return Colors.red.shade50;
    }
  }

  String _label(_DayStatus s) {
    switch (s) {
      case _DayStatus.available:
        return 'Available';
      case _DayStatus.pending:
        return 'Pending';
      case _DayStatus.full:
        return 'Fully Booked';
    }
  }

  void _onDayTap(DateTime date, bool isWide) {
    setState(() => _selectedDate = date);
    if (!isWide) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: _DaySlotsPanel(room: widget.room, date: date),
        ),
      );
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }

  Widget _buildGrid(List<BookingModel> bookings, bool isWide) {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final leading = first.weekday % 7; // Sunday-first
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final primary = Theme.of(context).colorScheme.primary;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.85,
      ),
      itemCount: leading + daysInMonth,
      itemBuilder: (context, index) {
        if (index < leading) return const SizedBox.shrink();
        final date =
            DateTime(_focusedMonth.year, _focusedMonth.month, index - leading + 1);
        final key = _dateKeyFormat.format(date);
        final isPast = date.isBefore(today);
        final status = _statusFor(bookings, key);
        final selected = _selectedDate != null &&
            _dateKeyFormat.format(_selectedDate!) == key;

        final borderColor = selected
            ? primary
            : (isPast ? Colors.grey.shade300 : _fg(status));

        return Material(
          color: isPast ? Colors.grey.shade100 : _bg(status),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: borderColor, width: selected ? 3 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: isPast ? null : () => _onDayTap(date, isWide),
            child: LayoutBuilder(
              builder: (context, c) {
                final showLabel = c.maxWidth >= 72;
                return Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPast ? Colors.grey : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (!isPast && showLabel)
                        Text(
                          _label(status),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _fg(status)),
                        )
                      else if (!isPast)
                        Icon(Icons.circle, size: 10, color: _fg(status)),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendar(bool isWide) {
    return StreamBuilder<List<BookingModel>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bookings = snap.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.room.departmentName} • Capacity ${widget.room.capacity}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('Approvals: ${widget.room.requiredSignatories.join(' + ')}',
                      style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _shiftMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          DateFormat('MMMM yyyy').format(_focusedMonth),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _shiftMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Row(
                    children: _weekdays
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(d,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  _buildGrid(bookings, isWide),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _legendItem(Colors.green.shade700, 'Available'),
                      _legendItem(Colors.amber.shade800, 'Pending'),
                      _legendItem(Colors.red.shade700, 'Fully Booked'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.room.name)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          final calendar = _buildCalendar(isWide);
          if (!isWide) return calendar;
          final selected = _selectedDate;
          return Row(
            children: [
              Expanded(child: calendar),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 360,
                child: selected == null
                    ? const Center(child: Text('Select a day to see time slots'))
                    : _DaySlotsPanel(room: widget.room, date: selected),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DaySlotsPanel extends StatefulWidget {
  final RoomModel room;
  final DateTime date;
  const _DaySlotsPanel({required this.room, required this.date});

  @override
  State<_DaySlotsPanel> createState() => _DaySlotsPanelState();
}

class _DaySlotsPanelState extends State<_DaySlotsPanel> {
  static const int _slotCount = 13; // 7:00 AM .. 8:00 PM, 1-hour blocks
  final BookingAlgorithmService _service = BookingAlgorithmService();
  late final Stream<List<BookingModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _service.streamBookingsForRoom(widget.room.id);
  }

  BookingModel? _bookingAt(List<BookingModel> day, int start, int end) {
    for (final b in day) {
      if (BookingAlgorithmService.overlaps(b.startTime, b.endTime, start, end)) {
        return b;
      }
    }
    return null;
  }

  Widget _slotCard({
    required String timeLabel,
    required Color bg,
    required Color fg,
    required String text,
    Widget? button,
  }) {
    return Card(
      color: bg,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
            if (button != null) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: button),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = _dateKeyFormat.format(widget.date);
    final now = DateTime.now();
    final isToday = _dateKeyFormat.format(now) == dateKey;
    final nowMinutes = now.hour * 60 + now.minute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMM d, yyyy').format(widget.date),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(widget.room.name),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<BookingModel>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final day = snap.data!
                  .where((b) =>
                      b.bookingDate == dateKey &&
                      BookingAlgorithmService.isActive(b.status))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _slotCount,
                itemBuilder: (context, i) {
                  final start = BookingAlgorithmService.operatingStart + i * 60;
                  final end = start + 60;
                  final label = '${formatMinutes(start)} - ${formatMinutes(end)}';
                  final booking = _bookingAt(day, start, end);

                  if (booking == null) {
                    final isPastSlot = isToday && end <= nowMinutes;
                    if (isPastSlot) {
                      return _slotCard(
                        timeLabel: label,
                        bg: Colors.grey.shade100,
                        fg: Colors.grey.shade600,
                        text: 'Past',
                      );
                    }
                    return _slotCard(
                      timeLabel: label,
                      bg: Colors.green.shade50,
                      fg: Colors.green.shade700,
                      text: 'Available',
                      button: FilledButton(
                        onPressed: () => showDialog<bool>(
                          context: context,
                          builder: (_) => BookingFormDialog(
                            room: widget.room,
                            bookingDate: dateKey,
                            initialStart: start,
                            initialEnd: end,
                          ),
                        ),
                        child: const Text('Book Now'),
                      ),
                    );
                  }

                  final isPending = booking.status == 'pending';
                  return _slotCard(
                    timeLabel: label,
                    bg: isPending ? Colors.amber.shade50 : Colors.red.shade50,
                    fg: isPending ? Colors.amber.shade800 : Colors.red.shade700,
                    text:
                        '${isPending ? 'Pending' : 'Approved'} - ${booking.eventName}',
                    button: OutlinedButton.icon(
                      onPressed: () => showSmartAlternativeDialog(
                        context: context,
                        targetRoom: widget.room,
                        bookingDate: dateKey,
                        startTime: start,
                        endTime: end,
                        attendeeCount: 1,
                        requiredEquipment: const <String>[],
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Find Smart Alternative'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}