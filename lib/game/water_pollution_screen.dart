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
            });
          }
        });
      });
    };
    
    game.onSortingUpdate = (accuracy, sorted) {
      setState(() {
        sortingAccuracy = accuracy;
        itemsSorted = sorted;
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
            // Main game view
            if (currentPhase == 1 || currentPhase == 3)
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.water_drop,
                size: 80,
                color: Colors.cyan,
              ),
              const SizedBox(height: 24),
              
              Text(
                'THIKA RIVER RESTORATION',
                style: GoogleFonts.exo2(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan, width: 2),
                ),
                child: Column(
                  children: [
                    _buildMissionItem(
                      '🚤 Phase 1: Navigate speedboat and collect floating waste',
                    ),
                    _buildMissionItem(
                      '♻️ Phase 2: Sort waste into recycling bins',
                    ),
                    _buildMissionItem(
                      '🦠 Phase 3: Apply bacteria to purify water',
                    ),
                    _buildMissionItem(
                      '🌾 Phase 4: Use clean water for sustainable irrigation',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.science, color: Colors.green, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bacteria cultures available: ${widget.bacteriaCulturesAvailable}',
                        style: GoogleFonts.exo2(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentPhase = 1;
                  });
                  game.startPhase1();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'START MISSION',
                  style: GoogleFonts.exo2(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.cyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.exo2(
                fontSize: 14,
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
    return Container(
      color: const Color(0xFF1E3A5F),
      child: SafeArea(
        child: Column(
          children: [
            _buildSortingHeader(),
            Expanded(
              child: Stack(
                children: [
                  // Conveyor background
                  Positioned.fill(child: Container(color: Colors.grey.shade800)),
                  // Draggable waste and bins rendered by game, but overlay stats
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Text(
                      'Accuracy: $sortingAccuracy% | Sorted: $itemsSorted / $wasteCollected',
                      style: GoogleFonts.exo2(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildRecyclingBins(), // Buttons or visuals for bins
          ],
        ),
      ),
    );
  }

  Widget _buildSortingHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black.withValues(alpha: 0.7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'WASTE SORTING',
            style: GoogleFonts.exo2(
              fontSize: 18,
              color: Colors.green,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Accuracy: $sortingAccuracy%',
            style: GoogleFonts.exo2(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecyclingBins() {
    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBinIcon('Plastic', Colors.blue),
          _buildBinIcon('Metal', Colors.grey),
          _buildBinIcon('Hazardous', Colors.red),
          _buildBinIcon('Organic', Colors.green),
        ],
      ),
    );
  }

  Widget _buildBinIcon(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.recycling, color: Colors.white, size: 40),
        ),
        Text(label, style: GoogleFonts.exo2(color: Colors.white, fontSize: 12)),
      ],
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
    return Container(
      color: const Color(0xFF2D5016),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black.withValues(alpha: 0.7),
              child: Column(
                children: [
                  Text(
                    'SUSTAINABLE IRRIGATION',
                    style: GoogleFonts.exo2(
                      fontSize: 20,
                      color: Colors.green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAgriStat('Farms', '$farmsIrrigated/$totalFarms'),
                      _buildAgriStat('Crops', '$cropsMature'),
                      _buildAgriStat('Efficiency', '${game.waterEfficiency}%'),
                    ],
                  ),
                ],
              ),
            ),
            // Pipeline grid (game renders pipes, overlay instructions)
            Expanded(
              child: Center(
                child: Text(
                  'Drag and tap pipes to connect river to farms',
                  style: GoogleFonts.exo2(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            _buildIrrigationMethods(), // Buttons to select after connection
          ],
        ),
      ),
    );
  }

  Widget _buildAgriStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.exo2(fontSize: 12, color: Colors.white70)),
        Text(value, style: GoogleFonts.exo2(fontSize: 24, color: Colors.green, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildIrrigationMethods() {
    return Container(
      height: 150,
      color: Colors.black.withValues(alpha: .8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildIrrigationOption(
              'Drip Irrigation',
              '90% efficient',
              Icons.water_drop,
              Colors.blue,
              50,
              () {
                // Call irrigate with 'drip'
                for (var farm in game.farmZones) {
                  if (!farm.isIrrigated) {
                    game.irrigateFarm(farm, 'drip');
                    break;
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildIrrigationOption(
              'Contour Farming',
              'Prevents erosion',
              Icons.landscape,
              Colors.green,
              75,
              () {
                // Call irrigate with 'contour'
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

  Widget _buildIrrigationOption(String name, String benefit, IconData icon, Color color, int cost, VoidCallback onTap) {
    return GestureDetector(
      onTap: game.pipelineConnected ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              name,
              style: GoogleFonts.exo2(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              benefit,
              style: GoogleFonts.exo2(
                fontSize: 11,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '$cost points',
              style: GoogleFonts.exo2(
                fontSize: 12,
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 100, color: Colors.green),
              const SizedBox(height: 24),
              
              Text(
                'RIVER RESTORED!',
                style: GoogleFonts.exo2(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan, width: 2),
                ),
                child: Column(
                  children: [
                    _buildCompletionStat('Total Points', '$totalPoints', Colors.amber),
                    const SizedBox(height: 16),
                    _buildCompletionStat('Purified Water', '${purifiedWater}L', Colors.cyan),
                    const SizedBox(height: 16),
                    _buildCompletionStat('Bacteria Cultures', '$bacteriaMultiplied', Colors.green),
                    const SizedBox(height: 16),
                    _buildCompletionStat('Recycled Materials', '${game.recycledMaterials}kg', Colors.purple),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Return to level map with resources
                        Navigator.pop(context, {
                          'purifiedWater': purifiedWater,
                          'bacteria': bacteriaMultiplied,
                          'recycledMaterials': game.recycledMaterials,
                          'ecoPoints': totalPoints,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'CONTINUE',
                        style: GoogleFonts.exo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
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
    );
  }

  Widget _buildCompletionStat(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: 24,
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