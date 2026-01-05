import 'dart:async';
import 'package:ecoquest/game/water_pollution_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ecoquest/main.dart';

class WaterPollutionScreen extends StatefulWidget {
  final int bacteriaCulturesAvailable; // From Deforestation level
  final Map<String, int> materialsFromPreviousLevel;
  
  const WaterPollutionScreen({
    super.key,
    required this.bacteriaCulturesAvailable,
    required this.materialsFromPreviousLevel,
  });

  @override
  State<WaterPollutionScreen> createState() => _WaterPollutionScreenState();
}

class _WaterPollutionScreenState extends State<WaterPollutionScreen> {
  late final WaterPollutionGame game;
  
  int currentPhase = 0; // 0=Intro, 1=Collection, 2=Sorting, 3=Treatment, 4=Agriculture, 5=Complete
  bool _showPhaseTransition = false;
  
  // Phase 1 stats
  int wasteCollected = 0;
  int totalWasteItems = 50;
  
  // Phase 2 stats
  int sortingAccuracy = 0;
  int itemsSorted = 0;
  int sortedCorrectly = 0;   
  int sortedIncorrectly = 0;
  
  // Phase 3 stats
  int zonesTreated = 0;
  int totalZones = 6;
  double pollutionLevel = 100.0;
  
  // Phase 4 stats
  int farmsIrrigated = 0;
  int totalFarms = 3;
  int cropsMature = 0;
  
  @override
  void initState() {
    super.initState();
    game = WaterPollutionGame(
      bacteriaCultures: widget.bacteriaCulturesAvailable,
    );
    
    // Set up callbacks
    game.onWasteCollected = (count) {
      setState(() {
        wasteCollected = count;
      });
    };
        
    game.onPhaseComplete = (phase) {
      setState(() {
        _showPhaseTransition = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              currentPhase = phase + 1;
              _showPhaseTransition = false;
              
              // ADD THIS: Start the next phase
              if (phase == 1) {
                game.startPhase2Sorting();
              } else if (phase == 2) {
                game.startPhase3Treatment();
              } else if (phase == 3) {
                game.startPhase4Agriculture();
              }
            });
          }
        });
      });
    };
    
    game.onSortingUpdate = (accuracy, sorted) {
      setState(() {
        sortingAccuracy = accuracy;
        itemsSorted = sorted;
        sortedCorrectly = game.sortedCorrectly;
        sortedIncorrectly = game.sortedIncorrectly;
      });
    };
    
    game.onTreatmentUpdate = (zones, pollution) {
      setState(() {
        zonesTreated = zones;
        pollutionLevel = pollution;
      });
    };
    
    game.onAgricultureUpdate = (farms, crops) {
      setState(() {
        farmsIrrigated = farms;
        cropsMature = crops;
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // Main game view - SHOW FOR PHASE 2 AS WELL
            if (currentPhase == 1 || currentPhase == 2 || currentPhase == 3)
              GameWidget(game: game),
            
            // UI Overlays
            if (currentPhase == 0) _buildIntroScreen(),
            if (currentPhase == 1) _buildCollectionOverlay(),
            if (currentPhase == 2) _buildSortingInterface(),
            if (currentPhase == 3) _buildTreatmentOverlay(),
            if (currentPhase == 4) _buildAgricultureInterface(),
            if (currentPhase == 5) _buildCompletionScreen(),
            
            // Phase transition overlay
            if (_showPhaseTransition) _buildPhaseTransition(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroScreen() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1E3A5F),
            const Color(0xFF0F2235),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: isLandscape && isMobile ? 10 : 20),
              
              Icon(
                Icons.water_drop,
                size: isMobile ? 60 : isTablet ? 70 : 80,
                color: Colors.cyan,
              ),
              SizedBox(height: isMobile ? 16 : 24),
              
              Text(
                'THIKA RIVER RESTORATION',
                style: GoogleFonts.exo2(
                  fontSize: isMobile ? 24 : isTablet ? 28 : 32,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isMobile ? 12 : 16),
              
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan, width: 2),
                ),
                child: Column(
                  children: [
                    _buildMissionItem(
                      '🚤 Phase 1: Navigate speedboat and collect floating waste',
                      isMobile,
                    ),
                    _buildMissionItem(
                      '♻️ Phase 2: Sort waste into recycling bins',
                      isMobile,
                    ),
                    _buildMissionItem(
                      '🦠 Phase 3: Apply bacteria to purify water',
                      isMobile,
                    ),
                    _buildMissionItem(
                      '🌾 Phase 4: Use clean water for sustainable irrigation',
                      isMobile,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isMobile ? 16 : 24),
              
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.science,
                      color: Colors.green,
                      size: isMobile ? 24 : 32,
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: Text(
                        'Bacteria cultures available: ${widget.bacteriaCulturesAvailable}',
                        style: GoogleFonts.exo2(
                          fontSize: isMobile ? 14 : 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isMobile ? 20 : 32),
              
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentPhase = 1;
                  });
                  game.startPhase1();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 32 : 48,
                    vertical: isMobile ? 12 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'START MISSION',
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              
              SizedBox(height: isLandscape && isMobile ? 10 : 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionItem(String text, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.cyan,
            size: isMobile ? 16 : 20,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.exo2(
                fontSize: isMobile ? 12 : 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionOverlay() {
    double collectionProgress = (wasteCollected / totalWasteItems * 100).clamp(0, 100);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    
    return Stack(
      children: [
        // Top stats panel - adaptive positioning
        Positioned(
          top: 0,
          left: 0,
          right: isLandscape && !isMobile ? screenWidth * 0.3 : 0,
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.all(isMobile ? 12 : isTablet ? 14 : 16),
              padding: EdgeInsets.all(isMobile ? 12 : isTablet ? 14 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyan, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'WASTE COLLECTION',
                          style: GoogleFonts.exo2(
                            fontSize: isMobile ? 14 : isTablet ? 16 : 18,
                            color: Colors.cyan,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 12,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyan, width: 1.5),
                        ),
                        child: Text(
                          '$wasteCollected / $totalWasteItems',
                          style: GoogleFonts.exo2(
                            fontSize: isMobile ? 14 : isTablet ? 16 : 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isMobile ? 8 : 12),
                  
                  // Animated progress bar with gradient
                  Container(
                    height: isMobile ? 16 : 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.cyan.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: (screenWidth - (isMobile ? 48 : isTablet ? 56 : 64)) * 
                                (collectionProgress / 100),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.cyan,
                                Colors.blue,
                                Colors.cyan.shade700,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        // Progress percentage text
                        Center(
                          child: Text(
                            '${collectionProgress.toInt()}%',
                            style: GoogleFonts.exo2(
                              fontSize: isMobile ? 10 : 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: isMobile ? 8 : 12),
                  
                  // Timer and net status row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: levelTimeNotifier,
                        builder: (context, time, _) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 10,
                              vertical: isMobile ? 4 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: time < 60 
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.green.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: time < 60 ? Colors.red : Colors.green,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: isMobile ? 14 : 16,
                                  color: time < 60 ? Colors.red : Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${time}s',
                                  style: GoogleFonts.exo2(
                                    fontSize: isMobile ? 12 : 14,
                                    color: time < 60 ? Colors.red : Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      // Net deployment indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: (game.speedboat?.netDeployed ?? false)
                              ? Colors.amber.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (game.speedboat?.netDeployed ?? false)
                                ? Colors.amber
                                : Colors.grey,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.catching_pokemon,
                              size: isMobile ? 14 : 16,
                              color: (game.speedboat?.netDeployed ?? false)
                                  ? Colors.amber
                                  : Colors.grey,
                            ),
                            SizedBox(width: 4),
                            Text(
                              (game.speedboat?.netDeployed ?? false) 
                                  ? 'NET ACTIVE'
                                  : 'NET READY',
                              style: GoogleFonts.exo2(
                                fontSize: isMobile ? 10 : 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isMobile ? 8 : 12),
                  
                  // Controls hint - adaptive for device type
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (!isMobile) ...[
                          // Desktop/Laptop controls
                          Text(
                            '🎮 KEYBOARD: WASD or Arrow Keys to move',
                            style: GoogleFonts.exo2(
                              fontSize: isTablet ? 11 : 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '🖱️ MOUSE: Click and drag to steer | SPACE to deploy net',
                            style: GoogleFonts.exo2(
                              fontSize: isTablet ? 11 : 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          // Mobile/Tablet touch controls
                          Text(
                            '👆 Touch and drag to steer the boat',
                            style: GoogleFonts.exo2(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '🎯 Tap to deploy collection net',
                            style: GoogleFonts.exo2(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Mobile virtual joystick overlay (bottom-left for portrait, adjusts for landscape)
        if (isMobile && game.speedboat?.showJoystick == true)
          Positioned(
            left: isLandscape ? 20 : 30,
            bottom: isLandscape ? 20 : 80,
            child: CustomPaint(
              size: Size(isMobile ? 100 : 120, isMobile ? 100 : 120),
              painter: VirtualJoystickPainter(
                center: game.speedboat!.joystickCenter!,
                position: game.speedboat!.joystickPosition!,
              ),
            ),
          ),
        
        // Collection feedback indicator (center-top)
        if (wasteCollected > 0 && wasteCollected % 5 == 0)
          Positioned(
            top: screenHeight * 0.25,
            left: 0,
            right: 0,
            child: Center(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: 1.0 - value,
                    child: Transform.scale(
                      scale: 1.0 + (value * 0.5),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.green.shade700],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Text(
                          '+5 COLLECTED! 🎉',
                          style: GoogleFonts.exo2(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        
        // River cleanliness indicator (bottom-right)
        Positioned(
          right: isMobile ? 12 : isTablet ? 16 : 20,
          bottom: isMobile ? 12 : isTablet ? 16 : 20,
          child: Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withValues(alpha: 0.8),
                  Colors.cyan.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop,
                  color: collectionProgress > 70 
                      ? Colors.green
                      : collectionProgress > 40
                          ? Colors.orange
                          : Colors.red,
                  size: isMobile ? 24 : 32,
                ),
                SizedBox(height: 4),
                Text(
                  'RIVER',
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 10 : 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  collectionProgress > 70 
                      ? 'CLEAN'
                      : collectionProgress > 40
                          ? 'BETTER'
                          : 'DIRTY',
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 8 : 10,
                    color: collectionProgress > 70 
                        ? Colors.green
                        : collectionProgress > 40
                            ? Colors.orange
                            : Colors.red,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortingInterface() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    
    return Stack(
      children: [
        // Top header with stats - COMPACT VERSION
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.all(isMobile ? 8 : 12),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'WASTE SORTING',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 14 : 16,
                      color: Colors.green,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCompactStat(
                        'Accuracy',
                        '$sortingAccuracy%',
                        sortingAccuracy >= 70 ? Colors.green : Colors.orange,
                        isMobile,
                      ),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _buildCompactStat(
                        'Progress',
                        '$itemsSorted/${game.collectedWaste.length}',
                        Colors.cyan,
                        isMobile,
                      ),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _buildCompactStat(
                        'Correct',
                        '$sortedCorrectly',
                        Colors.green,
                        isMobile,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Instructions - Floating hint (ONLY show on first few items)
        if (itemsSorted < 3)
          Positioned(
            top: size.height * 0.2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Colors.amber,
                      size: isMobile ? 20 : 24,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isMobile 
                            ? 'TAP to select, then TAP bin\nOR DRAG to bin'
                            : 'TAP item then TAP bin | OR | DRAG item to bin',
                        style: GoogleFonts.exo2(
                          fontSize: isMobile ? 11 : 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Bin labels at bottom - ADAPTIVE POSITIONING
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: EdgeInsets.only(
                left: isMobile ? 8 : 16,
                right: isMobile ? 8 : 16,
                bottom: isMobile ? 8 : 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMinimalBinLabel('PLASTIC', Colors.blue, isMobile),
                  _buildMinimalBinLabel('METAL', Colors.grey, isMobile),
                  _buildMinimalBinLabel('HAZARD', Colors.red, isMobile),
                  _buildMinimalBinLabel('ORGANIC', Colors.green, isMobile),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStat(String label, String value, Color color, bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 16 : 18,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 9 : 10,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalBinLabel(String label, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.exo2(
          fontSize: isMobile ? 9 : 11,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTreatmentOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Column(
            children: [
              Text(
                'BACTERIAL TREATMENT',
                style: GoogleFonts.exo2(
                  fontSize: 18,
                  color: Colors.green,
                  fontWeight: FontWeight.w900,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTreatmentStat('Zones', '$zonesTreated/$totalZones', Colors.cyan),
                  _buildTreatmentStat('Pollution', '${pollutionLevel.toInt()}%', 
                    pollutionLevel < 20 ? Colors.green : Colors.red),
                  _buildTreatmentStat('Bacteria', '${game.bacteriaRemaining}', Colors.green),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Pollution meter
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: MediaQuery.of(context).size.width * 0.9 * (pollutionLevel / 100),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red, Colors.orange, Colors.yellow],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Click polluted zones (red/brown) to apply bacteria',
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTreatmentStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildAgricultureInterface() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;
    
    return Container(
      color: const Color(0xFF2D5016),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              color: Colors.black.withValues(alpha: 0.7),
              child: Column(
                children: [
                  Text(
                    'SUSTAINABLE IRRIGATION',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 16 : isTablet ? 18 : 20,
                      color: Colors.green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAgriStat('Farms', '$farmsIrrigated/$totalFarms', isMobile),
                      _buildAgriStat('Crops', '$cropsMature', isMobile),
                      _buildAgriStat('Efficiency', '${game.waterEfficiency}%', isMobile),
                    ],
                  ),
                ],
              ),
            ),
            // Pipeline grid
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Text(
                    'Drag and tap pipes to connect river to farms',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 14 : isTablet ? 16 : 18,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            _buildIrrigationMethods(isMobile, isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildAgriStat(String label, String value, bool isMobile) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 10 : 12,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 18 : 24,
            color: Colors.green,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildIrrigationMethods(bool isMobile, bool isTablet) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: isMobile ? 140 : 150,
      ),
      color: Colors.black.withValues(alpha: 0.8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Row(
        children: [
          Expanded(
            child: _buildIrrigationOption(
              'Drip Irrigation',
              '90% efficient',
              Icons.water_drop,
              Colors.blue,
              50,
              isMobile,
              () {
                for (var farm in game.farmZones) {
                  if (!farm.isIrrigated) {
                    game.irrigateFarm(farm, 'drip');
                    break;
                  }
                }
              },
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: _buildIrrigationOption(
              'Contour Farming',
              'Prevents erosion',
              Icons.landscape,
              Colors.green,
              75,
              isMobile,
              () {
                for (var farm in game.farmZones) {
                  if (!farm.isIrrigated) {
                    game.irrigateFarm(farm, 'contour');
                    break;
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIrrigationOption(
    String name,
    String benefit,
    IconData icon,
    Color color,
    int cost,
    bool isMobile,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: game.pipelineConnected ? onTap : null,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: isMobile ? 24 : 32),
            SizedBox(height: isMobile ? 4 : 8),
            Text(
              name,
              style: GoogleFonts.exo2(
                fontSize: isMobile ? 11 : 14,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              benefit,
              style: GoogleFonts.exo2(
                fontSize: isMobile ? 9 : 11,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              '$cost points',
              style: GoogleFonts.exo2(
                fontSize: isMobile ? 10 : 12,
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    final totalPoints = game.calculateFinalScore();
    final purifiedWater = game.purifiedWaterAmount;
    final bacteriaMultiplied = game.bacteriaMultiplied;
    
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F4C81),
            const Color(0xFF1E88E5),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: isLandscape && isMobile ? 10 : 20),
              
              Icon(
                Icons.check_circle,
                size: isMobile ? 70 : isTablet ? 85 : 100,
                color: Colors.green,
              ),
              SizedBox(height: isMobile ? 16 : 24),
              
              Text(
                'RIVER RESTORED!',
                style: GoogleFonts.exo2(
                  fontSize: isMobile ? 28 : isTablet ? 32 : 36,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              
              SizedBox(height: isMobile ? 20 : 32),
              
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan, width: 2),
                ),
                child: Column(
                  children: [
                    _buildCompletionStat(
                      'Total Points',
                      '$totalPoints',
                      Colors.amber,
                      isMobile,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    _buildCompletionStat(
                      'Purified Water',
                      '${purifiedWater}L',
                      Colors.cyan,
                      isMobile,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    _buildCompletionStat(
                      'Bacteria Cultures',
                      '$bacteriaMultiplied',
                      Colors.green,
                      isMobile,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    _buildCompletionStat(
                      'Recycled Materials',
                      '${game.recycledMaterials}kg',
                      Colors.purple,
                      isMobile,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isMobile ? 20 : 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'purifiedWater': purifiedWater,
                      'bacteria': bacteriaMultiplied,
                      'recycledMaterials': game.recycledMaterials,
                      'ecoPoints': totalPoints,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'CONTINUE',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: isLandscape && isMobile ? 10 : 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionStat(String label, String value, Color color, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.exo2(
              fontSize: isMobile ? 14 : 16,
              color: Colors.white70,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 20 : 24,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseTransition() {
    String phaseText = '';
    IconData phaseIcon = Icons.check;
    
    switch (currentPhase) {
      case 1:
        phaseText = 'Waste Collection Complete!\nProceeding to Sorting...';
        phaseIcon = Icons.recycling;
        break;
      case 2:
        phaseText = 'Sorting Complete!\nStarting Bacterial Treatment...';
        phaseIcon = Icons.science;
        break;
      case 3:
        phaseText = 'Water Purified!\nSetting up Irrigation...';
        phaseIcon = Icons.agriculture;
        break;
      case 4:
        phaseText = 'Farms Irrigated!\nEcosystem Restoring...';
        phaseIcon = Icons.nature;
        break;
    }
    
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(phaseIcon, size: 80, color: Colors.cyan),
            const SizedBox(height: 24),
            Text(
              phaseText,
              style: GoogleFonts.exo2(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.cyan),
          ],
        ),
      ),
    );
  }
}

class VirtualJoystickPainter extends CustomPainter {
  final Vector2 center;
  final Vector2 position;
  
  VirtualJoystickPainter({
    required this.center,
    required this.position,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    // Draw outer circle (base)
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    // Draw outer circle border
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint
        ..color = Colors.cyan.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    
    // Calculate joystick position relative to center
    final direction = position - center;
    final distance = direction.length.clamp(0.0, size.width / 2 - 15);
    final normalized = distance > 0 ? direction.normalized() : Vector2.zero();
    final joystickPos = normalized * distance;
    
    // Draw inner circle (movable stick)
    final stickPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.cyan,
          Colors.cyan.shade700,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width / 2 + joystickPos.x,
            size.height / 2 + joystickPos.y,
          ),
          radius: 25,
        ),
      )
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(
        size.width / 2 + joystickPos.x,
        size.height / 2 + joystickPos.y,
      ),
      25,
      stickPaint,
    );
    
    // Draw direction indicator line
    if (distance > 5) {
      final linePaint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(size.width / 2, size.height / 2),
        Offset(
          size.width / 2 + joystickPos.x,
          size.height / 2 + joystickPos.y,
        ),
        linePaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(VirtualJoystickPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.center != center;
  }
}