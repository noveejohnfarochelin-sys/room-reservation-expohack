import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:room_reservation_expohack/models/booking_model.dart';
import 'package:room_reservation_expohack/models/room_model.dart';
import 'package:room_reservation_expohack/services/booking_algorithm_service.dart';
import 'package:room_reservation_expohack/widgets/common_widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final BookingAlgorithmService _service = BookingAlgorithmService();
  late final Stream<List<RoomModel>> _roomsStream = _service.streamRooms();
  late final Stream<List<BookingModel>> _bookingsStream =
      _service.streamAllBookings();

  bool _running = false;
  BatchBenchmarkResult? _result;
  String? _benchmarkError;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _override(BookingModel b) async {
    final ok = await confirmAction(context, 'Admin override',
        'Cancel "${b.eventName}" (${b.roomName}) and free the slot?');
    if (!ok) return;
    try {
      await _service.updateBookingStatus(
          bookingId: b.id, newStatus: 'cancelled');
      if (!mounted) return;
      _snack('Reservation cancelled by admin.');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not cancel: $e');
    }
  }

  Future<void> _runBenchmark() async {
    setState(() {
      _running = true;
      _benchmarkError = null;
    });
    try {
      final result = await _service.runBatchBaselineTest();
      if (!mounted) return;
      setState(() {
        _result = result;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _benchmarkError = 'Benchmark failed: $e';
        _running = false;
      });
    }
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _roomOverview(List<RoomModel> rooms, List<BookingModel> bookings) {
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final nowMin = now.hour * 60 + now.minute;

    final groups = <String, List<RoomModel>>{};
    for (final r in rooms) {
      final key = r.categoryType == 'General' ? 'General Facilities' : r.departmentName;
      groups.putIfAbsent(key, () => <RoomModel>[]).add(r);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'General Facilities') return 1;
        if (b == 'General Facilities') return -1;
        return a.compareTo(b);
      });

    if (rooms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No rooms yet. Seed data from the login screen.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: keys.map((group) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(group,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                ...groups[group]!.map((room) {
                  final today = bookings
                      .where((b) =>
                          b.roomId == room.id &&
                          b.bookingDate == todayKey &&
                          BookingAlgorithmService.isActive(b.status))
                      .toList();
                  final occupied = today
                      .any((b) => b.startTime <= nowMin && b.endTime > nowMin);
                  return ListTile(
                    leading: const Icon(Icons.meeting_room),
                    title: Text(room.name),
                    subtitle: Text(
                        'Capacity ${room.capacity} • ${today.length} active booking(s) today'),
                    trailing: Chip(
                      label: Text(occupied ? 'Occupied now' : 'Free now'),
                      backgroundColor:
                          occupied ? Colors.red.shade50 : Colors.green.shade50,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _metric(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _benchmarkSection() {
    final r = _result;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Fires 10 valid + 5 overlapping requests through the atomic '
                'booking engine on a throw-away test date, then cleans up.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _running ? null : _runBenchmark,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.speed),
              label: const Text('Run Batch Baseline Test (15 Sample Requests)'),
            ),
            if (_benchmarkError != null) ...[
              const SizedBox(height: 12),
              Text(_benchmarkError!, style: TextStyle(color: Colors.red.shade700)),
            ],
            if (r != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric('Total Time (ms): ${r.elapsedMs}', Colors.blue.shade800),
                  _metric('Confirmed: ${r.confirmedCount}', Colors.green.shade700),
                  _metric('Conflicts Blocked: ${r.blockedCount}',
                      Colors.amber.shade800),
                  _metric(
                      'Double-Bookings: ${r.doubleBookings}',
                      r.doubleBookings == 0
                          ? Colors.green.shade700
                          : Colors.red.shade700),
                ],
              ),
              const SizedBox(height: 8),
              Text('Total processed: ${r.totalProcessed}'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Room Administrator')),
      body: StreamBuilder<List<RoomModel>>(
        stream: _roomsStream,
        builder: (context, roomSnap) {
          return StreamBuilder<List<BookingModel>>(
            stream: _bookingsStream,
            builder: (context, bookingSnap) {
              if (roomSnap.hasError || bookingSnap.hasError) {
                return Center(
                    child: Text('Error: ${roomSnap.error ?? bookingSnap.error}'));
              }
              if (!roomSnap.hasData || !bookingSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rooms = roomSnap.data!;
              final bookings = bookingSnap.data!;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _heading('Master Room Status Overview'),
                  _roomOverview(rooms, bookings),
                  _heading('Performance Demo'),
                  _benchmarkSection(),
                  _heading('All Reservations (${bookings.length})'),
                  if (bookings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No reservations yet.'),
                    )
                  else
                    ...bookings.map((b) {
                      final cancellable =
                          b.status == 'pending' || b.status == 'approved';
                      return BookingTile(
                        booking: b,
                        actions: cancellable
                            ? [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red.shade700),
                                  onPressed: () => _override(b),
                                  icon: const Icon(Icons.gavel),
                                  label: const Text(
                                      'Cancel Reservation (Admin Override)'),
                                ),
                              ]
                            : const <Widget>[],
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}