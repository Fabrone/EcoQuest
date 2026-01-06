import 'dart:math';
import 'package:ecoquest/game/water_pollution_game.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Color extension for lighten/darken methods
extension ColorExtension on Color {
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');
    final hsl = HSLColor.fromColor(this);
    final newLightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    final hslLight = hsl.withLightness(newLightness);
    return hslLight.toColor();
  }

  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');
    final hsl = HSLColor.fromColor(this);
    final newLightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    final hslDark = hsl.withLightness(newLightness);
    return hslDark.toColor();
  }
}

class SpeedboatComponent extends PositionComponent
    with
        HasGameReference<WaterPollutionGame>,
        KeyboardHandler,
        DragCallbacks,
        TapCallbacks {
  Vector2 velocity = Vector2.zero();
  double speed = 250.0;
  bool netDeployed = false;
  double rotation = 0.0;
  double targetRotation = 0.0;
  Vector2 targetPosition = Vector2.zero();

  // Enhanced 3D properties
  double tiltAngle = 0.0;
  double bobOffset = 0.0;
  List<Vector2> wakeTrail = [];
  bool isMoving = false;

  // Touch controls
  Vector2? joystickCenter;
  Vector2? joystickPosition;
  bool showJoystick = false;

  SpeedboatComponent({required super.position, required super.size}) {
    anchor = Anchor.center;
    targetPosition = position.clone();
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    priority = 100;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();

    // Apply 3D transformations
    final centerX = size.x / 2;
    final centerY = size.y / 2;

    canvas.translate(centerX, centerY);

    // Apply rotation and tilt for 3D effect
    canvas.rotate(rotation);

    // Pseudo-3D tilt based on movement
    if (tiltAngle.abs() > 0.01) {
      final transform = Matrix4.identity()
        ..setEntry(3, 2, 0.001) // perspective
        ..rotateY(tiltAngle * 0.3)
        ..rotateX(sin(bobOffset) * 0.1);
      
      canvas.transform(transform.storage);
    }

    canvas.translate(-centerX, -centerY);

    // Enhanced 3D boat body with multiple layers
    _draw3DBoatBody(canvas);

    // Windshield with realistic reflection
    _draw3DWindshield(canvas);

    // Add propeller wake effect when moving
    if (isMoving) {
      _drawPropellerWake(canvas);
    }

    // Enhanced net with 3D depth
    if (netDeployed) {
      _draw3DNet(canvas);
    }

    canvas.restore();

    // Draw wake trail behind boat
    _drawWakeTrail(canvas);
  }

  void _draw3DBoatBody(Canvas canvas) {
    // Main hull with gradient for depth
    final hullGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white,
        Colors.grey.shade100,
        Colors.grey.shade300,
        Colors.grey.shade400,
      ],
      stops: [0.0, 0.3, 0.7, 1.0],
    );

    final hullPaint = Paint()
      ..shader = hullGradient.createShader(Rect.fromLTWH(0, 0, size.x, size.y))
      ..style = PaintingStyle.fill;

    // Draw hull with 3D depth layers
    final hullPath = Path();

    // Bottom layer (darkest - underwater)
    hullPath.moveTo(size.x * 0.5, size.y * 0.1);
    hullPath.cubicTo(
      size.x * 0.2,
      size.y * 0.2,
      size.x * 0.1,
      size.y * 0.4,
      size.x * 0.15,
      size.y * 0.85,
    );
    hullPath.lineTo(size.x * 0.85, size.y * 0.85);
    hullPath.cubicTo(
      size.x * 0.9,
      size.y * 0.4,
      size.x * 0.8,
      size.y * 0.2,
      size.x * 0.5,
      size.y * 0.1,
    );
    hullPath.close();

    // Shadow for 3D depth
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.save();
    canvas.translate(3, 5);
    canvas.drawPath(hullPath, shadowPaint);
    canvas.restore();

    canvas.drawPath(hullPath, hullPaint);

    // Middle deck layer (lighter)
    final deckPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey.shade200],
          ).createShader(
            Rect.fromLTWH(
              size.x * 0.2,
              size.y * 0.3,
              size.x * 0.6,
              size.y * 0.4,
            ),
          );

    final deckPath = Path();
    deckPath.moveTo(size.x * 0.5, size.y * 0.25);
    deckPath.lineTo(size.x * 0.75, size.y * 0.35);
    deckPath.lineTo(size.x * 0.7, size.y * 0.65);
    deckPath.lineTo(size.x * 0.3, size.y * 0.65);
    deckPath.lineTo(size.x * 0.25, size.y * 0.35);
    deckPath.close();
    canvas.drawPath(deckPath, deckPaint);

    // Cabin structure
    final cabinPaint = Paint()
      ..shader =
          LinearGradient(
            colors: [Colors.grey.shade100, Colors.grey.shade300],
          ).createShader(
            Rect.fromLTWH(
              size.x * 0.3,
              size.y * 0.2,
              size.x * 0.4,
              size.y * 0.3,
            ),
          );

    final cabinPath = Path();
    cabinPath.moveTo(size.x * 0.35, size.y * 0.35);
    cabinPath.lineTo(size.x * 0.65, size.y * 0.35);
    cabinPath.lineTo(size.x * 0.6, size.y * 0.5);
    cabinPath.lineTo(size.x * 0.4, size.y * 0.5);
    cabinPath.close();
    canvas.drawPath(cabinPath, cabinPaint);

    // Racing stripes for detail
    final stripePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(size.x * 0.25, size.y * 0.45),
      Offset(size.x * 0.75, size.y * 0.45),
      stripePaint,
    );

    canvas.drawLine(
      Offset(size.x * 0.25, size.y * 0.55),
      Offset(size.x * 0.75, size.y * 0.55),
      stripePaint..color = Colors.blue,
    );

    // Railings for realism
    final railingPaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (double i = 0.3; i <= 0.7; i += 0.1) {
      canvas.drawLine(
        Offset(size.x * i, size.y * 0.65),
        Offset(size.x * i, size.y * 0.7),
        railingPaint,
      );
    }
  }

  void _draw3DWindshield(Canvas canvas) {
    final windshieldPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.lightBlue.withValues(alpha: 0.7),
              Colors.white.withValues(alpha: 0.4),
              Colors.lightBlue.withValues(alpha: 0.5),
            ],
            stops: [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromLTWH(
              size.x * 0.35,
              size.y * 0.2,
              size.x * 0.3,
              size.y * 0.25,
            ),
          );

    // Main windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.35, size.y * 0.2, size.x * 0.3, size.y * 0.25),
        const Radius.circular(8),
      ),
      windshieldPaint,
    );

    // Reflection highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.4, size.y * 0.22, size.x * 0.15, size.y * 0.08),
      highlightPaint,
    );

    // Windshield frame
    final framePaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.35, size.y * 0.2, size.x * 0.3, size.y * 0.25),
        const Radius.circular(8),
      ),
      framePaint,
    );
  }

  void _drawPropellerWake(Canvas canvas) {
    final wakePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Animated bubbles from propeller
    for (int i = 0; i < 5; i++) {
      final offset = sin(bobOffset * 3 + i) * 5;
      final bubbleSize = 3 + (i % 3) * 2.0;

      canvas.drawCircle(
        Offset(size.x * 0.5 + offset, size.y * 0.9 + i * 8),
        bubbleSize,
        wakePaint..color = Colors.white.withValues(alpha: 0.3 - (i * 0.05)),
      );
    }
  }

  void _draw3DNet(Canvas canvas) {
    final netGradient = RadialGradient(
      colors: [
        Colors.amber.withValues(alpha: 0.6),
        Colors.orange.withValues(alpha: 0.3),
      ],
    );

    final netPaint = Paint()
      ..shader = netGradient.createShader(
        Rect.fromLTWH(-20, size.y, size.x + 40, 60),
      );

    // 3D net with perspective
    final netPath = Path();
    netPath.moveTo(-20, size.y + 5);
    netPath.quadraticBezierTo(
      size.x * 0.5,
      size.y + 15,
      size.x + 20,
      size.y + 5,
    );
    netPath.lineTo(size.x + 15, size.y + 55);
    netPath.quadraticBezierTo(size.x * 0.5, size.y + 70, -15, size.y + 55);
    netPath.close();

    canvas.drawPath(netPath, netPaint);

    // Net mesh with 3D effect
    final meshPaint = Paint()
      ..color = Colors.orange.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Vertical lines with perspective
    for (double i = 0; i <= 1; i += 0.15) {
      final topX = -20 + (size.x + 40) * i;
      final topY = size.y + 5 + sin(i * pi) * 10;
      final bottomX = -15 + (size.x + 30) * i;
      final bottomY = size.y + 55 + sin(i * pi) * 15;

      canvas.drawLine(Offset(topX, topY), Offset(bottomX, bottomY), meshPaint);
    }

    // Horizontal lines
    for (double i = 0; i <= 1; i += 0.2) {
      final y = size.y + 5 + (50 * i);
      final curve = sin(i * pi) * 10;

      final linePath = Path();
      linePath.moveTo(-20 + curve, y);
      linePath.quadraticBezierTo(
        size.x * 0.5,
        y + curve * 0.5,
        size.x + 20 - curve,
        y,
      );
      canvas.drawPath(linePath, meshPaint);
    }

    // Net floats
    final floatPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (double i = 0.2; i <= 0.8; i += 0.2) {
      canvas.drawCircle(
        Offset(-20 + (size.x + 40) * i, size.y + 5),
        4,
        floatPaint,
      );
    }
  }

  void _drawWakeTrail(Canvas canvas) {
    if (wakeTrail.isEmpty) return;

    final wakePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < wakeTrail.length - 1; i++) {
      final alpha = (1.0 - (i / wakeTrail.length)) * 0.3;
      wakePaint.color = Colors.white.withValues(alpha: alpha);

      canvas.drawLine(
        Offset(wakeTrail[i].x, wakeTrail[i].y),
        Offset(wakeTrail[i + 1].x, wakeTrail[i + 1].y),
        wakePaint,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update bob animation
    bobOffset += dt * 2;

    // Smooth movement to target
    final direction = targetPosition - position;
    isMoving = direction.length > 5;

    if (direction.length > 1) {
      velocity = direction.normalized() * speed;
      position += velocity * dt;

      // Smooth rotation
      targetRotation = direction.angleTo(Vector2(0, -1));
      final rotationDiff = targetRotation - rotation;
      rotation += rotationDiff * 0.15;

      // Tilt based on turning
      tiltAngle += (rotationDiff * 0.5 - tiltAngle) * 0.1;

      // Update wake trail
      wakeTrail.add(position.clone());
      if (wakeTrail.length > 15) {
        wakeTrail.removeAt(0);
      }
    } else {
      velocity = Vector2.zero();
      tiltAngle *= 0.9; // Return to neutral
      isMoving = false;
    }

    // Bounds clamping with margins
    position.x = position.x.clamp(size.x, game.size.x - size.x);
    position.y = position.y.clamp(size.y, game.size.y - size.y);

    if (netDeployed) {
      _checkWasteCollision();
    }
  }

  void _checkWasteCollision() {
    final netCenter = position + Vector2(0, size.y / 2 + 35);
    final netArea = Rect.fromCenter(
      center: Offset(netCenter.x, netCenter.y),
      width: size.x + 50,
      height: 70,
    );

    final wasteCopy = List<WasteItemComponent>.from(game.wasteItems);

    for (var waste in wasteCopy) {
      final wasteRect = Rect.fromCenter(
        center: Offset(waste.position.x, waste.position.y),
        width: waste.size.x,
        height: waste.size.y,
      );

      if (netArea.overlaps(wasteRect)) {
        game.collectWaste(waste);
      }
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (keysPressed.isEmpty) {
      targetPosition = position.clone();
      return false;
    }

    final moveDirection = Vector2.zero();

    if (keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW)) {
      moveDirection.y = -1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS)) {
      moveDirection.y = 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA)) {
      moveDirection.x = -1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD)) {
      moveDirection.x = 1;
    }

    if (moveDirection.length > 0) {
      targetPosition = position + (moveDirection.normalized() * 150);
    }

    if (keysPressed.contains(LogicalKeyboardKey.space)) {
      deployNet();
    }

    return true;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // Mobile joystick
    joystickCenter = event.localPosition;
    joystickPosition = event.localPosition;
    showJoystick = true;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (joystickCenter != null) {
      joystickPosition = event.localEndPosition;

      // Calculate direction from joystick
      final direction = joystickPosition! - joystickCenter!;
      final distance = direction.length.clamp(0.0, 60.0);

      if (distance > 10) {
        targetPosition = position + direction.normalized() * (distance * 3);
      }
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    showJoystick = false;
    joystickCenter = null;
    joystickPosition = null;
    targetPosition = position.clone();
  }

  @override
  void onTapUp(TapUpEvent event) {
    deployNet();
  }

  void deployNet() {
    if (!netDeployed) {
      netDeployed = true;
      game.camera.viewfinder.add(
        ScaleEffect.by(
          Vector2.all(1.05),
          EffectController(duration: 0.3, alternate: true),
        ),
      );
      Future.delayed(
        const Duration(milliseconds: 1500),
        () => netDeployed = false,
      );
    }
  }
}

class WasteItemComponent extends PositionComponent with DragCallbacks, TapCallbacks {
  final String type;
  late Color color;
  late Color accentColor;
  double bobOffset = 0;
  double bobSpeed = 1.0 + Random().nextDouble() * 0.5;
  double bobAmount = 2.0 + Random().nextDouble() * 3.0;
  double rotation = 0.0;
  double rotationSpeed = (Random().nextDouble() - 0.5) * 0.2;
  
  // Drag state
  bool isDragging = false;
  Vector2? dragStartPosition;

  WasteItemComponent({
    required this.type,
    required super.position,
    required super.size,
  }) {
    color = _getColorForType(type);
    accentColor = _getAccentColorForType(type);
    priority = 50;
    anchor = Anchor.center;
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'plastic_bottle':
        return Colors.blue.shade700;
      case 'can':
        return Colors.grey.shade400;
      case 'bag':
        return Colors.white.withValues(alpha: 0.9);
      case 'oil_slick':
        return Colors.black87;
      case 'wood':
        return Colors.brown.shade600;
      default:
        return Colors.grey;
    }
  }

  Color _getAccentColorForType(String type) {
    switch (type) {
      case 'plastic_bottle':
        return Colors.lightBlue.shade300;
      case 'can':
        return Colors.grey.shade200;
      case 'bag':
        return Colors.grey.shade300;
      case 'oil_slick':
        return Colors.brown.shade900;
      case 'wood':
        return Colors.brown.shade300;
      default:
        return Colors.white;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isDragging) {
      bobOffset += dt * bobSpeed;
      position.y += sin(bobOffset) * bobAmount * dt;
      rotation += rotationSpeed * dt;
    }
  }

  @override
  bool onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    debugPrint('\n════════════════════════════════════');
    debugPrint('🎯 WASTE ITEM DRAG START');
    debugPrint('════════════════════════════════════');
    debugPrint('Item type: $type');
    debugPrint('Item position: $position');
    debugPrint('Item size: $size');
    debugPrint('Event local position: ${event.localPosition}');
    debugPrint('Event canvas position: ${event.canvasPosition}');
    
    // Check if this is the top item in the game
    final game = parent;
    if (game is WaterPollutionGame) {
      if (game.collectedWaste.isEmpty || game.collectedWaste.first != this) {
        debugPrint('❌ Not the top item - ignoring drag');
        debugPrint('════════════════════════════════════\n');
        return false;
      }
      
      if (game.currentPhase != 2) {
        debugPrint('❌ Not in sorting phase - ignoring drag');
        debugPrint('════════════════════════════════════\n');
        return false;
      }
    }
    
    isDragging = true;
    dragStartPosition = position.clone();
    
    // Stop animations
    removeAll(children.whereType<Effect>());
    
    // Lift effect
    add(ScaleEffect.to(
      Vector2.all(1.3),
      EffectController(duration: 0.15),
    ));
    
    priority = 300;
    
    debugPrint('✅ Drag started successfully');
    debugPrint('════════════════════════════════════\n');
    return true;
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    if (isDragging) {
      position += event.localDelta;
      return true;
    }
    return false;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    debugPrint('\n════════════════════════════════════');
    debugPrint('🎯 WASTE ITEM DRAG END');
    debugPrint('════════════════════════════════════');
    debugPrint('Item type: $type');
    debugPrint('Final position: $position');
    
    if (!isDragging) {
      debugPrint('❌ Not dragging - ignoring');
      debugPrint('════════════════════════════════════\n');
      return false;
    }
    
    isDragging = false;
    
    final game = parent;
    if (game is WaterPollutionGame) {
      debugPrint('Checking ${game.bins.length} bins for drop');
      
      BinComponent? closestBin;
      double closestDistance = double.infinity;
      
      // Find closest bin
      for (var bin in game.bins) {
        final distanceToBin = (bin.position - position).length;
        debugPrint('  - ${bin.binType}: distance=$distanceToBin');
        
        if (distanceToBin < closestDistance) {
          closestDistance = distanceToBin;
          closestBin = bin;
        }
      }
      
      if (closestBin != null) {
        final binRadius = (closestBin.size.x + closestBin.size.y) * 0.7;
        debugPrint('Closest bin: ${closestBin.binType}, distance=$closestDistance, radius=$binRadius');
        
        if (closestDistance < binRadius) {
          bool isCorrect = game.isCorrectBin(type, closestBin.binType);
          debugPrint('✅ Dropped in ${closestBin.binType} bin - ${isCorrect ? "CORRECT" : "WRONG"}');
          
          if (isCorrect) {
            game.submitSort(this, closestBin);
            debugPrint('════════════════════════════════════\n');
            return true;
          } else {
            // WRONG BIN - trigger feedback
            closestBin.triggerErrorAnimation();
            game.showWrongBinFeedback(type, closestBin.binType);
            
            // Return to stack WITHOUT opacity effects (use only safe effects)
            debugPrint('Returning to stack (wrong bin)');
            removeAll(children.whereType<Effect>());
            
            final stackCenterX = game.size.x * 0.5;
            final stackCenterY = game.size.y * 0.30;
            
            // Use only MoveEffect and ScaleEffect - NO OpacityEffect
            add(SequenceEffect([
              MoveEffect.to(
                Vector2(stackCenterX, stackCenterY),
                EffectController(duration: 0.4, curve: Curves.easeOut),
              ),
              ScaleEffect.to(
                Vector2.all(1.0),
                EffectController(duration: 0.2),
              ),
            ]));
            
            priority = 150;
            debugPrint('════════════════════════════════════\n');
            return true;
          }
        } else {
          debugPrint('❌ Too far from bin');
        }
      }
      
      // Return to original position (dropped outside any bin)
      debugPrint('Returning to stack (dropped outside)');
      removeAll(children.whereType<Effect>());
      
      final stackCenterX = game.size.x * 0.5;
      final stackCenterY = game.size.y * 0.30;
      
      // Use only safe effects - NO OpacityEffect
      add(SequenceEffect([
        MoveEffect.to(
          Vector2(stackCenterX, stackCenterY),
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.2),
        ),
      ]));
      
      priority = 150;
    }
    
    debugPrint('════════════════════════════════════\n');
    return true;
  }

  @override
  bool onTapDown(TapDownEvent event) {
    debugPrint('\n════════════════════════════════════');
    debugPrint('🎯 WASTE ITEM TAP');
    debugPrint('════════════════════════════════════');
    debugPrint('Item type: $type');
    debugPrint('Item position: $position');
    
    final game = parent;
    if (game is WaterPollutionGame) {
      if (game.collectedWaste.isEmpty || game.collectedWaste.first != this) {
        debugPrint('❌ Not the top item');
        debugPrint('════════════════════════════════════\n');
        return false;
      }
      
      if (game.currentPhase != 2) {
        debugPrint('❌ Not in sorting phase');
        debugPrint('════════════════════════════════════\n');
        return false;
      }
      
      // Toggle selection
      if (game.selectedWaste == this) {
        game.selectedWaste = null;
        removeAll(children.whereType<Effect>());
        scale = Vector2.all(1.0);
        debugPrint('✅ Item deselected');
      } else {
        if (game.selectedWaste != null) {
          game.selectedWaste!.removeAll(game.selectedWaste!.children.whereType<Effect>());
          game.selectedWaste!.scale = Vector2.all(1.0);
        }
        game.selectedWaste = this;
        removeAll(children.whereType<Effect>());
        add(ScaleEffect.to(
          Vector2.all(1.2),
          EffectController(duration: 0.2),
        ));
        debugPrint('✅ Item selected');
      }
      
      debugPrint('════════════════════════════════════\n');
      return true;
    }
    
    debugPrint('════════════════════════════════════\n');
    return false;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    final centerX = size.x / 2;
    final centerY = size.y / 2;

    canvas.translate(centerX, centerY);
    canvas.rotate(rotation);

    // Apply 3D perspective transform
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.002)
      ..rotateX(sin(bobOffset) * 0.2)
      ..rotateY(cos(bobOffset * 0.7) * 0.15);

    canvas.transform(transform.storage);
    canvas.translate(-centerX, -centerY);

    // Multi-layer shadow for depth
    _draw3DShadow(canvas);

    // Main object with enhanced 3D shading
    final paint = Paint()
      ..shader = _create3DGradient().createShader(size.toRect());

    canvas.drawPath(_getPathForType(), paint);

    // Specular highlights
    _drawSpecularHighlights(canvas);

    // Type-specific 3D details
    _draw3DTypeDetails(canvas);

    canvas.restore();
  }

  // Keep all existing render methods unchanged...
  void _draw3DShadow(Canvas canvas) {
    final shadowLayers = [
      (offset: Offset(4, 6), blur: 8.0, alpha: 0.4),
      (offset: Offset(2, 3), blur: 4.0, alpha: 0.3),
      (offset: Offset(1, 1.5), blur: 2.0, alpha: 0.2),
    ];

    for (final layer in shadowLayers) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: layer.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, layer.blur);

      canvas.save();
      canvas.translate(layer.offset.dx, layer.offset.dy);
      canvas.drawPath(_getPathForType(), shadowPaint);
      canvas.restore();
    }
  }

  Path _getPathForType() {
    final path = Path();
    switch (type) {
      case 'plastic_bottle':
        path.moveTo(size.x * 0.4, 0);
        path.lineTo(size.x * 0.6, 0);
        path.lineTo(size.x * 0.7, size.y * 0.2);
        path.lineTo(size.x * 0.8, size.y * 0.6);
        path.lineTo(size.x * 0.7, size.y);
        path.lineTo(size.x * 0.3, size.y);
        path.lineTo(size.x * 0.2, size.y * 0.6);
        path.lineTo(size.x * 0.3, size.y * 0.2);
        path.close();
        return path;
      case 'can':
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.x, size.y),
            Radius.circular(size.x * 0.1),
          ),
        );
        return path;
      case 'bag':
        path.moveTo(size.x * 0.2, size.y * 0.3);
        path.quadraticBezierTo(size.x * 0.1, size.y * 0.5, size.x * 0.3, size.y * 0.7);
        path.quadraticBezierTo(size.x * 0.5, size.y * 0.9, size.x * 0.7, size.y * 0.7);
        path.quadraticBezierTo(size.x * 0.9, size.y * 0.5, size.x * 0.8, size.y * 0.3);
        path.quadraticBezierTo(size.x * 0.7, size.y * 0.1, size.x * 0.5, size.y * 0.2);
        path.quadraticBezierTo(size.x * 0.3, size.y * 0.1, size.x * 0.2, size.y * 0.3);
        path.close();
        return path;
      case 'oil_slick':
        path.moveTo(size.x * 0.3, size.y * 0.2);
        path.quadraticBezierTo(size.x * 0.1, size.y * 0.3, size.x * 0.2, size.y * 0.5);
        path.quadraticBezierTo(size.x * 0.1, size.y * 0.7, size.x * 0.4, size.y * 0.8);
        path.quadraticBezierTo(size.x * 0.6, size.y * 0.9, size.x * 0.8, size.y * 0.7);
        path.quadraticBezierTo(size.x * 0.9, size.y * 0.5, size.x * 0.7, size.y * 0.3);
        path.quadraticBezierTo(size.x * 0.8, size.y * 0.1, size.x * 0.5, size.y * 0.15);
        path.close();
        return path;
      case 'wood':
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.x, size.y),
            Radius.circular(size.y * 0.2),
          ),
        );
        return path;
      default:
        path.addRect(Rect.fromLTWH(0, 0, size.x, size.y));
        return path;
    }
  }

  LinearGradient _create3DGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color.lighten(0.3), color, color.darken(0.2), color.darken(0.4)],
      stops: [0.0, 0.4, 0.7, 1.0],
    );
  }

  void _drawSpecularHighlights(Canvas canvas) {
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    Offset highlightPos;
    double highlightSize;

    switch (type) {
      case 'plastic_bottle':
        highlightPos = Offset(size.x * 0.4, size.y * 0.2);
        highlightSize = size.x * 0.2;
        break;
      case 'can':
        highlightPos = Offset(size.x * 0.35, size.y * 0.15);
        highlightSize = size.x * 0.25;
        break;
      default:
        highlightPos = Offset(size.x * 0.4, size.y * 0.3);
        highlightSize = size.x * 0.15;
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: highlightPos,
        width: highlightSize,
        height: highlightSize * 0.6,
      ),
      highlightPaint,
    );
  }

  void _draw3DTypeDetails(Canvas canvas) {
    switch (type) {
      case 'plastic_bottle':
        _draw3DPlasticBottle(canvas);
        break;
      case 'can':
        _draw3DCan(canvas);
        break;
      case 'bag':
        _draw3DBag(canvas);
        break;
      case 'oil_slick':
        _draw3DOilSlick(canvas);
        break;
      case 'wood':
        _draw3DWood(canvas);
        break;
    }
  }

  void _draw3DPlasticBottle(Canvas canvas) {
    // Bottle body with cylindrical shading
    final bodyGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        color.darken(0.2),
        color,
        color.lighten(0.2),
        color,
        color.darken(0.2),
      ],
      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    final bodyPaint = Paint()
      ..shader = bodyGradient.createShader(
        Rect.fromLTWH(size.x * 0.25, size.y * 0.15, size.x * 0.5, size.y * 0.7),
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.25, size.y * 0.15, size.x * 0.5, size.y * 0.7),
        const Radius.circular(6),
      ),
      bodyPaint,
    );

    // Cap with 3D effect
    final capGradient = RadialGradient(
      colors: [accentColor.lighten(0.2), accentColor.darken(0.2)],
    );

    final capPaint = Paint()
      ..shader = capGradient.createShader(
        Rect.fromLTWH(size.x * 0.38, -2, size.x * 0.24, size.y * 0.18),
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.38, -2, size.x * 0.24, size.y * 0.18),
        const Radius.circular(3),
      ),
      capPaint,
    );

    // Label with perspective
    final labelPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.9),
              Colors.white.withValues(alpha: 0.7),
            ],
          ).createShader(
            Rect.fromLTWH(
              size.x * 0.22,
              size.y * 0.35,
              size.x * 0.56,
              size.y * 0.35,
            ),
          );

    final labelPath = Path();
    labelPath.moveTo(size.x * 0.22, size.y * 0.35);
    labelPath.lineTo(size.x * 0.78, size.y * 0.35);
    labelPath.lineTo(size.x * 0.76, size.y * 0.7);
    labelPath.lineTo(size.x * 0.24, size.y * 0.7);
    labelPath.close();

    canvas.drawPath(labelPath, labelPaint);

    // Brand text simulation
    final textPaint = Paint()
      ..color = Colors.blue.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(size.x * 0.3, size.y * (0.45 + i * 0.05)),
        Offset(size.x * 0.7, size.y * (0.45 + i * 0.05)),
        textPaint,
      );
    }
  }

  void _draw3DCan(Canvas canvas) {
    // Cylindrical can body with metallic sheen
    final canGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.grey.shade600,
        Colors.grey.shade300,
        Colors.grey.shade100,
        Colors.grey.shade300,
        Colors.grey.shade600,
      ],
      stops: [0.0, 0.2, 0.5, 0.8, 1.0],
    );

    final canPaint = Paint()..shader = canGradient.createShader(size.toRect());

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.15, size.y * 0.05, size.x * 0.7, size.y * 0.9),
        Radius.circular(size.x * 0.12),
      ),
      canPaint,
    );

    // Top rim
    final rimPaint = Paint()
      ..shader = LinearGradient(colors: [accentColor.darken(0.2), accentColor])
          .createShader(
            Rect.fromLTWH(
              size.x * 0.15,
              size.y * 0.05,
              size.x * 0.7,
              size.y * 0.12,
            ),
          );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.x * 0.15,
          size.y * 0.05,
          size.x * 0.7,
          size.y * 0.12,
        ),
        const Radius.circular(4),
      ),
      rimPaint,
    );

    // Pull tab
    final tabPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.42, size.y * 0.08, size.x * 0.16, size.y * 0.08),
      tabPaint,
    );

    // Label band with 3D curve
    final bandPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red, Colors.red.shade700],
          ).createShader(
            Rect.fromLTWH(
              size.x * 0.15,
              size.y * 0.4,
              size.x * 0.7,
              size.y * 0.25,
            ),
          );

    final bandPath = Path();
    bandPath.moveTo(size.x * 0.15, size.y * 0.4);
    bandPath.lineTo(size.x * 0.85, size.y * 0.4);
    bandPath.cubicTo(
      size.x * 0.88,
      size.y * 0.525,
      size.x * 0.88,
      size.y * 0.525,
      size.x * 0.85,
      size.y * 0.65,
    );
    bandPath.lineTo(size.x * 0.15, size.y * 0.65);
    bandPath.cubicTo(
      size.x * 0.12,
      size.y * 0.525,
      size.x * 0.12,
      size.y * 0.525,
      size.x * 0.15,
      size.y * 0.4,
    );
    bandPath.close();

    canvas.drawPath(bandPath, bandPaint);

    // Metallic highlights
    for (int i = 0; i < 5; i++) {
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15 - (i * 0.02))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawLine(
        Offset(size.x * (0.2 + i * 0.12), size.y * 0.1),
        Offset(size.x * (0.2 + i * 0.12), size.y * 0.9),
        highlightPaint,
      );
    }
  }

  void _draw3DBag(Canvas canvas) {
    // Wrinkled plastic bag with transparency layers
    final bagGradient = RadialGradient(
      center: Alignment.center,
      colors: [
        color.withValues(alpha: 0.9),
        color.withValues(alpha: 0.7),
        color.withValues(alpha: 0.5),
      ],
    );

    final bagPaint = Paint()
      ..shader = bagGradient.createShader(size.toRect())
      ..style = PaintingStyle.fill;

    final bagPath = Path();
    bagPath.moveTo(size.x * 0.25, size.y * 0.2);

    // Irregular organic shape for floating bag
    bagPath.cubicTo(
      size.x * 0.1,
      size.y * 0.3,
      size.x * 0.05,
      size.y * 0.5,
      size.x * 0.2,
      size.y * 0.7,
    );
    bagPath.cubicTo(
      size.x * 0.35,
      size.y * 0.85,
      size.x * 0.65,
      size.y * 0.85,
      size.x * 0.8,
      size.y * 0.7,
    );
    bagPath.cubicTo(
      size.x * 0.95,
      size.y * 0.5,
      size.x * 0.9,
      size.y * 0.3,
      size.x * 0.75,
      size.y * 0.2,
    );
    bagPath.cubicTo(
      size.x * 0.65,
      size.y * 0.1,
      size.x * 0.35,
      size.y * 0.1,
      size.x * 0.25,
      size.y * 0.2,
    );
    bagPath.close();

    canvas.drawPath(bagPath, bagPaint);

    // Wrinkle lines for realism
    final wrinklePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 4; i++) {
      final wrinklePath = Path();
      final startY = size.y * (0.25 + i * 0.15);

      wrinklePath.moveTo(size.x * 0.2, startY);
      wrinklePath.quadraticBezierTo(
        size.x * 0.35,
        startY + sin(i * 1.5) * 8,
        size.x * 0.5,
        startY,
      );
      wrinklePath.quadraticBezierTo(
        size.x * 0.65,
        startY - sin(i * 1.5) * 8,
        size.x * 0.8,
        startY,
      );

      canvas.drawPath(wrinklePath, wrinklePaint);
    }

    // Handles
    final handlePaint = Paint()
      ..color = color.darken(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final leftHandle = Path();
    leftHandle.moveTo(size.x * 0.3, size.y * 0.15);
    leftHandle.quadraticBezierTo(
      size.x * 0.25,
      size.y * 0.05,
      size.x * 0.35,
      size.y * 0.15,
    );
    canvas.drawPath(leftHandle, handlePaint);

    final rightHandle = Path();
    rightHandle.moveTo(size.x * 0.65, size.y * 0.15);
    rightHandle.quadraticBezierTo(
      size.x * 0.75,
      size.y * 0.05,
      size.x * 0.7,
      size.y * 0.15,
    );
    canvas.drawPath(rightHandle, handlePaint);
  }

  void _draw3DOilSlick(Canvas canvas) {
    // Multi-layer oil slick with iridescent effect
    final slickGradient = RadialGradient(
      center: Alignment.center,
      colors: [
        Colors.black87,
        Colors.brown.shade900,
        Colors.brown.shade700,
        Colors.brown.shade900.withValues(alpha: 0.8),
      ],
      stops: [0.0, 0.3, 0.6, 1.0],
    );

    final slickPaint = Paint()
      ..shader = slickGradient.createShader(size.toRect())
      ..style = PaintingStyle.fill;

    final slickPath = Path();
    slickPath.moveTo(size.x * 0.3, size.y * 0.15);
    slickPath.cubicTo(
      size.x * 0.05,
      size.y * 0.25,
      size.x * 0.1,
      size.y * 0.5,
      size.x * 0.2,
      size.y * 0.65,
    );
    slickPath.cubicTo(
      size.x * 0.15,
      size.y * 0.8,
      size.x * 0.4,
      size.y * 0.9,
      size.x * 0.6,
      size.y * 0.85,
    );
    slickPath.cubicTo(
      size.x * 0.85,
      size.y * 0.75,
      size.x * 0.92,
      size.y * 0.5,
      size.x * 0.8,
      size.y * 0.3,
    );
    slickPath.cubicTo(
      size.x * 0.85,
      size.y * 0.12,
      size.x * 0.6,
      size.y * 0.08,
      size.x * 0.3,
      size.y * 0.15,
    );
    slickPath.close();

    canvas.drawPath(slickPath, slickPaint);

    // Iridescent rainbow sheen layers
    final sheenColors = [
      (color: Colors.purple.withValues(alpha: 0.3), scale: 0.7),
      (color: Colors.blue.withValues(alpha: 0.25), scale: 0.5),
      (color: Colors.green.withValues(alpha: 0.2), scale: 0.4),
      (color: Colors.yellow.withValues(alpha: 0.15), scale: 0.3),
    ];

    for (final sheen in sheenColors) {
      final sheenPaint = Paint()
        ..color = sheen.color
        ..style = PaintingStyle.fill;

      final sheenPath = Path();
      final offsetX = sin(bobOffset * 2) * 5;
      final offsetY = cos(bobOffset * 2) * 5;

      sheenPath.moveTo(
        size.x * (0.35 + offsetX / 100),
        size.y * (0.25 + offsetY / 100),
      );
      sheenPath.cubicTo(
        size.x * (0.25 + offsetX / 100),
        size.y * (0.35 + offsetY / 100),
        size.x * (0.3 + offsetX / 100),
        size.y * (0.55 + offsetY / 100),
        size.x * (0.45 + offsetX / 100),
        size.y * (0.65 + offsetY / 100),
      );
      sheenPath.cubicTo(
        size.x * (0.6 + offsetX / 100),
        size.y * (0.7 + offsetY / 100),
        size.x * (0.7 + offsetX / 100),
        size.y * (0.5 + offsetY / 100),
        size.x * (0.65 + offsetX / 100),
        size.y * (0.35 + offsetY / 100),
      );
      sheenPath.close();

      canvas.save();
      canvas.scale(sheen.scale, sheen.scale);
      canvas.translate(
        size.x * (1 - sheen.scale) / 2,
        size.y * (1 - sheen.scale) / 2,
      );
      canvas.drawPath(sheenPath, sheenPaint);
      canvas.restore();
    }

    // Bubbles on surface
    final bubblePaint = Paint()
      ..color = Colors.brown.shade800.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final x = size.x * (0.2 + (i % 3) * 0.25 + sin(bobOffset + i) * 0.05);
      final y = size.y * (0.3 + (i ~/ 3) * 0.3 + cos(bobOffset + i) * 0.05);
      final radius = 2 + (i % 3) * 1.5;

      canvas.drawCircle(Offset(x, y), radius, bubblePaint);
    }
  }

  void _draw3DWood(Canvas canvas) {
    // Wooden log with bark texture
    final woodGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.brown.shade400,
        Colors.brown.shade600,
        Colors.brown.shade700,
        Colors.brown.shade600,
      ],
      stops: [0.0, 0.3, 0.7, 1.0],
    );

    final woodPaint = Paint()
      ..shader = woodGradient.createShader(size.toRect());

    final logPath = Path();
    logPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.05, size.y * 0.25, size.x * 0.9, size.y * 0.5),
        Radius.circular(size.y * 0.25),
      ),
    );

    canvas.drawPath(logPath, woodPaint);

    // Bark texture with vertical lines
    final barkPaint = Paint()
      ..color = Colors.brown.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 8; i++) {
      final x = size.x * (0.15 + i * 0.1);
      final lineHeight = size.y * 0.45;
      final yStart = size.y * 0.275;

      // Irregular bark lines
      final barkPath = Path();
      barkPath.moveTo(x, yStart);

      for (double j = 0; j <= 1; j += 0.2) {
        final offset = sin((i + j) * 3) * 2;
        barkPath.lineTo(x + offset, yStart + lineHeight * j);
      }

      canvas.drawPath(barkPath, barkPaint);
    }

    // Wood grain details
    final grainPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      final grainPath = Path();
      final y = size.y * (0.35 + i * 0.15);

      grainPath.moveTo(size.x * 0.1, y);
      grainPath.cubicTo(
        size.x * 0.3,
        y + sin(i * 2) * 4,
        size.x * 0.7,
        y - sin(i * 2) * 4,
        size.x * 0.95,
        y,
      );

      canvas.drawPath(grainPath, grainPaint);
    }

    // End caps showing cut wood
    final endCapPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.brown.shade300,
              Colors.brown.shade600,
              Colors.brown.shade800,
            ],
          ).createShader(
            Rect.fromLTWH(0, size.y * 0.25, size.x * 0.12, size.y * 0.5),
          );

    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.02, size.y * 0.28, size.x * 0.12, size.y * 0.44),
      endCapPaint,
    );

    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.86, size.y * 0.28, size.x * 0.12, size.y * 0.44),
      endCapPaint,
    );

    // Growth rings on end caps
    final ringPaint = Paint()
      ..color = Colors.brown.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      canvas.drawOval(
        Rect.fromLTWH(
          size.x * 0.02 + i * 2,
          size.y * 0.28 + i * 3,
          size.x * 0.12 - i * 4,
          size.y * 0.44 - i * 6,
        ),
        ringPaint,
      );
    }
  }
}

// Enhanced WaterTileComponent with full 3D visualization
class WaterTileComponent extends PositionComponent
    with HasGameReference<WaterPollutionGame>, TapCallbacks {
  final int row;
  final int col;
  bool isPolluted;
  bool isTreating = false;
  bool isClear = false;
  double treatmentProgress = 0.0;
  List<BacteriaParticle> bacteriaParticles = [];
  double waveAnimation = 0.0;
  double pollutionDensity = 0.0;

  WaterTileComponent({
    required this.row,
    required this.col,
    required super.position,
    required super.size,
    required this.isPolluted,
  }) {
    pollutionDensity = isPolluted ? (0.6 + Random().nextDouble() * 0.4) : 0.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    waveAnimation += dt * 2;
    
    if (isTreating) {
      treatmentProgress += dt / 2.0; // 2 seconds treatment time
      
      // Update bacteria particles
      for (var particle in bacteriaParticles) {
        particle.update(dt);
      }
      
      // Gradually reduce pollution
      pollutionDensity = (1.0 - treatmentProgress) * pollutionDensity;
      
      if (treatmentProgress >= 1.0) {
        completeTreatment();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();

    // Determine water color based on state
    Color baseWaterColor;
    if (isClear) {
      baseWaterColor = const Color(0xFF00BCD4); // Crystal clear cyan
    } else if (isTreating) {
      // Transitioning color during treatment
      baseWaterColor = Color.lerp(
        const Color(0xFF8B4513), // Brown polluted
        const Color(0xFF00BCD4), // Clear cyan
        treatmentProgress,
      ) ?? const Color(0xFF808080);
    } else if (isPolluted) {
      baseWaterColor = const Color(0xFF8B4513); // Brown polluted
    } else {
      baseWaterColor = const Color(0xFF64B5F6); // Light blue
    }

    // Draw water with 3D layered effect
    _draw3DWaterSurface(canvas, baseWaterColor);
    
    // Draw pollution particles if polluted
    if (isPolluted && !isClear) {
      _drawPollutionParticles(canvas);
    }
    
    // Draw bacteria particles during treatment
    if (isTreating) {
      _drawBacteriaParticles(canvas);
      _drawTreatmentEffect(canvas);
    }
    
    // Draw sparkles and bubbles for clear water
    if (isClear) {
      _drawClearWaterEffects(canvas);
    }
    
    // Draw tile border with glow
    _draw3DTileBorder(canvas);

    canvas.restore();
  }

  void _draw3DWaterSurface(Canvas canvas, Color waterColor) {
    // Multi-layer water for depth
    final layers = [
      (depth: 0.0, alpha: 0.9, offset: 0.0),
      (depth: 0.2, alpha: 0.7, offset: 0.1),
      (depth: 0.4, alpha: 0.5, offset: 0.2),
    ];
    
    for (final layer in layers) {
      // Ensure lighten/darken amounts are always positive and safe
      final lightenAmount = (0.2 - layer.depth).clamp(0.0, 0.3);
      final darkenAmount = (0.2 + layer.depth).clamp(0.0, 0.3);
      
      final layerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          waterColor.lighten(lightenAmount).withValues(alpha: layer.alpha),
          waterColor.withValues(alpha: layer.alpha),
          waterColor.darken(darkenAmount).withValues(alpha: layer.alpha),
        ],
        stops: [0.0, 0.5, 1.0],
      );

      final layerPaint = Paint()
        ..shader = layerGradient.createShader(size.toRect());

      // Animated wave surface
      final wavePath = Path();
      wavePath.moveTo(0, size.y * layer.offset);
      
      final segments = 20;
      for (int i = 0; i <= segments; i++) {
        final x = (size.x / segments) * i;
        final wave = sin(waveAnimation + (x / 20) + (row * 0.5) + (col * 0.3)) * 3;
        final y = size.y * layer.offset + wave;
        
        if (i == 0) {
          wavePath.lineTo(x, y);
        } else {
          wavePath.lineTo(x, y);
        }
      }
      
      wavePath.lineTo(size.x, size.y);
      wavePath.lineTo(0, size.y);
      wavePath.close();

      canvas.drawPath(wavePath, layerPaint);
    }
    
    // Specular highlight for water shine
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 1.5,
        colors: [
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(size.toRect());
    
    canvas.drawRect(size.toRect(), highlightPaint);
  }

  void _drawPollutionParticles(Canvas canvas) {
    final random = Random(row * 100 + col);
    final particleCount = (pollutionDensity * 15).toInt();
    
    for (int i = 0; i < particleCount; i++) {
      final x = random.nextDouble() * size.x;
      final baseY = random.nextDouble() * size.y;
      final floatOffset = sin(waveAnimation * 1.5 + i) * 4;
      final y = baseY + floatOffset;
      
      // Varied pollution particle types
      final particleType = random.nextInt(3);
      
      if (particleType == 0) {
        // Dark sediment particles
        final sedimentPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.brown.shade900.withValues(alpha: 0.7),
              Colors.brown.shade700.withValues(alpha: 0.4),
              Colors.brown.shade700.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCenter(
              center: Offset(x, y),
              width: 8,
              height: 8,
            ),
          );
        
        canvas.drawCircle(Offset(x, y), 3 + random.nextDouble() * 2, sedimentPaint);
      } else if (particleType == 1) {
        // Algae/organic matter
        final algaePaint = Paint()
          ..color = Colors.green.shade900.withValues(alpha: 0.5);
        
        final algaePath = Path();
        algaePath.moveTo(x, y);
        algaePath.quadraticBezierTo(
          x + 3, y + 2,
          x + 6, y,
        );
        algaePath.quadraticBezierTo(
          x + 3, y - 2,
          x, y,
        );
        
        canvas.drawPath(algaePath, algaePaint);
      } else {
        // Chemical contaminants (cloudy areas)
        final chemicalPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.grey.shade800.withValues(alpha: 0.4),
              Colors.grey.shade700.withValues(alpha: 0.2),
              Colors.grey.shade700.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCenter(
              center: Offset(x, y),
              width: 15,
              height: 15,
            ),
          );
        
        canvas.drawCircle(Offset(x, y), 5 + random.nextDouble() * 3, chemicalPaint);
      }
    }
  }

  void _drawBacteriaParticles(Canvas canvas) {
    for (var particle in bacteriaParticles) {
      particle.render(canvas);
    }
  }

  void _drawTreatmentEffect(Canvas canvas) {
    // Pulsing treatment aura
    final treatmentPulse = (sin(waveAnimation * 3) + 1) / 2;
    
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.green.withValues(alpha: 0.3 * treatmentPulse),
          Colors.lightGreen.withValues(alpha: 0.2 * treatmentPulse),
          Colors.green.withValues(alpha: 0),
        ],
      ).createShader(size.toRect());
    
    canvas.drawRect(size.toRect(), auraPaint);
    
    // Rising bubbles during treatment
    final bubblePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    
    final random = Random(row * 50 + col);
    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * size.x;
      final bubblePhase = (waveAnimation * 2 + i) % 2.0;
      final y = size.y - (bubblePhase / 2.0) * size.y;
      final opacity = (1.0 - bubblePhase / 2.0) * 0.7;
      
      if (y > 0 && y < size.y) {
        canvas.drawCircle(
          Offset(x, y),
          2 + random.nextDouble() * 2,
          bubblePaint..color = Colors.white.withValues(alpha: opacity),
        );
      }
    }
    
    // Treatment progress indicator (subtle glow around edges)
    final progressPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.5 * treatmentProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
      progressPaint,
    );
  }

  void _drawClearWaterEffects(Canvas canvas) {
    // Sparkles on clean water
    final sparklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    
    final random = Random(row * 5 + col);
    for (int i = 0; i < 4; i++) {
      final sparklePhase = (waveAnimation + i) % 1.0;
      final opacity = sin(sparklePhase * pi) * 0.8;
      
      if (opacity > 0.1) {
        final x = random.nextDouble() * size.x;
        final y = random.nextDouble() * size.y;
        
        // Draw star-shaped sparkle
        canvas.save();
        canvas.translate(x, y);
        
        final sparklePath = Path();
        for (int j = 0; j < 4; j++) {
          final angle = (j * pi / 2) + sparklePhase * pi;
          final length = 3 + sin(sparklePhase * pi * 2) * 2;
          
          if (j == 0) {
            sparklePath.moveTo(cos(angle) * length, sin(angle) * length);
          } else {
            sparklePath.lineTo(cos(angle) * length, sin(angle) * length);
          }
        }
        sparklePath.close();
        
        canvas.drawPath(
          sparklePath,
          sparklePaint..color = Colors.white.withValues(alpha: opacity),
        );
        canvas.restore();
      }
    }
    
    // Gentle bubbles in clear water
    final clearBubblePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 3; i++) {
      final x = (size.x / 4) * (i + 1);
      final floatY = sin(waveAnimation + i) * 5;
      final y = size.y * 0.7 + floatY;
      
      canvas.drawCircle(Offset(x, y), 2, clearBubblePaint);
    }
  }

  void _draw3DTileBorder(Canvas canvas) {
    Color borderColor;
    double glowIntensity = 0.3;
    
    if (isClear) {
      borderColor = Colors.cyan;
      glowIntensity = 0.5;
    } else if (isTreating) {
      borderColor = Colors.green;
      glowIntensity = 0.6 + (sin(waveAnimation * 3) * 0.2);
    } else if (isPolluted) {
      borderColor = Colors.red.shade700;
      glowIntensity = 0.4;
    } else {
      borderColor = Colors.white;
      glowIntensity = 0.2;
    }
    
    // Outer glow
    final glowPaint = Paint()
      ..color = borderColor.withValues(alpha: glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
      glowPaint,
    );
    
    // Inner border
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        size.toRect().deflate(1),
        const Radius.circular(4),
      ),
      borderPaint,
    );
  }

  void startTreatment() {
    if (isTreating || !isPolluted) return;
    
    isTreating = true;
    treatmentProgress = 0.0;
    
    // Generate bacteria particles
    bacteriaParticles.clear();
    final random = Random();
    
    for (int i = 0; i < 20; i++) {
      bacteriaParticles.add(
        BacteriaParticle(
          startPos: Vector2(
            size.x * random.nextDouble(),
            size.y * random.nextDouble(),
          ),
          tileSize: size,
        ),
      );
    }
    
    // Add particle system for dramatic effect
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 30,
          lifespan: 2.0,
          generator: (i) {
            final random = Random();
            return AcceleratedParticle(
              acceleration: Vector2(
                (random.nextDouble() - 0.5) * 20,
                -30 - random.nextDouble() * 20,
              ),
              child: CircleParticle(
                radius: 2 + random.nextDouble() * 2,
                paint: Paint()
                  ..shader = RadialGradient(
                    colors: [
                      Colors.green.withValues(alpha: 0.8),
                      Colors.lightGreen.withValues(alpha: 0.4),
                    ],
                  ).createShader(
                    Rect.fromCircle(center: Offset.zero, radius: 4),
                  ),
              ),
            );
          },
        ),
        position: Vector2(size.x / 2, size.y / 2),
      ),
    );
  }

  void completeTreatment() {
    isTreating = false;
    isPolluted = false;
    isClear = true;
    treatmentProgress = 0.0;
    pollutionDensity = 0.0;
    bacteriaParticles.clear();
    
    // Victory particle burst
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 40,
          lifespan: 1.5,
          generator: (i) {
            final random = Random();
            final angle = (i / 40) * 2 * pi;
            return AcceleratedParticle(
              acceleration: Vector2(
                cos(angle) * 80,
                sin(angle) * 80,
              ),
              child: CircleParticle(
                radius: 2 + random.nextDouble() * 3,
                paint: Paint()
                  ..shader = RadialGradient(
                    colors: [
                      Colors.cyan.withValues(alpha: 0.9),
                      Colors.blue.withValues(alpha: 0.5),
                    ],
                  ).createShader(
                    Rect.fromCircle(center: Offset.zero, radius: 5),
                  ),
              ),
            );
          },
        ),
        position: Vector2(size.x / 2, size.y / 2),
      ),
    );
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (isPolluted && !isTreating && game.bacteriaRemaining > 0) {
      game.treatTile(this);
    }
  }
}

// New class for bacteria particles
class BacteriaParticle {
  Vector2 position;
  late Vector2 velocity; // Changed to late
  double lifetime = 0.0;
  double maxLifetime;
  late Color color; // Changed to late
  double size;
  
  BacteriaParticle({
    required Vector2 startPos,
    required Vector2 tileSize,
  }) : position = startPos.clone(),
       maxLifetime = 1.5 + Random().nextDouble() * 0.5,
       size = 2 + Random().nextDouble() * 2 {
    
    // Random movement within tile
    final random = Random();
    velocity = Vector2(
      (random.nextDouble() - 0.5) * 30,
      (random.nextDouble() - 0.5) * 30,
    );
    
    // Bacteria colony colors
    final colors = [
      Colors.green.shade400,
      Colors.lightGreen.shade300,
      Colors.lime.shade400,
    ];
    color = colors[random.nextInt(colors.length)];
  }
  
  void update(double dt) {
    lifetime += dt;
    position += velocity * dt;
    
    // Fade as lifetime progresses
    if (lifetime > maxLifetime * 0.8) {
      final fadeProgress = (lifetime - maxLifetime * 0.8) / (maxLifetime * 0.2);
      color = color.withValues(alpha: 1.0 - fadeProgress);
    }
  }
  
  void render(Canvas canvas) {
    if (lifetime >= maxLifetime) return;
    
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: color.a * 0.9),
          color.withValues(alpha: color.a * 0.4),
          color.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(position.x, position.y), radius: size * 2),
      );
    
    canvas.drawCircle(
      Offset(position.x, position.y),
      size,
      paint,
    );
    
    // Add glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawCircle(
      Offset(position.x, position.y),
      size * 1.5,
      glowPaint,
    );
  }
}

class FarmZoneComponent extends PositionComponent {
  bool isIrrigated = false;
  bool cropsMature = false;
  String method = '';
  double growthProgress = 0.0;

  FarmZoneComponent({required super.position, required super.size});

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final plotPaint = Paint()
      ..color = isIrrigated ? const Color(0xFF8D6E63) : const Color(0xFFBCAAA4);

    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8)),
      plotPaint,
    );

    if (isIrrigated) {
      _drawCrops(canvas);
    }

    final borderPaint = Paint()
      ..color = Colors.brown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8)),
      borderPaint,
    );
  }

  void _drawCrops(Canvas canvas) {
    final cropColor = Color.lerp(
      const Color(0xFF81C784).withValues(alpha: 0.5),
      const Color(0xFF81C784),
      growthProgress,
    );

    final cropPaint = Paint()
      ..color = cropsMature
          ? const Color(0xFF4CAF50)
          : cropColor ?? const Color(0xFF81C784);

    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 4; j++) {
        final x = (size.x / 7) * (i + 1);
        final y = (size.y / 5) * (j + 1);
        final height = 10 * growthProgress;

        canvas.drawLine(
          Offset(x, y),
          Offset(x, y - height),
          cropPaint..strokeWidth = 2,
        );
      }
    }
  }

  void irrigate(String irrigationMethod) {
    method = irrigationMethod;
    isIrrigated = true;
    _startGrowth();
  }

  void _startGrowth() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (growthProgress < 1.0) {
        growthProgress += 0.017;
        if (growthProgress >= 1.0) {
          growthProgress = 1.0;
          cropsMature = true;
        }
        _startGrowth();
      }
    });
  }
}

class BinComponent extends PositionComponent with TapCallbacks {
  final String binType;
  late Color binColor;
  bool _showSuccessGlow = false;

  BinComponent({required this.binType, required super.position, super.size}) {
    size = size;
    binColor = _getBinColor(binType);
  }

  Color _getBinColor(String type) {
    switch (type) {
      case 'plastic':
        return Colors.blue;
      case 'metal':
        return Colors.grey;
      case 'hazardous':
        return Colors.red;
      case 'organic':
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  @override
  bool onTapDown(TapDownEvent event) {
    debugPrint('\n════════════════════════════════════');
    debugPrint('🗑️  BIN TAPPED');
    debugPrint('════════════════════════════════════');
    debugPrint('Bin type: $binType');
    debugPrint('Bin position: $position');
    debugPrint('Tap position: ${event.localPosition}');
    
    final game = parent;
    if (game is WaterPollutionGame) {
      if (game.selectedWaste != null) {
        debugPrint('Selected waste: ${game.selectedWaste!.type}');
        
        bool isCorrect = game.isCorrectBin(game.selectedWaste!.type, binType);
        debugPrint('Correct bin? ${isCorrect ? "YES ✓" : "NO ✗"}');
        
        if (isCorrect) {
          game.submitSort(game.selectedWaste!, this);
          game.selectedWaste = null;
          debugPrint('✅ Sort submitted');
        } else {
          triggerErrorAnimation();
          game.showWrongBinFeedback(game.selectedWaste!.type, binType);
          debugPrint('❌ Wrong bin');
        }
        
        debugPrint('════════════════════════════════════\n');
        return true;
      } else {
        debugPrint('❌ No waste selected');
      }
    }
    
    debugPrint('════════════════════════════════════\n');
    return false;
  }

  // Enhanced BinComponent with 3D visualization
  @override
  void render(Canvas canvas) {
    canvas.save();
    
    // 3D bin body with depth
    final binGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        binColor.lighten(0.3),
        binColor,
        binColor.darken(0.2),
        binColor.darken(0.4),
      ],
      stops: [0.0, 0.4, 0.7, 1.0],
    );
    
    // Shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    
    canvas.save();
    canvas.translate(4, 6);
    _drawBinShape(canvas, shadowPaint);
    canvas.restore();
    
    // Main bin body
    final binPaint = Paint()
      ..shader = binGradient.createShader(size.toRect());
    
    _drawBinShape(canvas, binPaint);
    
    // 3D lid with highlights
    _draw3DLid(canvas);
    
    // Recycling symbol with 3D effect
    _draw3DRecyclingSymbol(canvas);
    
    // Bin label with perspective
    _draw3DBinLabel(canvas);
    
    // Glow effect when correct item is sorted
    if (_showSuccessGlow) {
      _drawSuccessGlow(canvas);
    }
    
    canvas.restore();
  }

  void _drawBinShape(Canvas canvas, Paint paint) {
    final path = Path();
    
    // Trapezoidal bin shape for 3D effect
    path.moveTo(size.x * 0.2, 0);
    path.lineTo(size.x * 0.8, 0);
    path.lineTo(size.x * 0.9, size.y * 0.85);
    path.lineTo(size.x * 0.1, size.y * 0.85);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  void _draw3DLid(Canvas canvas) {
    final lidGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        binColor.lighten(0.4),
        binColor.lighten(0.2),
      ],
    );
    
    final lidPaint = Paint()
      ..shader = lidGradient.createShader(
        Rect.fromLTWH(size.x * 0.15, -size.y * 0.08, size.x * 0.7, size.y * 0.1),
      );
    
    // Lid shape with perspective
    final lidPath = Path();
    lidPath.moveTo(size.x * 0.15, -size.y * 0.08);
    lidPath.lineTo(size.x * 0.85, -size.y * 0.08);
    lidPath.lineTo(size.x * 0.82, size.y * 0.02);
    lidPath.lineTo(size.x * 0.18, size.y * 0.02);
    lidPath.close();
    
    canvas.drawPath(lidPath, lidPaint);
    
    // Lid handle
    final handlePaint = Paint()
      ..color = binColor.darken(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.42, -size.y * 0.12, size.x * 0.16, size.y * 0.06),
        const Radius.circular(4),
      ),
      handlePaint,
    );
  }

  void _draw3DRecyclingSymbol(Canvas canvas) {
    final symbolPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final symbolSize = size.x * 0.3;
    final centerX = size.x * 0.5;
    final centerY = size.y * 0.4;
    
    // Draw 3 arrows in recycling symbol
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate(i * (2 * pi / 3));
      
      final arrowPath = Path();
      arrowPath.moveTo(0, -symbolSize * 0.4);
      arrowPath.lineTo(symbolSize * 0.15, -symbolSize * 0.25);
      arrowPath.lineTo(symbolSize * 0.08, -symbolSize * 0.25);
      arrowPath.quadraticBezierTo(
        symbolSize * 0.1,
        0,
        0,
        symbolSize * 0.1,
      );
      arrowPath.lineTo(-symbolSize * 0.1, symbolSize * 0.05);
      arrowPath.quadraticBezierTo(
        0,
        -symbolSize * 0.15,
        -symbolSize * 0.08,
        -symbolSize * 0.25,
      );
      arrowPath.lineTo(-symbolSize * 0.15, -symbolSize * 0.25);
      arrowPath.close();
      
      canvas.drawPath(arrowPath, symbolPaint);
      canvas.restore();
    }
    
    // Add shine effect
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawCircle(
      Offset(centerX - symbolSize * 0.15, centerY - symbolSize * 0.15),
      symbolSize * 0.2,
      shinePaint,
    );
  }

  void _draw3DBinLabel(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: binType.toUpperCase(),
        style: GoogleFonts.exo2(
          color: Colors.white,
          fontSize: size.x * 0.12,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    // Draw with perspective
    canvas.save();
    canvas.translate(
      (size.x - textPainter.width) / 2,
      size.y * 0.65,
    );
    
    // Slight perspective skew
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(-0.1);
    
    canvas.transform(transform.storage);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawSuccessGlow(Canvas canvas) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.green.withValues(alpha: 0.6),
          Colors.green.withValues(alpha: 0.3),
          Colors.green.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.x / 2, size.y / 2),
          width: size.x * 1.5,
          height: size.y * 1.5,
        ),
      );
    
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x * 0.75,
      glowPaint,
    );
  }

  void triggerSuccessAnimation() {
    _showSuccessGlow = true;
    add(
      ScaleEffect.to(
        Vector2.all(1.15),
        EffectController(duration: 0.3, alternate: true),
        onComplete: () => _showSuccessGlow = false,
      ),
    );
    
    // Particle burst
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 15,
          lifespan: 1.0,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(
              (Random().nextDouble() - 0.5) * 200,
              -100 - Random().nextDouble() * 50,
            ),
            child: CircleParticle(
              radius: 3 + Random().nextDouble() * 3,
              paint: Paint()..color = Colors.green.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }

  void triggerErrorAnimation() {
    add(
      SequenceEffect([
        MoveEffect.by(
          Vector2(15, 0),
          EffectController(duration: 0.08),
        ),
        MoveEffect.by(
          Vector2(-30, 0),
          EffectController(duration: 0.08),
        ),
        MoveEffect.by(
          Vector2(15, 0),
          EffectController(duration: 0.08),
        ),
      ]),
    );
  }

  bool containsDrop(PositionComponent item) {
    // Use bin center and generous detection area
    final binCenter = position + Vector2(size.x / 2, size.y / 2);
    final distanceToCenter = (item.position - binCenter).length;
    
    // Accept drops within 70% of bin diagonal
    final acceptanceRadius = (size.x + size.y) * 0.7;
    
    return distanceToCenter < acceptanceRadius;
  }
}

class TreatmentFacilityBackground extends PositionComponent {
  double animationTime = 0.0;
  
  TreatmentFacilityBackground({required Vector2 size}) : super(size: size) {
    priority = -10;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    animationTime += dt;
  }
  
  @override
  void render(Canvas canvas) {
    // Laboratory/Treatment facility gradient background
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1A3A4A), // Dark blue-grey
        const Color(0xFF2A4A5A),
        const Color(0xFF1A3A4A),
      ],
      stops: [0.0, 0.5, 1.0],
    );
    
    canvas.drawRect(
      size.toRect(),
      Paint()..shader = bgGradient.createShader(size.toRect()),
    );
    
    // Grid pattern for scientific facility look
    _drawScientificGrid(canvas);
    
    // Equipment silhouettes in background
    _drawEquipmentSilhouettes(canvas);
    
    // Ambient light effects
    _drawAmbientLighting(canvas);
    
    // Status monitors on walls
    _drawStatusMonitors(canvas);
  }
  
  void _drawScientificGrid(Canvas canvas) {
    final gridPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // Vertical lines
    for (double x = 0; x < size.x; x += 40) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.y),
        gridPaint,
      );
    }
    
    // Horizontal lines
    for (double y = 0; y < size.y; y += 40) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.x, y),
        gridPaint,
      );
    }
  }
  
  void _drawEquipmentSilhouettes(Canvas canvas) {
    final equipmentPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3);
    
    // Large treatment tank (left side)
    final tankGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: 0.2),
        Colors.black.withValues(alpha: 0.4),
      ],
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, size.y * 0.2, 60, size.y * 0.6),
        const Radius.circular(10),
      ),
      Paint()..shader = tankGradient.createShader(
        Rect.fromLTWH(20, size.y * 0.2, 60, size.y * 0.6),
      ),
    );
    
    // Pipes
    final pipePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(50, size.y * 0.3),
      Offset(size.x * 0.2, size.y * 0.3),
      pipePaint,
    );
    
    // Control panel (right side)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x - 80, size.y * 0.15, 60, 100),
        const Radius.circular(8),
      ),
      equipmentPaint,
    );
    
    // Panel lights (blinking)
    final lightColors = [Colors.green, Colors.blue, Colors.red];
    for (int i = 0; i < 3; i++) {
      final blinkPhase = (animationTime * 2 + i) % 2.0;
      final opacity = blinkPhase > 1.0 ? 2.0 - blinkPhase : blinkPhase;
      
      canvas.drawCircle(
        Offset(size.x - 50, size.y * 0.15 + 30 + i * 20),
        3,
        Paint()..color = lightColors[i].withValues(alpha: opacity * 0.8),
      );
    }
  }
  
  void _drawAmbientLighting(Canvas canvas) {
    // Overhead lighting effect
    final lightPositions = [
      Offset(size.x * 0.3, 0),
      Offset(size.x * 0.7, 0),
    ];
    
    for (final lightPos in lightPositions) {
      final lightGradient = RadialGradient(
        center: Alignment(
          (lightPos.dx - size.x / 2) / (size.x / 2),
          -1.0,
        ),
        radius: 1.2,
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.cyan.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: [0.0, 0.4, 1.0],
      );
      
      canvas.drawRect(
        size.toRect(),
        Paint()..shader = lightGradient.createShader(size.toRect()),
      );
    }
    
    // Subtle animated light rays
    final rayPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 3; i++) {
      final rayOffset = sin(animationTime + i) * 20;
      final rayPath = Path();
      
      rayPath.moveTo(size.x * (0.3 + i * 0.2) + rayOffset, 0);
      rayPath.lineTo(size.x * (0.25 + i * 0.2) + rayOffset, size.y * 0.4);
      rayPath.lineTo(size.x * (0.35 + i * 0.2) + rayOffset, size.y * 0.4);
      rayPath.close();
      
      canvas.drawPath(rayPath, rayPaint);
    }
  }
  
  void _drawStatusMonitors(Canvas canvas) {
    // Monitor screens showing data
    final monitorPositions = [
      Rect.fromLTWH(size.x * 0.05, size.y * 0.05, size.x * 0.15, size.y * 0.1),
      Rect.fromLTWH(size.x * 0.8, size.y * 0.05, size.x * 0.15, size.y * 0.1),
    ];
    
    for (final monitorRect in monitorPositions) {
      // Monitor frame
      final framePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.5);
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(monitorRect, const Radius.circular(4)),
        framePaint,
      );
      
      // Screen glow
      final screenGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.green.withValues(alpha: 0.3),
          Colors.green.withValues(alpha: 0.1),
        ],
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          monitorRect.deflate(4),
          const Radius.circular(2),
        ),
        Paint()..shader = screenGradient.createShader(monitorRect),
      );
      
      // Animated scan lines
      final scanLinePaint = Paint()
        ..color = Colors.green.withValues(alpha: 0.2)
        ..strokeWidth = 1;
      
      final scanOffset = (animationTime * 50) % monitorRect.height;
      for (double y = 0; y < monitorRect.height; y += 4) {
        final lineY = monitorRect.top + ((y + scanOffset) % monitorRect.height);
        canvas.drawLine(
          Offset(monitorRect.left, lineY),
          Offset(monitorRect.right, lineY),
          scanLinePaint,
        );
      }
      
      // Fake data visualization
      final dataPaint = Paint()
        ..color = Colors.green.withValues(alpha: 0.6)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      final dataPath = Path();
      // FIXED: Use center.dy instead of centerY
      dataPath.moveTo(monitorRect.left + 8, monitorRect.center.dy);
      
      for (double x = 0; x < monitorRect.width - 16; x += 8) {
        final y = sin((animationTime + x / 10) * 2) * (monitorRect.height * 0.15);
        dataPath.lineTo(
          monitorRect.left + 8 + x,
          monitorRect.center.dy + y, // FIXED: Use center.dy instead of centerY
        );
      }
      
      canvas.drawPath(dataPath, dataPaint);
    }
  }
}

class TreatmentAmbientParticle extends PositionComponent {
  double lifetime = 0;
  final double maxLifetime = 6 + Random().nextDouble() * 4;
  final Color particleColor;
  final double particleSize;
  double opacity = 0.4;
  final Vector2 gameSize;
  final double floatSpeed;
  final double driftSpeed;
  
  TreatmentAmbientParticle({
    required super.position,
    required this.gameSize,
  }) : particleColor = [
          Colors.cyan.withValues(alpha: 0.3),
          Colors.lightBlue.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.2),
        ][Random().nextInt(3)],
        particleSize = 3 + Random().nextDouble() * 5,
        floatSpeed = 8 + Random().nextDouble() * 12,
        driftSpeed = 15 + Random().nextDouble() * 10 {
    priority = 5;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    lifetime += dt;
    
    // Gentle upward float
    position.y -= floatSpeed * dt;
    
    // Horizontal drift
    position.x += sin(lifetime * 2) * driftSpeed * dt;
    
    // Fade in and out
    if (lifetime < 1) {
      opacity = lifetime * 0.4;
    } else if (lifetime > maxLifetime - 2) {
      opacity = ((maxLifetime - lifetime) / 2) * 0.4;
    }
    
    // Reset when off screen or lifetime exceeded
    if (position.y < -20 || lifetime > maxLifetime) {
      position.y = gameSize.y + 20;
      position.x = Random().nextDouble() * gameSize.x;
      lifetime = 0;
    }
    
    // Wrap around horizontally
    if (position.x < -20) {
      position.x = gameSize.x + 20;
    } else if (position.x > gameSize.x + 20) {
      position.x = -20;
    }
  }
  
  @override
  void render(Canvas canvas) {
    // Main particle with glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          particleColor.withValues(alpha: opacity * 0.8),
          particleColor.withValues(alpha: opacity * 0.4),
          particleColor.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: particleSize * 2),
      );
    
    canvas.drawCircle(Offset.zero, particleSize * 1.5, glowPaint);
    
    // Core particle
    final corePaint = Paint()
      ..color = particleColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset.zero, particleSize * 0.6, corePaint);
    
    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.6);
    
    canvas.drawCircle(
      Offset(-particleSize * 0.2, -particleSize * 0.2),
      particleSize * 0.3,
      highlightPaint,
    );
  }
}

// Enhanced bacteria indicator component for UI
class BacteriaIndicatorComponent extends PositionComponent {
  int bacteriaCount;
  bool isPulsing = false;
  double pulseAnimation = 0.0;
  
  BacteriaIndicatorComponent({
    required super.position,
    required super.size,
    required this.bacteriaCount,
  }) {
    priority = 300;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (isPulsing) {
      pulseAnimation += dt * 4;
      if (pulseAnimation >= 1.0) {
        pulseAnimation = 0.0;
        isPulsing = false;
      }
    }
  }
  
  @override
  void render(Canvas canvas) {
    canvas.save();
    
    // Container background
    final containerGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.green.shade800.withValues(alpha: 0.8),
        Colors.green.shade900.withValues(alpha: 0.9),
      ],
    );
    
    final containerPaint = Paint()
      ..shader = containerGradient.createShader(size.toRect());
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12)),
      containerPaint,
    );
    
    // Pulse effect when bacteria used
    if (isPulsing) {
      final pulsePaint = Paint()
        ..color = Colors.green.withValues(alpha: (1.0 - pulseAnimation) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          size.toRect().inflate(pulseAnimation * 10),
          const Radius.circular(12),
        ),
        pulsePaint,
      );
    }
    
    // Border
    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12)),
      borderPaint,
    );
    
    // Bacteria icon (simplified microorganism)
    _drawBacteriaIcon(canvas, size.x * 0.25, size.y * 0.5);
    
    // Count text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'x$bacteriaCount',
        style: GoogleFonts.exo2(
          fontSize: size.y * 0.4,
          color: Colors.white,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(
        size.x * 0.45,
        (size.y - textPainter.height) / 2,
      ),
    );
    
    canvas.restore();
  }
  
  void _drawBacteriaIcon(Canvas canvas, double x, double y) {
    // Main bacteria body
    final bodyGradient = RadialGradient(
      colors: [
        Colors.lightGreen.shade300,
        Colors.green.shade400,
        Colors.green.shade600,
      ],
      stops: [0.0, 0.6, 1.0],
    );
    
    final bodyPaint = Paint()
      ..shader = bodyGradient.createShader(
        Rect.fromCircle(center: Offset(x, y), radius: size.y * 0.25),
      );
    
    // Elongated bacteria shape
    final bacteriaPath = Path();
    bacteriaPath.addOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: size.y * 0.3,
        height: size.y * 0.45,
      ),
    );
    
    canvas.drawPath(bacteriaPath, bodyPaint);
    
    // Flagella (tail-like structures)
    final flagellaPaint = Paint()
      ..color = Colors.green.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    for (int i = 0; i < 3; i++) {
      final flagellaPath = Path();
      final startX = x + (i - 1) * 3;
      final startY = y + size.y * 0.2;
      
      flagellaPath.moveTo(startX, startY);
      flagellaPath.quadraticBezierTo(
        startX + (i - 1) * 4,
        startY + 6,
        startX + (i - 1) * 2,
        startY + 12,
      );
      
      canvas.drawPath(flagellaPath, flagellaPaint);
    }
    
    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6);
    
    canvas.drawCircle(
      Offset(x - size.y * 0.08, y - size.y * 0.08),
      size.y * 0.08,
      highlightPaint,
    );
  }
  
  void triggerPulse() {
    isPulsing = true;
    pulseAnimation = 0.0;
  }
  
  void updateCount(int newCount) {
    if (newCount < bacteriaCount) {
      triggerPulse();
    }
    bacteriaCount = newCount;
  }
}

class PipeComponent extends PositionComponent
    with HasGameReference<WaterPollutionGame>, TapCallbacks {
  int rotationState = 0; // 0-3 for 90 deg rotations
  String pipeType; // 'straight', 'corner', 't', etc.

  PipeComponent({
    required super.position,
    required this.pipeType,
    required super.size,
  }) {
    angle = rotationState * pi / 2;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.blueGrey;
    // Draw based on pipeType
    switch (pipeType) {
      case 'straight':
        canvas.drawRect(
          Rect.fromLTWH(0, size.y * 0.4, size.x, size.y * 0.2),
          paint,
        );
        break;
      case 'corner':
        final path = Path()
          ..moveTo(0, size.y / 2)
          ..lineTo(size.x / 2, size.y / 2)
          ..lineTo(size.x / 2, size.y);
        canvas.drawPath(
          path,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.y * 0.2,
        );
        break;
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    rotationState = (rotationState + 1) % 4;
    angle = rotationState * pi / 2;
    game.checkPipelineConnection();
  }
}

class WildlifeComponent extends SpriteAnimationComponent
    with HasGameReference<WaterPollutionGame> {
  WildlifeComponent({required super.position, required super.size});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      final image = await game.images.load('wildlife.png');
      animation = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.1,
          textureSize: Vector2(32, 32),
        ),
      );
    } catch (e) {
      // If image not found, create a simple placeholder
      debugPrint('Wildlife image not found: $e');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += 50 * dt;
    if (position.x > game.size.x) removeFromParent();
  }
}

class RiverBackgroundComponent extends PositionComponent {
  double animationOffset = 0.0;
  late List<WaveLayer> waveLayers;
  
  RiverBackgroundComponent({required Vector2 size}) : super(size: size) {
    priority = -10;
    
    // Create multiple wave layers for depth
    waveLayers = [
      WaveLayer(
        color: const Color(0xFF4A7C8F),
        amplitude: 8,
        frequency: 0.8,
        speed: 0.3,
        yOffset: 0,
      ),
      WaveLayer(
        color: const Color(0xFF5A8C9F),
        amplitude: 12,
        frequency: 1.2,
        speed: 0.5,
        yOffset: 20,
      ),
      WaveLayer(
        color: const Color(0xFF6A9CAF),
        amplitude: 6,
        frequency: 1.5,
        speed: 0.7,
        yOffset: 40,
      ),
    ];
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    animationOffset += dt;
  }
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Base polluted water color gradient
    final baseGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF2E4A5A), // Darker polluted top
        const Color(0xFF4A6A7A), // Mid tone
        const Color(0xFF5A7A8A), // Lighter polluted bottom
      ],
    );
    
    final basePaint = Paint()
      ..shader = baseGradient.createShader(size.toRect());
    
    canvas.drawRect(size.toRect(), basePaint);
    
    // Draw animated wave layers
    for (final layer in waveLayers) {
      _drawWaveLayer(canvas, layer);
    }
    
    // Add foam patches for realism
    _drawFoamPatches(canvas);
    
    // Add pollution discoloration patches
    _drawPollutionPatches(canvas);
  }
  
  void _drawWaveLayer(Canvas canvas, WaveLayer layer) {
    final wavePaint = Paint()
      ..color = layer.color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    
    final wavePath = Path();
    wavePath.moveTo(0, size.y);
    
    final segments = 50;
    for (int i = 0; i <= segments; i++) {
      final x = (size.x / segments) * i;
      final phase = (animationOffset * layer.speed) + (i / segments) * layer.frequency * 2 * pi;
      final y = layer.yOffset + sin(phase) * layer.amplitude;
      
      if (i == 0) {
        wavePath.lineTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
    }
    
    wavePath.lineTo(size.x, size.y);
    wavePath.close();
    
    canvas.drawPath(wavePath, wavePaint);
  }
  
  void _drawFoamPatches(Canvas canvas) {
    final foamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    
    final random = Random(42); // Fixed seed for consistent placement
    
    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.x;
      final y = random.nextDouble() * size.y;
      final baseRadius = 15 + random.nextDouble() * 20;
      
      // Animated foam movement
      final animX = x + sin(animationOffset * 0.5 + i) * 10;
      final animY = y + cos(animationOffset * 0.3 + i) * 8;
      
      // Draw irregular foam patch
      for (int j = 0; j < 5; j++) {
        final offsetX = (random.nextDouble() - 0.5) * baseRadius;
        final offsetY = (random.nextDouble() - 0.5) * baseRadius * 0.6;
        final radius = baseRadius * (0.3 + random.nextDouble() * 0.4);
        
        canvas.drawCircle(
          Offset(animX + offsetX, animY + offsetY),
          radius,
          foamPaint..color = Colors.white.withValues(
            alpha: 0.15 + random.nextDouble() * 0.15,
          ),
        );
      }
    }
  }
  
  void _drawPollutionPatches(Canvas canvas) {
    final pollutionPaint = Paint()
      ..style = PaintingStyle.fill;
    
    final random = Random(123); // Fixed seed
    
    for (int i = 0; i < 10; i++) {
      final x = random.nextDouble() * size.x;
      final y = random.nextDouble() * size.y;
      
      final colors = [
        Colors.brown.shade700.withValues(alpha: 0.3),
        Colors.grey.shade700.withValues(alpha: 0.25),
        Colors.green.shade900.withValues(alpha: 0.2),
      ];
      
      final gradient = RadialGradient(
        colors: [
          colors[i % colors.length],
          colors[i % colors.length].withValues(alpha: 0),
        ],
      );
      
      pollutionPaint.shader = gradient.createShader(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 80 + random.nextDouble() * 60,
          height: 60 + random.nextDouble() * 40,
        ),
      );
      
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 80 + random.nextDouble() * 60,
          height: 60 + random.nextDouble() * 40,
        ),
        pollutionPaint,
      );
    }
  }
}

class WaveLayer {
  final Color color;
  final double amplitude;
  final double frequency;
  final double speed;
  final double yOffset;
  
  WaveLayer({
    required this.color,
    required this.amplitude,
    required this.frequency,
    required this.speed,
    required this.yOffset,
  });
}

class RiverParticleComponent extends PositionComponent {
  double lifetime = 0;
  final double maxLifetime = 8 + Random().nextDouble() * 4;
  final Color particleColor;
  final double particleSize;
  double opacity = 0.6;
  
  RiverParticleComponent({required super.position})
      : particleColor = [
          Colors.white.withValues(alpha: 0.4),
          Colors.blue.shade200.withValues(alpha: 0.3),
          Colors.grey.shade300.withValues(alpha: 0.35),
        ][Random().nextInt(3)],
        particleSize = 2 + Random().nextDouble() * 4 {
    priority = 5;
  }
    
  @override
  void update(double dt) {
    super.update(dt);
    
    lifetime += dt;
    
    // Gentle float movement
    position.y += 15 * dt;
    position.x += sin(lifetime * 2) * 20 * dt;
    
    // Fade in and out
    if (lifetime < 1) {
      opacity = lifetime * 0.6;
    } else if (lifetime > maxLifetime - 1) {
      opacity = (maxLifetime - lifetime) * 0.6;
    }
    
    // Reset when off screen or lifetime exceeded
    final parentComponent = parent;
    if (parentComponent != null && parentComponent is PositionComponent) {
      if (position.y > parentComponent.size.y || lifetime > maxLifetime) {
        position.y = -10;
        position.x = Random().nextDouble() * parentComponent.size.x;
        lifetime = 0;
      }
    }
  }
  
  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = particleColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset.zero, particleSize, paint);
    
    // Add glow effect
    final glowPaint = Paint()
      ..color = particleColor.withValues(alpha: opacity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    canvas.drawCircle(Offset.zero, particleSize * 1.5, glowPaint);
  }
}

class SortingFacilityBackground extends PositionComponent {
  SortingFacilityBackground({required Vector2 size}) : super(size: size) {
    priority = -10;
  }
  
  @override
  void render(Canvas canvas) {
    // Industrial floor
    final floorGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF4A4A4A),
        const Color(0xFF2A2A2A),
      ],
    );
    
    canvas.drawRect(
      size.toRect(),
      Paint()..shader = floorGradient.createShader(size.toRect()),
    );
    
    // Floor tiles
    final tilePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    for (double i = 0; i < size.x; i += 60) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.y),
        tilePaint,
      );
    }
    
    for (double i = 0; i < size.y; i += 60) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.x, i),
        tilePaint,
      );
    }
    
    // Facility walls with industrial look
    _drawWalls(canvas);
    
    // Lighting effects
    _drawLighting(canvas);
  }
  
  void _drawWalls(Canvas canvas) {
    final wallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6A6A6A),
          const Color(0xFF4A4A4A),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y * 0.15));
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y * 0.15),
      wallPaint,
    );
  }
  
  void _drawLighting(Canvas canvas) {
    final lightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.x / 2, size.y * 0.1),
          width: size.x * 0.6,
          height: size.y * 0.4,
        ),
      );
    
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y * 0.1),
        width: size.x * 0.6,
        height: size.y * 0.4,
      ),
      lightPaint,
    );
  }
}

class ConveyorBeltComponent extends PositionComponent {
  double animationOffset = 0.0;
  
  ConveyorBeltComponent({required super.position, required super.size}) {
    priority = 0;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    animationOffset += dt * 30; // Belt speed
    if (animationOffset > 40) animationOffset = 0;
  }
  
  @override
  void render(Canvas canvas) {
    // Belt body with metallic look
    final beltGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF3A3A3A),
        const Color(0xFF2A2A2A),
        const Color(0xFF3A3A3A),
      ],
      stops: [0.0, 0.5, 1.0],
    );
    
    final beltPaint = Paint()
      ..shader = beltGradient.createShader(size.toRect());
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        size.toRect(),
        const Radius.circular(8),
      ),
      beltPaint,
    );
    
    // Animated belt lines
    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 3;
    
    for (double i = -animationOffset; i < size.x + 40; i += 40) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.y),
        linePaint,
      );
    }
    
    // Belt edges with highlights
    final edgePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.2),
          Colors.black.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.x, 10));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 10), edgePaint);
    canvas.drawRect(Rect.fromLTWH(0, size.y - 10, size.x, 10), edgePaint);
    
    // Rollers at edges
    _drawRoller(canvas, 20, size.y / 2);
    _drawRoller(canvas, size.x - 20, size.y / 2);
  }
  
  void _drawRoller(Canvas canvas, double x, double y) {
    final rollerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF5A5A5A),
          const Color(0xFF2A2A2A),
        ],
      ).createShader(
        Rect.fromCenter(center: Offset(x, y), width: 40, height: 40),
      );
    
    canvas.drawCircle(Offset(x, y), 20, rollerPaint);
    
    // Roller shine
    canvas.drawCircle(
      Offset(x - 5, y - 5),
      8,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
  }
}