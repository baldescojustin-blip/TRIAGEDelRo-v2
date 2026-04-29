import 'package:flutter/material.dart';
import '../../main.dart';

// lib/panels/intro/intro_page3.dart

class IntroPage3 extends StatelessWidget {
  const IntroPage3({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Column(
        children: [
          // TOP IMAGE
          SizedBox(
            height: screenHeight * 0.6,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/intro_page/intro_page3.png',
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
                    'YOUR MYLAUD\nEMERGENCY ASSISTANT',
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
                    'Report incidents, request assistance,\n'
                    'track triage status, and access emergency\n'
                    'services with just a tap.',
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
                  const Text(
                    '[ TOGETHER WE RESPOND. TOGETHER WE RECOVER. ]',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 10,
                      color: AppColors.electric,
                      letterSpacing: 1.2,
                      fontStyle: FontStyle.italic,
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