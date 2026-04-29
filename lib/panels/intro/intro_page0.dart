import 'package:flutter/material.dart';
import '../../main.dart';

// lib/panels/intro/intro_page0.dart
// Branded splash-style page shown as the FIRST intro screen

class IntroPage0 extends StatelessWidget {
  const IntroPage0({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5B21B6), // rich violet
              Color(0xFF7C3AED), // primary violet
              Color(0xFF6D28D9), // deeper violet bottom
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo (Increased Size)
              Image.asset(
                'assets/images/intro_page/milaudlogo.png',
                width: 350,  // <-- Increased from 150
                height: 300, // <-- Increased from 120
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 40),

              // App name
              const Text(
                'MYLAUD',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 6,
                  height: 1,
                ),
              ),

              const SizedBox(height: 16),

              // Subtitle
              const Text(
                'MILAOR, CAMARINES SUR',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70, 
                  letterSpacing: 4,
                ),
              ),

              const Spacer(flex: 3),

              // Bottom progress bar area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // CONNECTING Text ONLY
                    const Text(
                      'CONNECTING...',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 11,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}