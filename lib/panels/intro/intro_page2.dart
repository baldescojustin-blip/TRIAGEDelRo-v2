import 'package:flutter/material.dart';
import '../../main.dart';

// lib/panels/intro/intro_page2.dart

class IntroPage2 extends StatelessWidget {
  const IntroPage2({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Column(
        children: [
          // TOP IMAGE
          SizedBox(
            height: screenHeight * 0.62,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/intro_page/intro_page2.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.ink.withOpacity(0.92),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // BOTTOM CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'STAY INFORMED\nDURING EMERGENCIES',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(width: 60, height: 2, color: AppColors.electric),
                  const SizedBox(height: 16),
                  const Text(
                    'Receive real-time alerts, incident reports,\n'
                    'emergency health advisories, and triage\n'
                    'status updates — anytime, anywhere.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.7,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.amber.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'REAL-TIME · INCIDENT ALERTS · RESPONSE STATUS',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 9,
                        color: AppColors.amber,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}