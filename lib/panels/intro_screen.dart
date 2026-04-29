import 'package:flutter/material.dart';
import '../main.dart';
import 'intro/intro_page0.dart';
import 'intro/intro_page1.dart';
import 'intro/intro_page2.dart';
import 'intro/intro_page3.dart';
import 'login.dart';

// lib/panels/intro_screen.dart
// Page 0: branded splash → Pages 1-3: feature intros → Login

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageCtrl = PageController();
  int _current = 0;
  final int _total = 4; // page0 + page1 + page2 + page3

  final _pages = const [IntroPage0(), IntroPage1(), IntroPage2(), IntroPage3()];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < _total - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
    );
  }

  // Page 0 has no controls — tapping anywhere advances to page 1
  bool get _isPage0 => _current == 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: GestureDetector(
        // tap anywhere on page 0 to advance
        onTap: _isPage0 ? _next : null,
        child: Stack(
          children: [
            // ── Pages ──────────────────────────────────────────────────────
            PageView(
              controller: _pageCtrl,
              physics: _isPage0
                  ? const NeverScrollableScrollPhysics() // prevent swipe on page0
                  : const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _current = i),
              children: _pages,
            ),

            // ── Controls (hidden on page 0) ─────────────────────────────
            if (!_isPage0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 44),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.ink.withOpacity(0),
                        AppColors.ink.withOpacity(0.97),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dot indicators (pages 1-3 only, so 3 dots)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final active = (i + 1) == _current;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.electric
                                  : AppColors.textDim,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 20),

                      // Buttons row
                      Row(
                        children: [
                          // Skip (hidden on last page)
                          if (_current < _total - 1)
                            Expanded(
                              child: GestureDetector(
                                onTap: _goToLogin,
                                child: Container(
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SKIP',
                                    style: TextStyle(
                                      fontFamily: 'Rajdhani',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          if (_current < _total - 1) const SizedBox(width: 12),

                          // Next / Get Started
                          Expanded(
                            flex: _current < _total - 1 ? 2 : 1,
                            child: GestureDetector(
                              onTap: _next,
                              child: Container(
                                height: 50,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.electric,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.electric.withOpacity(0.4),
                                      blurRadius: 14,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _current == _total - 1
                                          ? 'GET STARTED'
                                          : 'NEXT',
                                      style: const TextStyle(
                                        fontFamily: 'Rajdhani',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 2.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ── Page 0 tap hint ─────────────────────────────────────────
            if (_isPage0)
              Positioned(
                bottom: 20, // <--- Lowered from 44 to 20 to fix the overlap!
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'TAP ANYWHERE TO CONTINUE',
                    style: TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.4),
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}