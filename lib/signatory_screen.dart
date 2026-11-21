import 'package:flutter/material.dart';
import 'package:room_reservation_expohack/models/booking_model.dart';
import 'package:room_reservation_expohack/services/booking_algorithm_service.dart';
import 'package:room_reservation_expohack/widgets/common_widgets.dart';

class SignatoryScreen extends StatefulWidget {
  final String signatoryName;
  const SignatoryScreen({super.key, required this.signatoryName});

  @override
  State<SignatoryScreen> createState() => _SignatoryScreenState();
}

class _SignatoryScreenState extends State<SignatoryScreen> {
  final BookingAlgorithmService _service = BookingAlgorithmService();
  late final Stream<List<BookingModel>> _stream = _service.streamAllBookings();

  bool _requiresMine = true;
  String _roomFilter = 'all';

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _approve(BookingModel b) async {
    try {
      await _service.approveBooking(
          bookingId: b.id, signatoryName: widget.signatoryName);
      if (!mounted) return;
      _snack('Signed "${b.eventName}" as ${widget.signatoryName}.');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not approve: $e');
    }
  }

  Future<void> _reject(BookingModel b) async {
    final ok = await confirmAction(context, 'Reject request?',
        'Reject "${b.eventName}"? The time slot will be freed.');
    if (!ok) return;
    try {
      await _service.updateBookingStatus(
          bookingId: b.id, newStatus: 'rejected');
      if (!mounted) return;
      _snack('Request rejected.');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not reject: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Signatory: ${widget.signatoryName}')),
      body: StreamBuilder<List<BookingModel>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pending =
              snap.data!.where((b) => b.status == 'pending').toList();

          final rooms = <String, String>{};
          for (final b in pending) {
            rooms[b.roomId] = b.roomName;
          }
          final roomFilter = rooms.containsKey(_roomFilter) ? _roomFilter : 'all';

          final shown = pending.where((b) {
            if (roomFilter != 'all' && b.roomId != roomFilter) return false;
            if (_requiresMine) {
              return b.requiredSignatories.contains(widget.signatoryName) &&
                  !b.approvedBy.contains(widget.signatoryName);
            }
            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                            value: true,
                            label: Text('Requires My Signature'),
                            icon: Icon(Icons.draw)),
                        ButtonSegment<bool>(
                            value: false,
                            label: Text('All Pending Requests'),
                            icon: Icon(Icons.list)),
                      ],
                      selected: <bool>{_requiresMine},
                      onSelectionChanged: (s) =>
                          setState(() => _requiresMine = s.first),
                    ),
                    const SizedBox(height: 12),
                    LabeledDropdown<String>(
                      label: 'Filter by Room',
                      value: roomFilter,
                      items: [
                        const DropdownMenuItem<String>(
                            value: 'all', child: Text('All Rooms')),
                        ...rooms.entries.map((e) => DropdownMenuItem<String>(
                            value: e.key, child: Text(e.value))),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _roomFilter = v);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('No requests to show.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final b = shown[i];
                          final isRequired =
                              b.requiredSignatories.contains(widget.signatoryName);
                          final alreadySigned =
                              b.approvedBy.contains(widget.signatoryName);
                          final canApprove = isRequired && !alreadySigned;
                          return BookingTile(
                            booking: b,
                            actions: [
                              OutlinedButton.icon(
                                onPressed: isRequired ? () => _reject(b) : null,
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                              ),
                              FilledButton.icon(
                                onPressed: canApprove ? () => _approve(b) : null,
                                icon: const Icon(Icons.check),
                                label: Text(alreadySigned ? 'Signed' : 'Approve'),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}