import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MandalaColoringScreen extends StatefulWidget {
  final Color dyeColor;
  final String dyeType;
  final Function(int) onComplete;

  const MandalaColoringScreen({
    super.key,
    required this.dyeColor,
    required this.dyeType,
    required this.onComplete,
  });

  @override
  State<MandalaColoringScreen> createState() => _MandalaColoringScreenState();
}

class _MandalaColoringScreenState extends State<MandalaColoringScreen> {
  Set<int> coloredSections = {};
  int totalSections = 16;
  int dyeUsed = 0;
  bool isComplete = false;

  @override
  Widget build(BuildContext context) {
    double completionPercentage = (coloredSections.length / totalSections) * 100;

    return Scaffold(
      backgroundColor: const Color(0xFF1B3A1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D1E17),
        title: Text(
          'MANDALA COLORING',
          style: GoogleFonts.vt323(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showExitConfirmation(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black.withValues(alpha: 0.3),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROGRESS',
                            style: GoogleFonts.vt323(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${coloredSections.length}/$totalSections sections',
                            style: GoogleFonts.vt323(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'DYE USED',
                            style: GoogleFonts.vt323(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.water_drop, color: widget.dyeColor, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$dyeUsed ml',
                                style: GoogleFonts.vt323(
                                  fontSize: 16,
                                  color: widget.dyeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  Container(
                    width: double.infinity,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: widget.dyeColor, width: 2),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: MediaQuery.of(context).size.width *
                              (completionPercentage / 100),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              colors: [
                                widget.dyeColor,
                                widget.dyeColor.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${completionPercentage.toInt()}% Complete',
                    style: GoogleFonts.vt323(
                      fontSize: 16,
                      color: widget.dyeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Mandala canvas
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: widget.dyeColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CustomPaint(
                        painter: MandalaPainter(
                          coloredSections: coloredSections,
                          dyeColor: widget.dyeColor,
                          totalSections: totalSections,
                        ),
                        child: GestureDetector(
                          onTapDown: (details) => _handleTap(details.localPosition),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black.withValues(alpha: 0.3),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.touch_app, color: Colors.amber, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap the white sections to color them with your ${widget.dyeType}',
                          style: GoogleFonts.vt323(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isComplete) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onComplete(dyeUsed);
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.check_circle, size: 24),
                        label: Text(
                          'FINISH & CLAIM REWARDS',
                          style: GoogleFonts.vt323(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(Offset position) {
    if (isComplete) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    
    // Calculate angle from center
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final angle = math.atan2(dy, dx);
    final normalizedAngle = (angle + math.pi) / (2 * math.pi);
    final section = (normalizedAngle * totalSections).floor();

    if (!coloredSections.contains(section)) {
      setState(() {
        coloredSections.add(section);
        dyeUsed += 1; // Each section uses 0.3ml, total of 5ml for complete
        
        if (coloredSections.length == totalSections) {
          isComplete = true;
        }
      });
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1E17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Exit Coloring?',
          style: GoogleFonts.vt323(fontSize: 22, color: Colors.white),
        ),
        content: Text(
          coloredSections.isEmpty
              ? 'You haven\'t colored anything yet. Exit anyway?'
              : 'Your progress will be lost. Are you sure?',
          style: GoogleFonts.vt323(fontSize: 16, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'CONTINUE',
              style: GoogleFonts.vt323(fontSize: 18, color: Colors.green),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'EXIT',
              style: GoogleFonts.vt323(fontSize: 18, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class MandalaPainter extends CustomPainter {
  final Set<int> coloredSections;
  final Color dyeColor;
  final int totalSections;

  MandalaPainter({
    required this.coloredSections,
    required this.dyeColor,
    required this.totalSections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Draw background
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw mandala sections
    for (int i = 0; i < totalSections; i++) {
      final startAngle = (i / totalSections) * 2 * math.pi - math.pi / 2;
      final sweepAngle = (2 * math.pi) / totalSections;

      final paint = Paint()
        ..color = coloredSections.contains(i)
            ? dyeColor.withValues(alpha: 0.8)
            : Colors.white
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);

      // Draw section borders
      final borderPaint = Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, borderPaint);
    }

    // Draw concentric circles for detail
    for (double r = radius * 0.3; r < radius; r += radius * 0.2) {
      final circlePaint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, r, circlePaint);
    }

    // Draw center circle
    final centerPaint = Paint()
      ..color = coloredSections.length > totalSections / 2
          ? dyeColor
          : Colors.grey.shade200
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.15, centerPaint);

    final centerBorderPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius * 0.15, centerBorderPaint);
  }

  @override
  bool shouldRepaint(MandalaPainter oldDelegate) =>
      oldDelegate.coloredSections != coloredSections;
}