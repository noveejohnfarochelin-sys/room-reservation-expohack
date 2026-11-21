import 'package:flutter/material.dart';
import 'package:room_reservation_expohack/models/booking_model.dart';

Color statusColor(String status) {
  switch (status) {
    case 'approved':
      return Colors.green.shade700;
    case 'pending':
      return Colors.amber.shade800;
    case 'rejected':
      return Colors.red.shade700;
    default:
      return Colors.grey.shade600;
  }
}

Color statusBackground(String status) {
  switch (status) {
    case 'approved':
      return Colors.green.shade50;
    case 'pending':
      return Colors.amber.shade50;
    case 'rejected':
      return Colors.red.shade50;
    default:
      return Colors.grey.shade200;
  }
}

Future<bool> confirmAction(
    BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes')),
      ],
    ),
  );
  return result ?? false;
}

class BookingStatusChip extends StatelessWidget {
  final String status;
  const BookingStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusBackground(status),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor(status)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: statusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class BookingTile extends StatelessWidget {
  final BookingModel booking;
  final List<Widget> actions;

  const BookingTile({
    super.key,
    required this.booking,
    this.actions = const <Widget>[],
  });

  Widget _info(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = booking.requiredSignatories.length;
    final done =
        booking.requiredSignatories.where(booking.approvedBy.contains).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.eventName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                BookingStatusChip(status: booking.status),
              ],
            ),
            const SizedBox(height: 8),
            _info(Icons.meeting_room,
                '${booking.roomName} • ${booking.departmentName}'),
            _info(Icons.event,
                '${booking.bookingDate}  ${booking.formattedTimeRange}'),
            _info(Icons.person,
                '${booking.requesterName} (${booking.requesterRole}) • ${booking.organization}'),
            _info(Icons.groups, '${booking.attendeeCount} attendees'),
            if (booking.includedEquipment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: booking.includedEquipment
                      .map((e) => Chip(
                            label: Text(e),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ),
            const Divider(height: 24),
            Text(
              '$done/$total Signatures Approved',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: booking.requiredSignatories.map((s) {
                final signed = booking.approvedBy.contains(s);
                return Chip(
                  avatar: Icon(
                    signed ? Icons.check_circle : Icons.hourglass_empty,
                    size: 18,
                    color: signed ? Colors.green.shade700 : Colors.amber.shade800,
                  ),
                  label: Text(s),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 8, runSpacing: 8, children: actions),
              ),
            ],
          ],
        ),
      ),
    );
  }
}