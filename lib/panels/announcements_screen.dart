import 'package:flutter/material.dart';
import '../main.dart'; // Make sure this points to where AppColors is

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        title: const Text('ANNOUNCEMENTS'),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.textInverse,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'LATEST UPDATES',
            style: TextStyle(
              color: AppColors.textDim,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          // Here is the custom card we built for your theme!
          AnnouncementCard(
            category: 'SERVICES',
            date: 'MARCH 13, 2026',
            title: 'New Waste Collection Schedule',
            description: 'Please ensure segregated waste is placed outside by 8:00 AM every Tuesday and Friday. Bio-waste only on Wednesdays.',
            isUrgent: true,
          ),
          SizedBox(height: 24),
          AnnouncementCard(
            category: 'ADVISORY',
            date: 'MARCH 10, 2026',
            title: 'Scheduled Power Interruption',
            description: 'There will be a scheduled power interruption on Saturday from 8:00 AM to 5:00 PM for line maintenance.',
            isUrgent: false,
          ),
        ],
      ),
    );
  }
}

// ─── Custom Announcement Card Widget ──────────────────────────────────────────
class AnnouncementCard extends StatelessWidget {
  final String category;
  final String date;
  final String title;
  final String description;
  final bool isUrgent;

  const AnnouncementCard({
    super.key,
    required this.category,
    required this.date,
    required this.title,
    required this.description,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.void_, // Dark card background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Placeholder Area (Replaces the green truck)
          Container(
            height: 140,
            width: double.infinity,
            color: AppColors.surface, // Subtle dark background
            child: const Icon(
              Icons.local_shipping_outlined, // Truck icon
              size: 48,
              color: AppColors.textDim,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category Badge & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.electric.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppColors.electric,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 12,
                        fontFamily: 'IBMPlexMono',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Title & Description
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Bottom Row: Status & Details Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isUrgent)
                      const Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: AppColors.amber),
                          SizedBox(width: 6),
                          Text(
                            'EFFECTIVE IMMEDIATELY',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(), // Empty space if not urgent
                      
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        minimumSize: const Size(80, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () {}, // Add detail action later
                      child: const Text('Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}