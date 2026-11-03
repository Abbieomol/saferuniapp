import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/incident.dart';

/// Vertical timeline of every status change, newest at the top,
/// so students can see exactly what has happened to their report.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.history});

  final List<StatusUpdate> history;

  @override
  Widget build(BuildContext context) {
    final entries = [...history]..sort((a, b) => b.at.compareTo(a.at));
    final text = Theme.of(context).textTheme;
    final dateFormat = DateFormat('d MMM yyyy, HH:mm');

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dot and connecting line.
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: entries[i].status.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: entries[i].status.color.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      if (i < entries.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries[i].status.label,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: entries[i].status.color,
                          ),
                        ),
                        if (entries[i].note.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(entries[i].note, style: text.bodyMedium),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${entries[i].updatedBy} · ${dateFormat.format(entries[i].at)}',
                          style: text.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
