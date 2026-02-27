// rowing_components.dart
// Enhanced Phase 1: Realistic rowing boat, river challenges, waste collection
// Drop-in replacement / extension for water_components.dart Phase 1 elements

import 'dart:math';
import 'package:ecoquest/game/water_pollution_game.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/effects.dart';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ENUMS & CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

enum RowingStroke { left, right, none }

enum CrocodileState { lurking, surfacing, snapping, retreating, submerged }

enum ObstacleType { crocodile, whirlpool, logJam, oilPatch, rapidsCurrent }

enum WasteType {
  plasticBottle,
  metalCan,
  plasticBag,
  oilSlick,
  organicWaste,
  metalScrap,
}

extension WasteTypeExt on WasteType {
  String get label {
    switch (this) {
      case WasteType.plasticBottle:
        return 'Plastic Bottle';
      case WasteType.metalCan:
        return 'Metal Can';
      case WasteType.plasticBag:
        return 'Plastic Bag';
      case WasteType.oilSlick:
        return 'Oil Slick';
      case WasteType.organicWaste:
        return 'Organic Waste';
      case WasteType.metalScrap:
        return 'Metal Scrap';
    }
  }

  String get gameKey {
    switch (this) {
      case WasteType.plasticBottle:
        return 'plastic_bottle';
      case WasteType.metalCan:
        return 'can';
      case WasteType.plasticBag:
        return 'bag';
      case WasteType.oilSlick:
        return 'oil_slick';
      case WasteType.organicWaste:
        return 'wood';
      case WasteType.metalScrap:
        return 'metal_scrap';
    }
  }

  Color get color {
    switch (this) {
      case WasteType.plasticBottle:
        return const Color(0xFF1565C0);
      case WasteType.metalCan:
        return const Color(0xFF78909C);
      case WasteType.plasticBag:
        return const Color(0xFFE0E0E0);
      case WasteType.oilSlick:
        return const Color(0xFF1A1A1A);
      case WasteType.organicWaste:
        return const Color(0xFF6D4C41);
      case WasteType.metalScrap:
        return const Color(0xFF546E7A);
    }
  }

  int get points {
    switch (this) {
      case WasteType.oilSlick:
        return 15; // Hardest to collect
      case WasteType.metalScrap:
        return 12;
      case WasteType.metalCan:
        return 8;
      case WasteType.plasticBottle:
        return 6;
      case WasteType.plasticBag:
        return 5;
      case WasteType.organicWaste:
        return 4;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROWING BOAT (replaces SpeedboatComponent for Phase 1)
// ─────────────────────────────────────────────────────────────────────────────

/// A realistic 2D rowing boat seen from above/side-perspective.
/// Player steers with on-screen joystick or keyboard.
/// Rowing animation syncs with movement — alternating left/right paddle strokes.
class RowingBoatComponent extends PositionComponent
    with HasGameReference<WaterPollutionGame>, KeyboardHandler {
  // ── Movement ──────────────────────────────────────────────────────────────
  Vector2 velocity = Vector2.zero();
  Vector2 targetVelocity = Vector2.zero();
  double boatAngle = 0.0; // radians, 0 = pointing up/north
  double angularVelocity = 0.0;
  static const double maxSpeed = 280.0;
  static const double acceleration = 520.0;
  static const double drag = 0.82;
  static const double angularDrag = 0.55;     // low drag = angular velocity sticks longer
  static const double turnRate = 4.5;         // radians/sec applied directly to boatAngle when key held
  static const double maxAngularVelocity = 6.0; // cap so it doesn't spin out
  bool isMoving = false;

  // ── Rowing animation ──────────────────────────────────────────────────────
  RowingStroke currentStroke = RowingStroke.none;
  double strokeTimer = 0.0;
  static const double strokeDuration = 0.45; // seconds per half-stroke
  double strokePhase = 0.0; // 0..1 within a stroke
  bool leftOarForward = true;

  // ── Net casting ───────────────────────────────────────────────────────────
  bool netDeployed = false;
  double netTimer = 0.0;
  static const double netDuration = 1.8;
  double netRadius = 0.0;
  static const double maxNetRadius = 65.0;

  // ── Visual / bob ─────────────────────────────────────────────────────────
  double bobOffset = 0.0;
  List<Vector2> wakeTrail = [];
  double wakeTimer = 0.0;

  // ── Health & stamina ─────────────────────────────────────────────────────
  double health = 100.0; // reduced by obstacles
  double stunTimer = 0.0; // seconds of stun after croc hit

  // ── Keyboard state ────────────────────────────────────────────────────────
  final Set<LogicalKeyboardKey> _heldKeys = {};
  /// Tracks keys that fired a KeyDown this frame so we can apply an
  /// immediate angular impulse before the continuous per-frame accumulation.
  final Set<LogicalKeyboardKey> _justPressedKeys = {};

  RowingBoatComponent({required super.position, required super.size}) {
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    priority = 100;
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    // If stunned, apply heavy drag only
    if (stunTimer > 0) {
      stunTimer -= dt;
      velocity *= pow(drag, dt * 60).toDouble();
      position += velocity * dt;
      _clampToBounds();
      return;
    }

    // ── Input to angular + forward velocity ──────────────────────────────
    double turnInput = 0.0;
    double forwardInput = 0.0;

    // ── Keyboard: instant impulse on first press, then continuous hold ────
    final bool leftHeld = _heldKeys.contains(LogicalKeyboardKey.arrowLeft) ||
        _heldKeys.contains(LogicalKeyboardKey.keyA);
    final bool rightHeld = _heldKeys.contains(LogicalKeyboardKey.arrowRight) ||
        _heldKeys.contains(LogicalKeyboardKey.keyD);
    final bool upHeld = _heldKeys.contains(LogicalKeyboardKey.arrowUp) ||
        _heldKeys.contains(LogicalKeyboardKey.keyW);
    final bool downHeld = _heldKeys.contains(LogicalKeyboardKey.arrowDown) ||
        _heldKeys.contains(LogicalKeyboardKey.keyS);

    if (leftHeld) turnInput = -1.0;
    if (rightHeld) turnInput = 1.0;
    if (upHeld) forwardInput = 1.0;
    if (downHeld) forwardInput = -0.5;

    // Instant angular impulse on the very first frame a turn key is pressed
    if (_justPressedKeys.contains(LogicalKeyboardKey.arrowLeft) ||
        _justPressedKeys.contains(LogicalKeyboardKey.keyA)) {
      angularVelocity -= turnRate * 0.6;
    }
    if (_justPressedKeys.contains(LogicalKeyboardKey.arrowRight) ||
        _justPressedKeys.contains(LogicalKeyboardKey.keyD)) {
      angularVelocity += turnRate * 0.6;
    }
    if (_justPressedKeys.contains(LogicalKeyboardKey.arrowUp) ||
        _justPressedKeys.contains(LogicalKeyboardKey.keyW)) {
      final fwd = Vector2(sin(boatAngle), -cos(boatAngle));
      velocity += fwd * (acceleration * 0.25);
    }
    _justPressedKeys.clear();

    // ── Direct boatAngle rotation while key is held ───────────────────────
    // The boat turns at a fixed rate the instant and every frame a key is
    // held, giving zero-lag keyboard / D-pad turning.
    if (leftHeld) boatAngle -= turnRate * dt;
    if (rightHeld) boatAngle += turnRate * dt;

    // ── Apply physics ─────────────────────────────────────────────────────
    // angularVelocity is now only used for drag-steering and impulse inertia.
    // Keyboard turning writes directly to boatAngle above — no ramp needed.
    angularVelocity = angularVelocity.clamp(-maxAngularVelocity, maxAngularVelocity);
    angularVelocity *= pow(angularDrag, dt * 60).toDouble();
    boatAngle += angularVelocity * dt;

    final forwardDir =
        Vector2(sin(boatAngle), -cos(boatAngle)); // boat nose direction
    if (forwardInput.abs() > 0.01) {
      velocity += forwardDir * (forwardInput * acceleration * dt);
    }
    velocity *= pow(drag, dt * 60).toDouble();

    final speed = velocity.length;
    isMoving = speed > 5;
    if (speed > maxSpeed) velocity = velocity.normalized() * maxSpeed;

    // Notify game to start the countdown on the very first movement
    if (isMoving || turnInput.abs() > 0.01) {
      game.notifyPlayerStarted();
    }

    position += velocity * dt;
    _clampToBounds();

    // ── Wake trail ────────────────────────────────────────────────────────
    wakeTimer += dt;
    if (isMoving && wakeTimer > 0.06) {
      wakeTimer = 0;
      wakeTrail.add(position.clone());
      if (wakeTrail.length > 20) wakeTrail.removeAt(0);
    }

    // ── Bob / water rocking ───────────────────────────────────────────────
    bobOffset += dt * 1.8;

    // ── Rowing stroke animation ───────────────────────────────────────────
    if (isMoving) {
      strokeTimer += dt;
      if (strokeTimer >= strokeDuration) {
        strokeTimer = 0;
        leftOarForward = !leftOarForward;
        currentStroke =
            leftOarForward ? RowingStroke.left : RowingStroke.right;
      }
      strokePhase = strokeTimer / strokeDuration;
    } else {
      strokePhase = 0;
      currentStroke = RowingStroke.none;
      strokeTimer = 0;
    }

    // ── Net timer ─────────────────────────────────────────────────────────
    if (netDeployed) {
      netTimer += dt;
      // Expand then hold then retract
      final halfTime = netDuration * 0.4;
      if (netTimer < halfTime) {
        netRadius = maxNetRadius * (netTimer / halfTime);
      } else if (netTimer < netDuration * 0.7) {
        netRadius = maxNetRadius;
        _checkNetCollision(); // Active sweep window
      } else {
        netRadius = maxNetRadius * (1.0 - (netTimer - netDuration * 0.7) /
            (netDuration * 0.3));
      }
      if (netTimer >= netDuration) {
        netDeployed = false;
        netTimer = 0;
        netRadius = 0;
        // Notify HUD: net retracted, cooldown begins
        game.onNetStateChanged?.call(false, 1.0);
      }
    }
  }

  void _clampToBounds() {
    final half = size / 2;
    position.x = position.x.clamp(half.x + 10, game.size.x - half.x - 10);
    position.y = position.y.clamp(half.y + 10, game.size.y - half.y - 10);
  }

  void _checkNetCollision() {
    final wasteCopy = List<FloatingWasteComponent>.from(
        game.children.whereType<FloatingWasteComponent>());
    for (final w in wasteCopy) {
      if ((w.position - position).length < netRadius + w.size.x / 2) {
        game.collectFloatingWaste(w);
      }
    }
  }

  // ── Damage ─────────────────────────────────────────────────────────────

  void takeDamage(double amount) {
    health = (health - amount).clamp(0, 100);
    stunTimer = 0.3;  // was 0.8 — short stun so player can react and escape immediately
    // Light knockback — preserves some momentum so the player can steer away
    velocity = velocity * 0.4 + velocity.normalized() * -40;
  }

  // ─── Rendering ────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Wake trail drawn in world space via parent; here local rendering
    _drawBoat(canvas);
    if (netDeployed && netRadius > 2) _drawNet(canvas);
  }

  void _drawBoat(Canvas canvas) {
    canvas.save();
    final cx = size.x / 2;
    final cy = size.y / 2;
    canvas.translate(cx, cy);
    canvas.rotate(boatAngle);

    // ── Gentle water rocking ──────────────────────────────────────────────
    canvas.rotate(sin(bobOffset) * 0.04);
    canvas.translate(0, sin(bobOffset * 0.7) * 1.5);

    // ── Shadow ────────────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(Rect.fromCenter(center: const Offset(3, 6),
        width: size.x * 0.85, height: size.y * 0.6), shadowPaint);

    // ── Hull (dark wood + green) ──────────────────────────────────────────
    final hullPath = _buildHullPath();

    // Outer hull — dark forest green
    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF1B5E20), const Color(0xFF2E7D32),
          const Color(0xFF1B5E20)],
      ).createShader(Rect.fromLTWH(-cx, -cy, size.x, size.y));
    canvas.drawPath(hullPath, outerPaint);

    // Hull edge highlight
    final edgePaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(hullPath, edgePaint);

    // ── Inner deck (wood planks) ──────────────────────────────────────────
    final deckPath = Path()
      ..moveTo(0, -cy * 0.65)
      ..lineTo(cx * 0.6, -cy * 0.3)
      ..lineTo(cx * 0.6, cy * 0.55)
      ..lineTo(-cx * 0.6, cy * 0.55)
      ..lineTo(-cx * 0.6, -cy * 0.3)
      ..close();
    final deckPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFA1887F), const Color(0xFF795548),
          const Color(0xFF5D4037)],
      ).createShader(Rect.fromLTWH(-cx * 0.65, -cy * 0.7, size.x * 0.65, size.y * 1.25));
    canvas.drawPath(deckPath, deckPaint);

    // Plank lines
    final plankPaint = Paint()
      ..color = Colors.brown.shade900.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (double py = -cy * 0.2; py < cy * 0.5; py += 8) {
      canvas.drawLine(
          Offset(-cx * 0.55, py), Offset(cx * 0.55, py), plankPaint);
    }

    // ── Seat bench ────────────────────────────────────────────────────────
    final seatPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-cx * 0.5, -cy * 0.05, size.x * 0.5, size.y * 0.12),
          const Radius.circular(3)),
      seatPaint,
    );

    // ── Rower silhouette ─────────────────────────────────────────────────
    _drawRower(canvas, cx, cy);

    // ── Oars ──────────────────────────────────────────────────────────────
    _drawOars(canvas, cx, cy);

    // ── Bow (prow) decoration ─────────────────────────────────────────────
    final bowPaint = Paint()..color = const Color(0xFFF9A825);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(0, -cy + 4), width: 10, height: 6),
        bowPaint);

    canvas.restore();
  }

  Path _buildHullPath() {
    final cx = size.x / 2;
    final cy = size.y / 2;
    return Path()
      ..moveTo(0, -cy) // bow/nose
      ..cubicTo(cx * 0.3, -cy * 0.8, cx * 0.75, -cy * 0.4, cx * 0.8, 0)
      ..cubicTo(cx * 0.75, cy * 0.55, cx * 0.4, cy * 0.85, 0, cy) // stern
      ..cubicTo(-cx * 0.4, cy * 0.85, -cx * 0.75, cy * 0.55, -cx * 0.8, 0)
      ..cubicTo(-cx * 0.75, -cy * 0.4, -cx * 0.3, -cy * 0.8, 0, -cy)
      ..close();
  }

  void _drawRower(Canvas canvas, double cx, double cy) {
    // Body
    final bodyPaint = Paint()..color = const Color(0xFF1565C0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-8, -cy * 0.08, 16, 18), const Radius.circular(4)),
      bodyPaint,
    );
    // Head
    final headPaint = Paint()..color = const Color(0xFFFFB74D);
    canvas.drawCircle(Offset(0, -cy * 0.08 - 9), 7, headPaint);
    // Hat
    final hatPaint = Paint()..color = const Color(0xFFFF8F00);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(0, -cy * 0.08 - 16), width: 16, height: 6),
        hatPaint);
  }

  void _drawOars(Canvas canvas, double cx, double cy) {
    final oarShaftPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final bladePaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;

    // Left oar
    final leftSwing = leftOarForward
        ? _swingAngle(true)
        : _swingAngle(false);
    _drawSingleOar(canvas, cx, cy, isLeft: true, swingAngle: leftSwing,
        shaftPaint: oarShaftPaint, bladePaint: bladePaint);

    // Right oar (opposite phase)
    final rightSwing = leftOarForward
        ? _swingAngle(false)
        : _swingAngle(true);
    _drawSingleOar(canvas, cx, cy, isLeft: false, swingAngle: rightSwing,
        shaftPaint: oarShaftPaint, bladePaint: bladePaint);
  }

  double _swingAngle(bool isForward) {
    // isForward = this oar is currently sweeping forward through water
    const range = 0.7; // radians of swing
    if (isForward) {
      return -range / 2 + strokePhase * range;
    } else {
      return range / 2 - strokePhase * range;
    }
  }

  void _drawSingleOar(Canvas canvas, double cx, double cy,
      {required bool isLeft,
      required double swingAngle,
      required Paint shaftPaint,
      required Paint bladePaint}) {
    canvas.save();
    final pivotX = isLeft ? -cx * 0.65 : cx * 0.65;
    canvas.translate(pivotX, -cy * 0.08);
    canvas.rotate(isLeft ? swingAngle : -swingAngle);

    final shaftLength = size.y * 0.95;
    final dir = isLeft ? -1.0 : 1.0;

    // Shaft
    canvas.drawLine(
        Offset(0, 0), Offset(dir * shaftLength * 0.55, shaftLength * 0.4),
        shaftPaint);

    // Blade
    canvas.save();
    canvas.translate(dir * shaftLength * 0.55, shaftLength * 0.4);
    canvas.rotate(isLeft ? 0.4 : -0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(isLeft ? -14 : -2, 0, 16, 22),
          const Radius.circular(4)),
      bladePaint,
    );
    canvas.restore();

    canvas.restore();
  }

  void _drawNet(Canvas canvas) {
    canvas.save();
    final cx = size.x / 2;
    final cy = size.y / 2;
    canvas.translate(cx, cy);
    canvas.rotate(boatAngle);

    // Net cast in front of boat (toward bow)
    final netCx = 0.0;
    final netCy = -cy - netRadius * 0.6;

    final gradient = RadialGradient(
      colors: [
        Colors.amber.withValues(alpha: 0.55),
        Colors.orange.withValues(alpha: 0.25),
        Colors.orange.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(
        center: Offset(netCx, netCy), radius: netRadius));

    final fillPaint = Paint()..shader = gradient;
    canvas.drawCircle(Offset(netCx, netCy), netRadius, fillPaint);

    // Mesh lines
    final meshPaint = Paint()
      ..color = Colors.orange.shade700.withValues(alpha: 0.7)
      ..strokeWidth = 1.4;

    final steps = 8;
    for (int i = 0; i < steps; i++) {
      final ang = (i / steps) * pi * 2;
      canvas.drawLine(
          Offset(netCx, netCy),
          Offset(netCx + cos(ang) * netRadius, netCy + sin(ang) * netRadius),
          meshPaint);
    }
    for (double r = netRadius * 0.3; r <= netRadius; r += netRadius * 0.3) {
      canvas.drawCircle(Offset(netCx, netCy), r,
          meshPaint..style = PaintingStyle.stroke);
    }

    // Rope from boat to net
    final ropePaint = Paint()
      ..color = Colors.brown.shade600
      ..strokeWidth = 2.0;
    canvas.drawLine(const Offset(0, -20), Offset(netCx, netCy + netRadius * 0.5),
        ropePaint);

    // Floats
    final floatPaint = Paint()..color = Colors.red;
    for (int i = 0; i < 6; i++) {
      final ang = (i / 6) * pi * 2;
      canvas.drawCircle(
          Offset(netCx + cos(ang) * netRadius, netCy + sin(ang) * netRadius),
          4,
          floatPaint);
    }

    canvas.restore();
  }

  // ─── Input handlers ───────────────────────────────────────────────────────

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _heldKeys
      ..clear()
      ..addAll(keysPressed);

    if (event is KeyDownEvent) {
      // Record for instant-impulse processing in update()
      _justPressedKeys.add(event.logicalKey);

      if (event.logicalKey == LogicalKeyboardKey.space) {
        castNet();
        return true;
      }
    }
    return keysPressed.isNotEmpty;
  }

  /// Called by the on-screen D-pad buttons (mobile) to simulate a key press.
  /// Adds [key] to _heldKeys and records it in _justPressedKeys for the
  /// instant-impulse on first press — identical to physical keyboard behaviour.
  void pressKey(LogicalKeyboardKey key) {
    _heldKeys.add(key);
    _justPressedKeys.add(key);
    game.notifyPlayerStarted();
  }

  /// Called by the on-screen D-pad buttons (mobile) to simulate key release.
  void releaseKey(LogicalKeyboardKey key) {
    _heldKeys.remove(key);
  }

  void castNet() {
    if (netDeployed) return;
    netDeployed = true;
    netTimer = 0;
    netRadius = 0;

    // Casting net counts as first player action — start timer
    game.notifyPlayerStarted();

    // Scare nearby crocodiles when the net is cast — gives the player a
    // defensive action to push crocs away without full collision damage.
    _scareCrocodilesNearby();

    // Notify HUD
    game.onNetStateChanged?.call(true, 0.0);

    // Haptic-style camera nudge
    game.camera.viewfinder.add(
      ScaleEffect.by(Vector2.all(1.04),
          EffectController(duration: 0.2, alternate: true)),
    );
  }

  /// Scares any crocodile within 1.5× the max net radius into retreating.
  void _scareCrocodilesNearby() {
    const double scareRadius = maxNetRadius * 2.2;
    for (final croc in List<CrocodileComponent>.from(
        game.children.whereType<CrocodileComponent>())) {
      final dist = (croc.position - position).length;
      if (dist < scareRadius) {
        croc.scare();
      }
    }
  }


  /// World-space position of the net's center (used for collision).
  Vector2 get netWorldCenter {
    final local = Vector2(0, -(size.y / 2) - netRadius * 0.6);
    // Rotate by boatAngle
    final rx = local.x * cos(boatAngle) - local.y * sin(boatAngle);
    final ry = local.x * sin(boatAngle) + local.y * cos(boatAngle);
    return position + Vector2(rx, ry);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WAKE / WATER TRAIL RENDERER (drawn behind boat)
// ─────────────────────────────────────────────────────────────────────────────

class BoatWakeRenderer extends PositionComponent
    with HasGameReference<WaterPollutionGame> {
  BoatWakeRenderer() : super(priority: 95);

  @override
  void render(Canvas canvas) {
    final boat = game.rowingBoat;
    if (boat == null || boat.wakeTrail.length < 2) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < boat.wakeTrail.length - 1; i++) {
      final t = i / boat.wakeTrail.length;
      paint.color = Colors.white.withValues(alpha: t * 0.35);
      paint.strokeWidth = 6 * t + 2;
      canvas.drawLine(
        boat.wakeTrail[i].toOffset(),
        boat.wakeTrail[i + 1].toOffset(),
        paint,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ENHANCED FLOATING WASTE ITEM
// ─────────────────────────────────────────────────────────────────────────────

class FloatingWasteComponent extends PositionComponent {
  final WasteType wasteType;
  double bobOffset;
  double bobSpeed;
  double driftX; // pixels/sec horizontal sway
  double driftY; // pixels/sec downstream drift
  double spinRate; // radians/sec
  double currentAngle = 0;
  bool collected = false;

  static final _rng = Random();

  FloatingWasteComponent({
    required this.wasteType,
    required super.position,
    super.size,
  })  : bobOffset = _rng.nextDouble() * pi * 2,
        bobSpeed = 1.0 + _rng.nextDouble() * 0.8,
        driftX = (_rng.nextDouble() - 0.5) * 20,
        driftY = 25 + _rng.nextDouble() * 30,
        spinRate = (_rng.nextDouble() - 0.5) * 0.6,
        super(anchor: Anchor.center) {
    priority = 50;
    size = _defaultSize(wasteType);
  }

  static Vector2 _defaultSize(WasteType t) {
    switch (t) {
      case WasteType.oilSlick:
        return Vector2(64, 28);
      case WasteType.plasticBag:
        return Vector2(38, 48);
      default:
        return Vector2(36, 36);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    bobOffset += dt * bobSpeed;
    currentAngle += spinRate * dt;

    // Downstream drift + gentle horizontal sway
    position.y += driftY * dt;
    position.x += driftX * dt + sin(bobOffset * 0.5) * 8 * dt;

    // Wrap at bottom — respawn at top
    final gameSize = parent is WaterPollutionGame
        ? (parent as WaterPollutionGame).size
        : Vector2(400, 800);
    if (position.y > gameSize.y + 60) {
      position.y = -40;
      position.x = 40 + _rng.nextDouble() * (gameSize.x - 80);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    final cx = size.x / 2;
    final cy = size.y / 2;
    canvas.translate(cx, cy);
    canvas.rotate(currentAngle + sin(bobOffset) * 0.08);

    switch (wasteType) {
      case WasteType.plasticBottle:
        _renderPlasticBottle(canvas, cx, cy);
        break;
      case WasteType.metalCan:
        _renderMetalCan(canvas, cx, cy);
        break;
      case WasteType.plasticBag:
        _renderPlasticBag(canvas, cx, cy);
        break;
      case WasteType.oilSlick:
        _renderOilSlick(canvas, cx, cy);
        break;
      case WasteType.organicWaste:
        _renderOrganicWaste(canvas, cx, cy);
        break;
      case WasteType.metalScrap:
        _renderMetalScrap(canvas, cx, cy);
        break;
    }

    canvas.restore();
  }

  void _renderPlasticBottle(Canvas canvas, double cx, double cy) {
    // Body
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF90CAF9), const Color(0xFF1565C0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(-cx * 0.45, -cy, cx * 0.9, cy * 2));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-cx * 0.45, -cy * 0.75, cx * 0.9, cy * 1.5),
            const Radius.circular(8)),
        bodyPaint);
    // Cap
    final capPaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-cx * 0.28, -cy, cx * 0.56, cy * 0.28),
            const Radius.circular(3)),
        capPaint);
    // Label
    final labelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-cx * 0.38, -cy * 0.2, cx * 0.76, cy * 0.5),
            const Radius.circular(3)),
        labelPaint);
    // Shimmer
    canvas.drawOval(
        Rect.fromLTWH(-cx * 0.3, -cy * 0.65, cx * 0.3, cy * 0.25),
        Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  void _renderMetalCan(Canvas canvas, double cx, double cy) {
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFB0BEC5), const Color(0xFF546E7A),
          const Color(0xFF78909C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(-cx, -cy, size.x, size.y));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-cx * 0.7, -cy, cx * 1.4, cy * 2),
            const Radius.circular(10)),
        bodyPaint);
    // Top/bottom rims
    final rimPaint = Paint()..color = const Color(0xFF37474F);
    for (double yPos in [-cy, cy - 8]) {
      canvas.drawRect(
          Rect.fromLTWH(-cx * 0.7, yPos, cx * 1.4, 8), rimPaint);
    }
    // Ring pull
    final ringPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
        Rect.fromCenter(center: Offset(0, -cy + 5), width: 12, height: 10),
        0, pi, false, ringPaint);
    // Label colour stripe
    final stripePaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawRect(
        Rect.fromLTWH(-cx * 0.7, -cy * 0.2, cx * 1.4, cy * 0.5), stripePaint);
  }

  void _renderPlasticBag(Canvas canvas, double cx, double cy) {
    final bagPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    final bagPath = Path()
      ..moveTo(0, -cy)
      ..quadraticBezierTo(cx * 0.8, -cy * 0.5, cx * 0.9,
          cy * 0.5 + sin(bobOffset) * 4)
      ..quadraticBezierTo(cx * 0.3, cy, 0, cy)
      ..quadraticBezierTo(-cx * 0.3, cy, -cx * 0.9,
          cy * 0.5 + sin(bobOffset) * 4)
      ..quadraticBezierTo(-cx * 0.8, -cy * 0.5, 0, -cy)
      ..close();
    canvas.drawPath(bagPath, bagPaint);
    // Outline
    final outlinePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(bagPath, outlinePaint);
    // Knot
    canvas.drawCircle(Offset(0, -cy + 6), 5,
        Paint()..color = Colors.grey.shade500);
    // Handles
    for (double hx in [-cx * 0.25, cx * 0.25]) {
      canvas.drawLine(Offset(hx, -cy + 2), Offset(hx * 0.6, -cy - 10),
          outlinePaint);
    }
  }

  void _renderOilSlick(Canvas canvas, double cx, double cy) {
    // Irregular blob shape
    final oilPath = Path();
    const pts = 10;
    for (int i = 0; i <= pts; i++) {
      final ang = (i / pts) * pi * 2;
      final r =
          cx * (0.75 + sin(ang * 3 + bobOffset) * 0.2 + cos(ang * 2) * 0.15);
      final ox = cos(ang) * r;
      final oy = sin(ang) * r * 0.5; // flatten for slick
      if (i == 0) {
        oilPath.moveTo(ox, oy);
      } else {
        oilPath.lineTo(ox, oy);
      }
    }
    oilPath.close();

    // Iridescent oil colours
    final oilPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.black87,
          Colors.purple.withValues(alpha: 0.7),
          Colors.teal.withValues(alpha: 0.7),
          Colors.black87,
        ],
        startAngle: bobOffset * 0.3,
        endAngle: bobOffset * 0.3 + pi * 2,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: cx));
    canvas.drawPath(oilPath, oilPaint);

    // Sheen overlay
    final sheenPaint = Paint()
      ..color = Colors.deepPurple.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
        Rect.fromLTWH(-cx * 0.5, -cy * 0.2, cx, cy * 0.4), sheenPaint);
  }

  void _renderOrganicWaste(Canvas canvas, double cx, double cy) {
    // Floating log-like mass
    final woodPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFA1887F), const Color(0xFF5D4037)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(-cx, -cy * 0.5, size.x, cy));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-cx, -cy * 0.45, size.x, cy * 0.9),
            const Radius.circular(12)),
        woodPaint);
    // Grain lines
    final grainPaint = Paint()
      ..color = Colors.brown.shade900.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (double gx = -cx + 8; gx < cx; gx += 10) {
      canvas.drawLine(
          Offset(gx, -cy * 0.35), Offset(gx + 4, cy * 0.35), grainPaint);
    }
    // Green algae patches
    final algaePaint = Paint()
      ..color = Colors.green.shade700.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(-cx * 0.3, 0), width: 18, height: 10),
        algaePaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx * 0.25, cy * 0.2), width: 14, height: 8),
        algaePaint);
  }

  void _renderMetalScrap(Canvas canvas, double cx, double cy) {
    // Bent/jagged metal shape
    final scrapPath = Path()
      ..moveTo(-cx * 0.8, -cy * 0.5)
      ..lineTo(-cx * 0.3, -cy)
      ..lineTo(cx * 0.5, -cy * 0.7)
      ..lineTo(cx * 0.9, 0)
      ..lineTo(cx * 0.4, cy * 0.8)
      ..lineTo(-cx * 0.6, cy * 0.7)
      ..lineTo(-cx, cy * 0.2)
      ..close();
    final metalPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFB0BEC5), const Color(0xFF37474F),
          const Color(0xFF78909C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(-cx, -cy, size.x, size.y));
    canvas.drawPath(scrapPath, metalPaint);
    // Rust patches
    final rustPaint = Paint()..color = const Color(0xFFBF360C).withValues(alpha: 0.6);
    canvas.drawCircle(Offset(cx * 0.3, cy * 0.3), 8, rustPaint);
    canvas.drawCircle(Offset(-cx * 0.4, -cy * 0.2), 5, rustPaint);
    // Edge highlight
    canvas.drawPath(
        scrapPath,
        Paint()
          ..color = Colors.blueGrey.shade200
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CROCODILE OBSTACLE
// ─────────────────────────────────────────────────────────────────────────────

class CrocodileComponent extends PositionComponent
    with HasGameReference<WaterPollutionGame> {
  CrocodileState state = CrocodileState.lurking;
  double stateTimer = 0.0;
  double lurk = 0.0;          // 0=fully submerged, 1=fully visible
  double jawAngle = 0.0;      // 0=closed, 1=open
  double speed = 0.0;
  Vector2 moveDir = Vector2.zero();
  bool hasDealtDamage = false;

  // Patrol
  Vector2 patrolCenter;
  double patrolRadius;
  double patrolAngle;
  static final _rng = Random();

  /// HP damage dealt per successful snap — low so a single bite isn't catastrophic
  /// Damage dealt per successful snap — reduced so a single croc hit is survivable.
  static const double damageToDeal = 3.0; // was 5 — softer hit

  CrocodileComponent({
    required Vector2 position,
    required Vector2 size,
  })  : patrolCenter = position.clone(),
        patrolRadius = 60 + _rng.nextDouble() * 80,
        patrolAngle = _rng.nextDouble() * pi * 2,
        super(position: position, size: size, anchor: Anchor.center) {
    priority = 80;
    state = _randomState();
  }

  static CrocodileState _randomState() {
    return [CrocodileState.lurking, CrocodileState.submerged][
        _rng.nextInt(2)];
  }

  @override
  void update(double dt) {
    super.update(dt);
    stateTimer += dt;

    switch (state) {
      case CrocodileState.submerged:
        lurk = 0.0;
        // Long submerge gap — crocs rest longer so they rarely all attack at once
        if (stateTimer > 5 + _rng.nextDouble() * 6) _transition(CrocodileState.lurking);
        _patrol(dt);
        break;

      case CrocodileState.lurking:
        lurk = (lurk + dt * 0.8).clamp(0, 0.35); // Only eyes visible
        if (stateTimer > 3.5) _checkApproachPlayer(); // slower to trigger chase
        if (stateTimer > 8) _transition(CrocodileState.submerged); // dives sooner
        _patrol(dt);
        break;

      case CrocodileState.surfacing:
        lurk = (lurk + dt * 2.0).clamp(0, 1.0);
        jawAngle = (jawAngle + dt * 1.5).clamp(0, 1.0);
        speed = 110;
        if (stateTimer > 0.8) _transition(CrocodileState.snapping);
        _chasePlayer(dt);
        break;

      case CrocodileState.snapping:
        lurk = 1.0;
        jawAngle = (sin(stateTimer * 8) * 0.5 + 0.5).clamp(0, 1.0);
        speed = 130;
        _chasePlayer(dt);
        _checkDamagePlayer();
        if (stateTimer > 1.5) _transition(CrocodileState.retreating); // shorter snap window
        break;

      case CrocodileState.retreating:
        lurk = (lurk - dt * 1.5).clamp(0, 1.0);
        jawAngle = (jawAngle - dt).clamp(0, 1.0);
        position += moveDir * speed * dt;
        if (stateTimer > 2.0) { // longer retreat before re-submerging
          hasDealtDamage = false;
          speed = 0;
          _transition(CrocodileState.submerged);
        }
        break;
    }

    // Clamp to game bounds
    final gs = game.size;
    position.x = position.x.clamp(size.x, gs.x - size.x);
    position.y = position.y.clamp(size.y, gs.y - size.y);
  }

  void _transition(CrocodileState next) {
    state = next;
    stateTimer = 0;
    hasDealtDamage = false;
  }

  /// Called when the player casts a net nearby — forces the croc to flee.
  /// Works from any active state, giving the player a reliable scare action.
  void scare() {
    // Only scare if the croc is visible / threatening — don't surface submerged ones
    if (state == CrocodileState.submerged) return;
    _transition(CrocodileState.retreating);
    // Flee away from the boat fast
    final boat = game.rowingBoat;
    if (boat != null) {
      moveDir = (position - boat.position).normalized();
    }
    speed = 220; // fast retreat speed
  }

  void _patrol(double dt) {
    patrolAngle += dt * 0.4;
    final target = patrolCenter +
        Vector2(cos(patrolAngle) * patrolRadius, sin(patrolAngle) * patrolRadius * 0.5);
    moveDir = (target - position).normalized();
    position += moveDir * 30 * dt;
  }

  void _chasePlayer(double dt) {
    final boat = game.rowingBoat;
    if (boat == null) return;
    moveDir = (boat.position - position).normalized();
    position += moveDir * speed * dt;
  }

  void _checkApproachPlayer() {
    final boat = game.rowingBoat;
    if (boat == null) return;
    final dist = (boat.position - position).length;
    if (dist < 200) _transition(CrocodileState.surfacing);
  }

  void _checkDamagePlayer() {
    if (hasDealtDamage) return;
    final boat = game.rowingBoat;
    if (boat == null) return;
    final dist = (boat.position - position).length;
    if (dist < size.x * 0.7) {
      boat.takeDamage(damageToDeal);
      game.reportObstacleHit('crocodile', damageToDeal);
      hasDealtDamage = true;
    }
  }

  @override
  void render(Canvas canvas) {
    if (lurk <= 0.02) return; // Fully submerged — invisible

    super.render(canvas);
    canvas.save();
    final cx = size.x / 2;
    final cy = size.y / 2;
    canvas.translate(cx, cy);

    // Face movement direction
    final ang = atan2(moveDir.y, moveDir.x) + pi / 2;
    canvas.rotate(ang);

    // Depth clipping — partial emergence
    canvas.clipRect(
        Rect.fromLTWH(-cx, -cy + (1 - lurk) * size.y * 0.8, size.x, size.y));

    _drawCrocodile(canvas, cx, cy);

    canvas.restore();
  }

  void _drawCrocodile(Canvas canvas, double cx, double cy) {
    // ── Body ──────────────────────────────────────────────────────────────
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF558B2F), const Color(0xFF33691E),
          const Color(0xFF1B5E20)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(-cx, -cy, size.x, size.y));

    // Body ellipse
    canvas.drawOval(
        Rect.fromLTWH(-cx * 0.7, -cy * 0.45, size.x * 0.7, size.y * 0.6),
        bodyPaint);

    // ── Tail taper ────────────────────────────────────────────────────────
    final tailPath = Path()
      ..moveTo(-cx * 0.5, cy * 0.15)
      ..quadraticBezierTo(-cx * 0.3, cy * 1.2, 0, cy * 1.1)
      ..quadraticBezierTo(cx * 0.1, cy * 0.5, cx * 0.35, cy * 0.15)
      ..close();
    canvas.drawPath(tailPath, bodyPaint);

    // ── Scales (ridges) ───────────────────────────────────────────────────
    final scalesPaint = Paint()
      ..color = const Color(0xFF33691E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (double sy = -cy * 0.25; sy < cy * 0.25; sy += 8) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(0, sy), width: cx * 0.4, height: 5),
          scalesPaint);
    }

    // ── Legs (flippers) ───────────────────────────────────────────────────
    final legPaint = Paint()..color = const Color(0xFF33691E);
    for (int side in [-1, 1]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  side * cx * 0.68,
                  -cy * 0.1,
                  cx * 0.35,
                  cy * 0.25),
              const Radius.circular(6)),
          legPaint);
    }

    // ── Upper jaw ─────────────────────────────────────────────────────────
    final jawPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF689F38), const Color(0xFF33691E)],
      ).createShader(Rect.fromLTWH(-cx * 0.55, -cy * 1.1, cx * 1.1, cy * 0.7));
    final upperJawPath = Path()
      ..moveTo(-cx * 0.55, -cy * 0.4)
      ..quadraticBezierTo(0, -cy * 1.1, cx * 0.55, -cy * 0.4)
      ..lineTo(cx * 0.48, -cy * 0.25)
      ..quadraticBezierTo(0, -cy * 0.75, -cx * 0.48, -cy * 0.25)
      ..close();
    canvas.drawPath(upperJawPath, jawPaint);

    // ── Lower jaw (rotates open) ───────────────────────────────────────────
    canvas.save();
    canvas.translate(0, -cy * 0.4);
    canvas.rotate(jawAngle * 0.55); // open angle
    final lowerJawPaint = Paint()
      ..color = const Color(0xFF9CCC65);
    final lowerPath = Path()
      ..moveTo(-cx * 0.45, 0)
      ..quadraticBezierTo(0, cy * 0.55, cx * 0.45, 0)
      ..lineTo(cx * 0.4, -10)
      ..quadraticBezierTo(0, cy * 0.3, -cx * 0.4, -10)
      ..close();
    canvas.drawPath(lowerPath, lowerJawPaint);

    // Teeth
    final toothPaint = Paint()..color = Colors.white;
    for (double tx = -cx * 0.35; tx <= cx * 0.35; tx += cx * 0.18) {
      canvas.drawPath(
          Path()
            ..moveTo(tx, 0)
            ..lineTo(tx + 5, -8)
            ..lineTo(tx + 10, 0)
            ..close(),
          toothPaint);
    }
    canvas.restore();

    // ── Eyes (always visible when lurking) ───────────────────────────────
    for (final ex in [-cx * 0.3, cx * 0.3]) {
      canvas.drawCircle(
          Offset(ex, -cy * 0.42), 6,
          Paint()..color = const Color(0xFFFFE57F));
      canvas.drawCircle(
          Offset(ex, -cy * 0.42), 3,
          Paint()..color = Colors.black87);
      // Glint
      canvas.drawCircle(
          Offset(ex + 2, -cy * 0.42 - 2), 1.5,
          Paint()..color = Colors.white);
    }

    // ── Snapping danger indicator ─────────────────────────────────────────
    if (state == CrocodileState.snapping) {
      final dangerPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.4 + sin(stateTimer * 10) * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset.zero, size.x * 0.85, dangerPaint);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WHIRLPOOL OBSTACLE
// ─────────────────────────────────────────────────────────────────────────────

class WhirlpoolComponent extends PositionComponent
    with HasGameReference<WaterPollutionGame> {
  double spinAngle = 0.0;
  double pullStrength = 28.0; // gentle pull — noticeable but beatable with thrust
  double radius;
  double pulseTimer = 0.0;
  double _damageCooldown = 0.0;
  static const double _damageCooldownMax = 5.0; // damage at most every 5 seconds
  int _escapeAttempts = 0; // counts how many times the player has thrust hard inside

  WhirlpoolComponent({required super.position, required this.radius})
      : super(anchor: Anchor.center, priority: 40) {
    size = Vector2.all(radius * 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    spinAngle += dt * 2.5;
    pulseTimer += dt;
    if (_damageCooldown > 0) _damageCooldown -= dt;

    final boat = game.rowingBoat;
    if (boat == null) return;

    final diff = position - boat.position;
    final dist = diff.length;

    if (dist < radius * 1.2 && dist > 5) {
      final boatSpeed = boat.velocity.length;

      // ── Escape mechanic ───────────────────────────────────────────────────
      // Rowing hard (speed > 60) counts as an escape attempt each second.
      // After 2 attempts AND health ≥ 40%, pull drops to near-zero so the
      // player rows clear. Even before that, high speed dramatically reduces pull.
      if (boatSpeed > 60) {
        _escapeAttempts++;
      }
      final canEscape = game.boatHealth >= 40.0 && _escapeAttempts >= 2;

      if (canEscape) {
        // Pull is almost nothing — boat's own thrust easily overcomes it
        final weakPull = diff.normalized() * pullStrength * 0.08 *
            (1 - dist / (radius * 1.2));
        boat.velocity += weakPull * dt * 60;
        // Reset so player has to re-earn escape if they fall back in
        _escapeAttempts = 0;
      } else {
        // Normal pull — scales with distance; weaker at the outer edge
        final pullScale = boatSpeed > 60 ? 0.35 : 1.0; // fast rowing halves pull
        final pull = diff.normalized() * pullStrength * pullScale *
            (1 - dist / (radius * 1.2));
        boat.velocity += pull * dt * 60;
      }

      // Very gentle spin — reduced so turning keys still work clearly
      boat.angularVelocity += dt * 0.4;

      // Core damage — only in dead centre, long cooldown, minimal stun
      if (dist < radius * 0.3 && _damageCooldown <= 0) {
        boat.stunTimer = (boat.stunTimer + 0.3).clamp(0, 0.8); // tiny stun
        game.reportObstacleHit('whirlpool', 2.0);
        _damageCooldown = _damageCooldownMax;
      }
    } else if (dist >= radius * 1.2) {
      // Reset escape counter once fully clear of whirlpool
      _escapeAttempts = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    final cx = size.x / 2;
    final cy = size.y / 2;
    canvas.translate(cx, cy);

    final pulse = 0.85 + sin(pulseTimer * 3) * 0.15;

    for (int ring = 4; ring >= 1; ring--) {
      final r = radius * (ring / 4.0) * pulse;
      final alpha = 0.15 + (4 - ring) * 0.08;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 + ring
        ..color = Colors.cyan.shade300.withValues(alpha: alpha);

      // Rotated arc segments for swirl look
      canvas.save();
      canvas.rotate(spinAngle + ring * 0.4);
      canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          0, pi * 1.6, false, paint);
      canvas.restore();
    }

    // Centre vortex
    final vortexPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.cyan.shade900,
          Colors.blue.shade900.withValues(alpha: 0.0)
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 0.3));
    canvas.drawCircle(Offset.zero, radius * 0.3, vortexPaint);

    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOG JAM — PASSIVE RIVER DEBRIS (collectible organic waste, not an obstacle)
//  Logs drift downstream with the current. The boat passes through them freely.
//  When the net is active they are swept up as organic waste items.
// ─────────────────────────────────────────────────────────────────────────────

class LogJamComponent extends PositionComponent
    with HasGameReference<WaterPollutionGame> {
  final int logCount;
  final List<_LogData> _logs = [];
  static final _rng = Random();
  bool _collected = false; // true once the net sweeps these up

  LogJamComponent({required super.position, required super.size, this.logCount = 3})
      : super(anchor: Anchor.center, priority: 45) {
    for (int i = 0; i < logCount; i++) {
      _logs.add(_LogData(
        offset: Vector2(
            (_rng.nextDouble() - 0.5) * size.x * 0.8,
            (_rng.nextDouble() - 0.5) * size.y * 0.5),
        angle: _rng.nextDouble() * pi,
        length: 35 + _rng.nextDouble() * 30,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_collected) return;

    // Gentle downstream drift — purely visual, no collision with boat
    position.y += 22 * dt;

    // Check if the boat's active net sweeps over this log cluster
    final boat = game.rowingBoat;
    if (boat != null && boat.netDeployed && boat.netRadius > 10) {
      final dist = (boat.netWorldCenter - position).length;
      if (dist < boat.netRadius + size.x * 0.4) {
        _collected = true;
        // Award organic waste points and count as a collected item
        game.collectLogAsWaste(this);
        return;
      }
    }

    // Wrap — respawn at top when scrolled off bottom
    if (position.y > game.size.y + 80) {
      position.y = -60;
      position.x = 50 + _rng.nextDouble() * (game.size.x - 100);
      _collected = false;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_collected) return;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    for (final log in _logs) {
      canvas.save();
      canvas.translate(log.offset.x, log.offset.y);
      canvas.rotate(log.angle);

      final logPaint = Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFF8D6E63), const Color(0xFF5D4037),
            const Color(0xFF8D6E63)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(
            Rect.fromLTWH(-log.length / 2, -8, log.length, 16));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-log.length / 2, -7, log.length, 14),
              const Radius.circular(7)),
          logPaint);
      // End rings
      for (final ex in [-log.length / 2, log.length / 2]) {
        canvas.drawCircle(Offset(ex, 0), 7,
            Paint()..color = const Color(0xFF4E342E));
      }
      canvas.restore();
    }

    canvas.restore();
  }
}

class _LogData {
  final Vector2 offset;
  final double angle;
  final double length;
  _LogData({required this.offset, required this.angle, required this.length});
}

// ─────────────────────────────────────────────────────────────────────────────
//  RIVER CURRENT ZONE (speeds up / diverts boat)
// ─────────────────────────────────────────────────────────────────────────────

class RapidsCurrentZone extends PositionComponent
    with HasGameReference<WaterPollutionGame> {
  final Vector2 currentForce; // pixels/sec
  double waveOffset = 0.0;

  RapidsCurrentZone({
    required super.position,
    required super.size,
    required this.currentForce,
  }) : super(anchor: Anchor.center, priority: 30);

  @override
  void update(double dt) {
    super.update(dt);
    waveOffset += dt * 3;

    final boat = game.rowingBoat;
    if (boat == null) return;
    final rect = Rect.fromCenter(
        center: position.toOffset(), width: size.x, height: size.y);
    if (rect.contains(boat.position.toOffset())) {
      boat.velocity += currentForce * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2 - size.x / 2 + position.x,
        size.y / 2 - size.y / 2 + position.y);

    // Translucent current zone
    final zonePaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        zonePaint);

    // Flow arrows
    final arrowPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.45)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final dir = currentForce.normalized();
    for (double ax = -size.x * 0.35; ax <= size.x * 0.35; ax += size.x * 0.35) {
      for (double ay = -size.y * 0.4; ay <= size.y * 0.4; ay += size.y * 0.35) {
        final phase = sin(waveOffset + ax * 0.05 + ay * 0.05);
        final arrowLen = 18 + phase * 6;
        final sx = ax + dir.x * phase * 8;
        final sy = ay + dir.y * phase * 8;
        canvas.drawLine(Offset(sx, sy),
            Offset(sx + dir.x * arrowLen, sy + dir.y * arrowLen), arrowPaint);
        // Arrowhead
        final ex = sx + dir.x * arrowLen;
        final ey = sy + dir.y * arrowLen;
        final perp = Vector2(-dir.y, dir.x);
        canvas.drawLine(Offset(ex, ey),
            Offset(ex - dir.x * 6 + perp.x * 5, ey - dir.y * 6 + perp.y * 5),
            arrowPaint);
        canvas.drawLine(Offset(ex, ey),
            Offset(ex - dir.x * 6 - perp.x * 5, ey - dir.y * 6 - perp.y * 5),
            arrowPaint);
      }
    }

    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COLLECTION EFFECT (splashy collect animation)
// ─────────────────────────────────────────────────────────────────────────────

class CollectSplashEffect extends PositionComponent {
  final Color color;
  final int points;
  double _timer = 0;
  static const double _duration = 0.9;

  CollectSplashEffect({required super.position, required this.color, required this.points})
      : super(anchor: Anchor.center, priority: 200);

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _timer / _duration;
    final alpha = (1 - t).clamp(0.0, 1.0);

    // Expanding rings
    for (int i = 0; i < 3; i++) {
      final ringT = (t - i * 0.12).clamp(0.0, 1.0);
      final r = ringT * 40;
      canvas.drawCircle(
          const Offset(0, 0),
          r,
          Paint()
            ..color = color.withValues(alpha: alpha * (1 - ringT))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 - ringT * 2);
    }

    // Splash droplets
    final rng = Random(42);
    for (int d = 0; d < 8; d++) {
      final ang = (d / 8) * pi * 2 + rng.nextDouble();
      final dist = t * 35;
      canvas.drawCircle(
          Offset(cos(ang) * dist, sin(ang) * dist),
          (1 - t) * 5,
          Paint()..color = color.withValues(alpha: alpha));
    }

    // Points label
    if (t < 0.75) {
      final tp = TextPainter(
        text: TextSpan(
          text: '+$points',
          style: GoogleFonts.exo2(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: alpha),
            shadows: [Shadow(color: color, blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -30 - t * 20));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHALLENGE POPUP (crocodile warning / obstacle info)
// ─────────────────────────────────────────────────────────────────────────────

class DangerFlashComponent extends PositionComponent {
  final String message;
  double _timer = 0;
  static const double _duration = 1.8;

  DangerFlashComponent({required super.position, required this.message})
      : super(anchor: Anchor.center, priority: 300);

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    position.y -= 25 * dt;
    if (_timer >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _timer / _duration;
    final alpha = t < 0.2
        ? t / 0.2
        : t > 0.7
            ? 1 - (t - 0.7) / 0.3
            : 1.0;

    final bgPaint = Paint()
      ..color = Colors.red.shade900.withValues(alpha: alpha * 0.85);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-80, -20, 160, 40),
            const Radius.circular(8)),
        bgPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: message,
        style: GoogleFonts.exo2(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 155);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NET CAST BUTTON (on-screen button overlay — used by screen widget)
// ─────────────────────────────────────────────────────────────────────────────

class NetCastButtonPainter extends CustomPainter {
  final bool isActive;
  final double cooldownFraction; // 0..1, 0=ready 1=full cooldown

  NetCastButtonPainter({required this.isActive, required this.cooldownFraction});

  @override
  void paint(Canvas canvas, Size sz) {
    final center = Offset(sz.width / 2, sz.height / 2);
    final radius = sz.width / 2;

    // Background
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = isActive
              ? Colors.orange.shade700.withValues(alpha: 0.9)
              : Colors.grey.shade800.withValues(alpha: 0.75));

    // Cooldown arc
    if (cooldownFraction > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - 4),
          -pi / 2,
          cooldownFraction * pi * 2,
          true,
          Paint()..color = Colors.white.withValues(alpha: 0.25));
    }

    // Net icon — concentric arcs
    final netPaint = Paint()
      ..color = Colors.white.withValues(alpha: isActive ? 1.0 : 0.5)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    for (double r = radius * 0.2; r <= radius * 0.65; r += radius * 0.22) {
      canvas.drawCircle(center, r, netPaint);
    }
    for (int i = 0; i < 6; i++) {
      final ang = (i / 6) * pi * 2;
      canvas.drawLine(center,
          Offset(center.dx + cos(ang) * radius * 0.7, center.dy + sin(ang) * radius * 0.7),
          netPaint);
    }

    // Border
    canvas.drawCircle(
        center, radius,
        Paint()
          ..color = Colors.orange.shade300
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(NetCastButtonPainter old) =>
      old.isActive != isActive || old.cooldownFraction != cooldownFraction;
}
// ─────────────────────────────────────────────────────────────────────────────
//  ENHANCED RIVER BACKGROUND
//  (lives here so water_pollution_game.dart can access it via rowing_components)
// ─────────────────────────────────────────────────────────────────────────────

class EnhancedRiverBackground extends PositionComponent {
  final Vector2 gameSize;
  double _waveOffset = 0.0;
  double _flowOffset = 0.0;

  EnhancedRiverBackground({required this.gameSize})
      : super(size: gameSize, priority: 0);

  @override
  void update(double dt) {
    super.update(dt);
    _waveOffset += dt * 1.2;
    _flowOffset += dt * 40;
    if (_flowOffset > 80) _flowOffset -= 80;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromLTWH(0, 0, gameSize.x, gameSize.y);

    // Base river gradient
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1A3A5C),
          const Color(0xFF0D2B45),
          const Color(0xFF152535),
          const Color(0xFF0A1F30),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    // River banks
    final bankPaint = Paint()..color = const Color(0xFF0A1520);
    final bankWidth = gameSize.x * 0.08;
    canvas.drawRect(Rect.fromLTWH(0, 0, bankWidth, gameSize.y), bankPaint);
    canvas.drawRect(
        Rect.fromLTWH(gameSize.x - bankWidth, 0, bankWidth, gameSize.y),
        bankPaint);

    _drawBankVegetation(canvas, bankWidth);
    _drawCurrentLines(canvas);
    _drawSurfaceRipples(canvas);

    // Pollution tint
    canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF3E2723).withValues(alpha: 0.18));

    _drawFoamEdges(canvas, bankWidth);
  }

  void _drawBankVegetation(Canvas canvas, double bankW) {
    final rng = Random(42);
    final grassPaint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int side = 0; side < 2; side++) {
      final baseX = side == 0 ? bankW * 0.3 : gameSize.x - bankW * 0.3;
      for (double gy = 0; gy < gameSize.y; gy += 22) {
        final bendX = sin(_waveOffset + gy * 0.05) * 4;
        final height = 12 + rng.nextDouble() * 10;
        canvas.drawLine(
            Offset(baseX + rng.nextDouble() * 10 - 5, gy),
            Offset(baseX + bendX, gy - height),
            grassPaint);
      }
    }
  }

  void _drawCurrentLines(Canvas canvas) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (double lx = 0.1; lx < 1.0; lx += 0.12) {
      final x = gameSize.x * lx + sin(_waveOffset * 0.5 + lx * 3) * 15;
      for (double ly = -80; ly < gameSize.y + 80; ly += 80) {
        final fy = (ly + _flowOffset) % (gameSize.y + 80) - 40;
        canvas.drawLine(Offset(x, fy),
            Offset(x + sin(_waveOffset + fy * 0.01) * 8, fy + 45), linePaint);
      }
    }
  }

  void _drawSurfaceRipples(Canvas canvas) {
    final ripplePaint = Paint()
      ..color = Colors.lightBlue.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int r = 0; r < 12; r++) {
      final cx =
          gameSize.x * (0.1 + (r % 4) * 0.25 + sin(_waveOffset + r) * 0.04);
      final cy = gameSize.y * (0.12 + (r / 12.0)) +
          sin(_waveOffset * 0.8 + r * 0.7) * 20;
      final rad = 18 + sin(_waveOffset + r * 0.5) * 8;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, cy), width: rad * 2.5, height: rad),
          ripplePaint);
    }
  }

  void _drawFoamEdges(Canvas canvas, double bankW) {
    final foamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(
        Rect.fromLTWH(bankW - 4, 0, 10, gameSize.y), foamPaint);
    canvas.drawRect(
        Rect.fromLTWH(gameSize.x - bankW - 6, 0, 10, gameSize.y), foamPaint);
  }
}