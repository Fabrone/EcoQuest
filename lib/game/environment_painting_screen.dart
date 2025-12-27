import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EnvironmentPaintingScreen extends StatefulWidget {
  final Color dyeColor;
  final String dyeType;
  final Function(int) onComplete;

  const EnvironmentPaintingScreen({
    super.key,
    required this.dyeColor,
    required this.dyeType,
    required this.onComplete,
  });

  @override
  State<EnvironmentPaintingScreen> createState() =>
      _EnvironmentPaintingScreenState();
}

class _EnvironmentPaintingScreenState extends State<EnvironmentPaintingScreen>
    with TickerProviderStateMixin {
  List<PaintableObject> objects = [];
  int paintedObjects = 0;
  int dyeUsed = 0;
  bool isComplete = false;
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _initializeObjects();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  void _initializeObjects() {
    objects = [
      // Trees
      PaintableObject(
        id: 'tree1',
        type: ObjectType.tree,
        position: const Offset(80, 150),
        size: 100,
        isPainted: false,
      ),
      PaintableObject(
        id: 'tree2',
        type: ObjectType.tree,
        position: const Offset(280, 130),
        size: 120,
        isPainted: false,
      ),
      
      // Flowers
      PaintableObject(
        id: 'flower1',
        type: ObjectType.flower,
        position: const Offset(50, 320),
        size: 40,
        isPainted: false,
      ),
      PaintableObject(
        id: 'flower2',
        type: ObjectType.flower,
        position: const Offset(150, 340),
        size: 45,
        isPainted: false,
      ),
      PaintableObject(
        id: 'flower3',
        type: ObjectType.flower,
        position: const Offset(250, 330),
        size: 42,
        isPainted: false,
      ),
      PaintableObject(
        id: 'flower4',
        type: ObjectType.flower,
        position: const Offset(320, 345),
        size: 38,
        isPainted: false,
      ),
      
      // Rocks
      PaintableObject(
        id: 'rock1',
        type: ObjectType.rock,
        position: const Offset(180, 280),
        size: 50,
        isPainted: false,
      ),
      PaintableObject(
        id: 'rock2',
        type: ObjectType.rock,
        position: const Offset(100, 400),
        size: 45,
        isPainted: false,
      ),
      
      // Mushrooms
      PaintableObject(
        id: 'mushroom1',
        type: ObjectType.mushroom,
        position: const Offset(220, 360),
        size: 35,
        isPainted: false,
      ),
      PaintableObject(
        id: 'mushroom2',
        type: ObjectType.mushroom,
        position: const Offset(330, 280),
        size: 32,
        isPainted: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    double completionPercentage = (paintedObjects / objects.length) * 100;

    return Scaffold(
      backgroundColor: const Color(0xFF1B3A1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D1E17),
        title: Text(
          'PAINT THE FOREST',
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
                            'OBJECTS PAINTED',
                            style: GoogleFonts.vt323(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$paintedObjects/${objects.length}',
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

            // Forest canvas
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF87CEEB).withValues(alpha: 0.3),
                      const Color(0xFF90EE90).withValues(alpha: 0.5),
                      Colors.green.shade800,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: widget.dyeColor.withValues(alpha: 0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    children: [
                      // Ground
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.green.shade700.withValues(alpha: 0.7),
                                Colors.green.shade900,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Paintable objects
                      ...objects.map((obj) => Positioned(
                        left: obj.position.dx,
                        top: obj.position.dy,
                        child: GestureDetector(
                          onTap: () => _paintObject(obj),
                          child: AnimatedBuilder(
                            animation: _sparkleController,
                            builder: (context, child) {
                              return _buildPaintableObject(obj);
                            },
                          ),
                        ),
                      )),

                      // Sparkles for unpainted objects
                      if (!isComplete)
                        ...objects
                            .where((obj) => !obj.isPainted)
                            .map((obj) => Positioned(
                              left: obj.position.dx + obj.size / 2 - 15,
                              top: obj.position.dy - 20,
                              child: AnimatedBuilder(
                                animation: _sparkleController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: (math.sin(_sparkleController.value * 2 * math.pi) + 1) / 2,
                                    child: Icon(
                                      Icons.arrow_downward,
                                      color: Colors.amber,
                                      size: 30,
                                    ),
                                  );
                                },
                              ),
                            )),
                    ],
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
                          'Tap the objects to paint them with your ${widget.dyeType}',
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

  Widget _buildPaintableObject(PaintableObject obj) {
    Color objectColor = obj.isPainted ? widget.dyeColor : Colors.grey.shade400;

    switch (obj.type) {
      case ObjectType.tree:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tree crown
            Container(
              width: obj.size * 0.8,
              height: obj.size * 0.6,
              decoration: BoxDecoration(
                color: objectColor,
                shape: BoxShape.circle,
                boxShadow: obj.isPainted
                    ? [
                        BoxShadow(
                          color: widget.dyeColor.withValues(alpha: 0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
                border: Border.all(
                  color: Colors.brown.shade700,
                  width: 2,
                ),
              ),
            ),
            // Tree trunk
            Container(
              width: obj.size * 0.2,
              height: obj.size * 0.5,
              decoration: BoxDecoration(
                color: Colors.brown.shade600,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.brown.shade900,
                  width: 2,
                ),
              ),
            ),
          ],
        );

      case ObjectType.flower:
        return Stack(
          alignment: Alignment.center,
          children: [
            // Petals
            ...List.generate(6, (index) {
              double angle = (index / 6) * 2 * math.pi;
              return Transform.translate(
                offset: Offset(
                  math.cos(angle) * obj.size * 0.3,
                  math.sin(angle) * obj.size * 0.3,
                ),
                child: Container(
                  width: obj.size * 0.4,
                  height: obj.size * 0.4,
                  decoration: BoxDecoration(
                    color: objectColor,
                    shape: BoxShape.circle,
                    boxShadow: obj.isPainted
                        ? [
                            BoxShadow(
                              color: widget.dyeColor.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: Colors.black26,
                      width: 1,
                    ),
                  ),
                ),
              );
            }),
            // Center
            Container(
              width: obj.size * 0.3,
              height: obj.size * 0.3,
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.orange,
                  width: 2,
                ),
              ),
            ),
          ],
        );

      case ObjectType.rock:
        return Container(
          width: obj.size,
          height: obj.size * 0.7,
          decoration: BoxDecoration(
            color: objectColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(obj.size * 0.3),
              topRight: Radius.circular(obj.size * 0.4),
              bottomLeft: Radius.circular(obj.size * 0.2),
              bottomRight: Radius.circular(obj.size * 0.2),
            ),
            boxShadow: obj.isPainted
                ? [
                    BoxShadow(
                      color: widget.dyeColor.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
            border: Border.all(
              color: Colors.grey.shade700,
              width: 2,
            ),
          ),
        );

      case ObjectType.mushroom:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mushroom cap
            Container(
              width: obj.size,
              height: obj.size * 0.6,
              decoration: BoxDecoration(
                color: objectColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(obj.size * 0.5),
                  topRight: Radius.circular(obj.size * 0.5),
                  bottomLeft: Radius.circular(obj.size * 0.1),
                  bottomRight: Radius.circular(obj.size * 0.1),
                ),
                boxShadow: obj.isPainted
                    ? [
                        BoxShadow(
                          color: widget.dyeColor.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
                border: Border.all(
                  color: Colors.brown.shade700,
                  width: 2,
                ),
              ),
            ),
            // Mushroom stem
            Container(
              width: obj.size * 0.3,
              height: obj.size * 0.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(obj.size * 0.15),
                border: Border.all(
                  color: Colors.grey.shade400,
                  width: 1,
                ),
              ),
            ),
          ],
        );
    }
  }

  void _paintObject(PaintableObject obj) {
    if (obj.isPainted || isComplete) return;

    setState(() {
      obj.isPainted = true;
      paintedObjects++;
      dyeUsed += 1; // Each object uses ~0.4ml
      
      if (paintedObjects == objects.length) {
        isComplete = true;
      }
    });
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1E17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Exit Painting?',
          style: GoogleFonts.vt323(fontSize: 22, color: Colors.white),
        ),
        content: Text(
          paintedObjects == 0
              ? 'You haven\'t painted anything yet. Exit anyway?'
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

enum ObjectType { tree, flower, rock, mushroom }

class PaintableObject {
  final String id;
  final ObjectType type;
  final Offset position;
  final double size;
  bool isPainted;

  PaintableObject({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    required this.isPainted,
  });
}