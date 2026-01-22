import 'dart:ui';

import 'package:ecoquest/game/level3/city_collection_screen.dart';
import 'package:flutter/material.dart';

class PollutedCityScreen extends StatelessWidget {
  const PollutedCityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
          // UI elements overlay
          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Top section: Title with translucent background
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 16.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Solid Waste Crisis',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                    fontFamily: 'Roboto',
                                    shadows: [
                                      Shadow(
                                        blurRadius: 8.0,
                                        color: Colors.black,
                                        offset: Offset(0, 2.0),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Custom gradient underline
                                CustomPaint(
                                  size: const Size(220, 3),
                                  painter: GradientUnderlinePainter(),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Level 3',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 6.0,
                                        color: Colors.black,
                                        offset: Offset(0, 2.0),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Middle section: Tasks list (unified background)
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 16.0,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.black.withValues(alpha: 0.5),
                                    Colors.black.withValues(alpha: 0.3),
                                    Colors.black.withValues(alpha: 0.1),
                                  ],
                                  stops: const [0.0, 0.5, 0.8, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTaskRow('Collect Waste'),
                                  const SizedBox(height: 8),
                                  _buildTaskRow('Repair Sewers'),
                                  const SizedBox(height: 8),
                                  _buildTaskRow('Sort Recyclables'),
                                  const SizedBox(height: 8),
                                  _buildTaskRow('Craft Upcycled Items'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Bottom section: Resources, button, and controls
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 24.0,
                          left: 16.0,
                          right: 16.0,
                        ),
                        child: Column(
                          children: [
                            // Resource cards row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildResourceCard(
                                  emoji: '💸',
                                  label: 'Eco-Points',
                                  isLarge: true,
                                ),
                                const SizedBox(width: 8),
                                _buildResourceCard(
                                  emoji: '🛡️',
                                  label: 'BluePrints',
                                  isLarge: true,
                                ),
                                const SizedBox(width: 8),
                                _buildResourceCard(
                                  emoji: '🫧',
                                  label: '',
                                  isLarge: false,
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Start Level button
                            _buildElevatedButton(
                              text: 'START LEVEL',
                              backgroundColor: const Color(0xFF2B7FD9),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CityCollectionScreen(),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 14),

                            // Bottom controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: _buildElevatedButton(
                                    text: 'Controls',
                                    backgroundColor: const Color(0xFF3C3C3C),
                                    onPressed: () {
                                      // Controls logic
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: _buildElevatedButton(
                                    text: 'Skip Intro',
                                    backgroundColor: const Color(0xFF3C3C3C),
                                    onPressed: () {
                                      // Skip intro logic
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(String task) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Yellow checkmark icon without circular background
        const Icon(
          Icons.check,
          color: Color(0xFFFFD700),
          size: 22,
          weight: 1000,
        ),
        const SizedBox(width: 10),
        Text(
          task,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 6.0,
                color: Colors.black,
                offset: Offset(0, 2.0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResourceCard({
    required String emoji,
    required String label,
    required bool isLarge,
  }) {
    return Container(
      width: isLarge ? 105 : 60,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A5F).withValues(alpha: 0.7),
            const Color(0xFF0D1B2A).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildElevatedButton({
    required String text,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  backgroundColor,
                  backgroundColor.withValues(
                    red: (backgroundColor.r * 0.8).clamp(0, 1),
                    green: (backgroundColor.g * 0.8).clamp(0, 1),
                    blue: (backgroundColor.b * 0.8).clamp(0, 1),
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    blurRadius: 4.0,
                    color: Colors.black,
                    offset: Offset(0, 2.0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for gradient underline
class GradientUnderlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height / 2);
    path.lineTo(size.width, size.height / 2);

    // Create gradient shader
    final gradient = LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0.1),
        Colors.white.withValues(alpha: 0.8),
        Colors.white,
        Colors.white.withValues(alpha: 0.8),
        Colors.white.withValues(alpha: 0.1),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = gradient.createShader(rect);

    // Draw thicker line in center, thinner at edges
    for (double i = 0; i <= size.width; i += 1) {
      final normalizedPosition = (i / size.width - 0.5).abs() * 2;
      final thickness = 3.0 - (normalizedPosition * 2.5);
      paint.strokeWidth = thickness;
      canvas.drawPoints(
        PointMode.points,
        [Offset(i, size.height / 2)],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
