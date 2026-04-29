import 'package:flutter/material.dart';
import '../../main.dart';

// lib/panels/intro/intro_page1.dart

class IntroPage1 extends StatelessWidget {
  const IntroPage1({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Column(
        children: [
          // TOP IMAGE - uses MediaQuery instead of .sh
          SizedBox(
            height: screenHeight * 0.6,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/intro_page/intro_page1.png',
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
                    'WELCOME TO\nMY LAUD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(width: 60, height: 2, color: AppColors.electric),
                  const SizedBox(height: 16),
                  const Text(
                    'A smart triage and emergency response\n'
                    'system connecting residents to faster\n'
                    'services, clearer communication, and\n'
                    'real-time updates — all in one app.',
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
                      border: Border.all(color: AppColors.electric.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'BDRRMC · BARANGAY DEL ROSARIO · MILAOR',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 9,
                        color: AppColors.electric,
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