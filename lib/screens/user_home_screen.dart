import 'package:flutter/material.dart';
import 'package:room_reservation_expohack/models/booking_model.dart';
import 'package:room_reservation_expohack/models/room_model.dart';
import 'package:room_reservation_expohack/screens/room_calendar_screen.dart';
import 'package:room_reservation_expohack/services/booking_algorithm_service.dart';
import 'package:room_reservation_expohack/widgets/common_widgets.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final BookingAlgorithmService _service = BookingAlgorithmService();
  late final Stream<List<RoomModel>> _roomsStream = _service.streamRooms();
  late final Stream<List<BookingModel>> _bookingsStream =
      _service.streamAllBookings();

  int _browseMode = 0; // 0 = Departments, 1 = General Facilities
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tech4ISATU Rooms'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.meeting_room), text: 'Browse Rooms'),
              Tab(icon: Icon(Icons.event_note), text: 'My Reservations'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildBrowseTab(), _buildReservationsTab()],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Browse tab

  Widget _buildBrowseTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(
                  value: 0,
                  label: Text('Departments'),
                  icon: Icon(Icons.account_balance)),
              ButtonSegment<int>(
                  value: 1,
                  label: Text('General Facilities'),
                  icon: Icon(Icons.domain)),
            ],
            selected: <int>{_browseMode},
            onSelectionChanged: (s) => setState(() => _browseMode = s.first),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<RoomModel>>(
            stream: _roomsStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rooms = snap.data!;
              if (rooms.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No rooms yet. Go back and tap "Seed ISATU Rooms & Signatories".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return _browseMode == 0
                  ? _buildDepartments(rooms)
                  : _buildGeneral(rooms);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDepartments(List<RoomModel> rooms) {
    final groups = <String, List<RoomModel>>{};
    for (final r in rooms.where((r) => r.categoryType == 'Department')) {
      groups.putIfAbsent(r.departmentName, () => <RoomModel>[]).add(r);
    }
    if (groups.isEmpty) {
      return const Center(child: Text('No department rooms available.'));
    }
    final names = groups.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: names.map((name) {
        final list = groups[name]!;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.apartment)),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${list.length} room${list.length == 1 ? '' : 's'}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    _DepartmentRoomsScreen(department: name, rooms: list),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGeneral(List<RoomModel> rooms) {
    final general = rooms.where((r) => r.categoryType == 'General').toList();
    if (general.isEmpty) {
      return const Center(child: Text('No general facilities available.'));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: general.map((r) => _RoomCard(room: r)).toList(),
    );
  }

  // ------------------------------------------------------ Reservations tab

  Future<void> _cancel(BookingModel booking) async {
    final ok = await confirmAction(context, 'Cancel reservation?',
        'Cancel "${booking.eventName}" and free the time slot?');
    if (!ok) return;
    try {
      await _service.updateBookingStatus(
          bookingId: booking.id, newStatus: 'cancelled');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservation cancelled.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
    }
  }

  Widget _buildReservationsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Filter by requester, organization or event',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<BookingModel>>(
            stream: _bookingsStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data!.where((b) {
                if (_query.isEmpty) return true;
                return b.requesterName.toLowerCase().contains(_query) ||
                    b.organization.toLowerCase().contains(_query) ||
                    b.eventName.toLowerCase().contains(_query);
              }).toList();
              if (list.isEmpty) {
                return const Center(child: Text('No reservations found.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final b = list[i];
                  final cancellable =
                      b.status == 'pending' || b.status == 'approved';
                  return BookingTile(
                    booking: b,
                    actions: cancellable
                        ? [
                            OutlinedButton.icon(
                              onPressed: () => _cancel(b),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel Reservation'),
                            ),
                          ]
                        : const <Widget>[],
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

class _DepartmentRoomsScreen extends StatelessWidget {
  final String department;
  final List<RoomModel> rooms;

  const _DepartmentRoomsScreen({required this.department, required this.rooms});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(department)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: rooms.map((r) => _RoomCard(room: r)).toList(),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => RoomCalendarScreen(room: room)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(room.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const Icon(Icons.calendar_month),
                ],
              ),
              const SizedBox(height: 4),
              Text('${room.departmentName} • Capacity ${room.capacity}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: room.equipment
                    .map((e) => Chip(
                        label: Text(e), visualDensity: VisualDensity.compact))
                    .toList(),
              ),
              const SizedBox(height: 4),
              Text('Approvals: ${room.requiredSignatories.join(' + ')}',
                  style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }
}