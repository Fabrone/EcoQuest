import 'dart:async';
import 'dart:math' as math;
import 'package:ecoquest/game/eco_quest_game.dart';
import 'package:ecoquest/game/water_pollution_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class DyeExtractionScreen extends StatefulWidget {
  final EcoQuestGame game;
  final int levelTimeRemaining;

  const DyeExtractionScreen({
    super.key,
    required this.game,
    this.levelTimeRemaining = 100,
  });

  @override
  State<DyeExtractionScreen> createState() => _DyeExtractionScreenState();
}

class _DyeExtractionScreenState extends State<DyeExtractionScreen>
    with TickerProviderStateMixin {
  // Material Quality System
  String materialQuality = 'Good';
  double qualityMultiplier = 1.0;
  Map<String, int> materials = {};
  Map<String, String> materialQualities = {};

  // Workshop State
  int currentPhase =
      0; // 0=Transition, 1=Workshop, 2=Crushing, 3=Temperature, 4=Filtering, 5=Complete
  String? selectedRecipe;
  List<String> selectedMaterials = [];

  late AnimationController _bottlePlacementController;
  late AnimationController _shelfShineController;

  List<StoredDye> storedDyes = []; // Tracks all stored dyes
  bool _showStorageSuccess = false;

  // Dye tracking variables
  int totalDyeProduced = 0;
  int dyeRemaining = 0;
  List<Map<String, dynamic>> completedActivities = [];

  // Mini-game scores
  double crushingEfficiency = 1.0;
  double temperatureMaintained = 1.0;
  double filteringPurity = 1.0;

  // Final results
  int dyeProduced = 0;
  int ecoCoinsEarned = 0;
  Color dyeColor = Colors.green;
  String dyeType = '';

  // Animation controllers
  late AnimationController _transitionController;
  late AnimationController _crushingController;
  late AnimationController _bubbleController;

  // Temperature mini-game - UPDATED
  double temperature = 70.0;
  double temperatureTarget = 70.0;
  Timer? temperatureTimer;
  double heatingProgress = 0.0; // Progress towards completion (0.0 to 100.0)
  double damageAccumulated = 0.0; // Damage from overheating
  int timeInOptimalZone = 0; // Deciseconds in optimal zone
  int timeInDangerZone = 0; // Deciseconds in danger zone
  bool heatingComplete = false;

  // Crushing mini-game
  int tapCount = 0;

  // Filtering mini-game
  double filterPosition = 0.0;
  int swipeCount = 0;
  Timer? filteringTimer;
  int filteringTimeLeft = 30; // Increased from 15 to 30 seconds
  double filteringProgress = 0.0; // Track actual filtration progress (0-100)
  double impurityLevel = 100.0; // Start with 100% impurities
  List<Map<String, dynamic>> impurityParticles =
      []; // Track individual impurity particles
  bool isFiltering = false; // Track if user is actively filtering
  double filterClothSag = 0.0; // Visual feedback for filter cloth
  int consecutiveSwipes = 0; // Bonus for consistent swiping
  DateTime? lastSwipeTime;

  @override
  void initState() {
    super.initState();
    _initializeMaterials();
    _initializeAnimations();

    // ADD THESE NEW CONTROLLERS:
    _bottlePlacementController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _shelfShineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _transitionController.dispose();
    _crushingController.dispose();
    _bubbleController.dispose();
    temperatureTimer?.cancel();
    filteringTimer?.cancel();

    // ADD THESE:
    _bottlePlacementController.dispose();
    _shelfShineController.dispose();

    super.dispose();
  }

  void _initializeMaterials() {
    int timeRemaining = widget.levelTimeRemaining;

    if (timeRemaining >= 100) {
      // Excellent quality - completed very quickly (100+ seconds remaining)
      materialQuality = 'Premium Harvest';
      qualityMultiplier = 1.5; // +50% bonus
    } else if (timeRemaining > 40 && timeRemaining < 100) {
      // Good quality - moderate speed (40-99 seconds remaining)
      materialQuality = 'Quality Harvest';
      qualityMultiplier = 1.25; // +25% bonus
    } else {
      // Basic quality - slow completion (0-40 seconds remaining)
      materialQuality = 'Basic Harvest';
      qualityMultiplier = 1.0; // No bonus
    }

    // Get actual materials from game
    Map<String, int> gameMaterials = widget.game.getMaterialsCollected();

    materials = {
      '🍃 Leaves': gameMaterials['leaf'] ?? 0,
      '🪵 Bark': gameMaterials['bark'] ?? 0,
      '🌿 Roots': gameMaterials['root'] ?? 0,
      '🌺 Flowers': gameMaterials['flower'] ?? 0,
      '🫐 Fruits': gameMaterials['fruit'] ?? 0,
    };

    // Assign qualities to all materials
    materials.forEach((key, value) {
      materialQualities[key] = materialQuality;
    });
  }

  void _initializeAnimations() {
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _crushingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  void _startWorkshop() {
    setState(() {
      currentPhase = 1;
    });
  }

  void _selectRecipe(String recipe, Color color, String type) {
    setState(() {
      selectedRecipe = recipe;
      dyeColor = color;
      dyeType = type;
      selectedMaterials.clear();
    });
  }

  bool _canCraftRecipe(String recipe) {
    Map<String, int> required = _getRecipeRequirements(recipe);
    for (var entry in required.entries) {
      if ((materials[entry.key] ?? 0) < entry.value) {
        return false;
      }
    }
    return true;
  }

  Map<String, int> _getRecipeRequirements(String recipe) {
    switch (recipe) {
      case 'Green Dye':
        return {'🍃 Leaves': 10};
      case 'Brown Dye':
        return {'🪵 Bark': 10};
      case 'Yellow Dye':
        return {'🌿 Roots': 10};
      case 'Red Dye':
        return {'🌺 Flowers': 10};
      case 'Purple Dye':
        return {'🫐 Fruits': 10};
      case 'Blue Dye':
        return {'🍃 Leaves': 5, '🫐 Fruits': 5};
      case 'Orange Dye':
        return {'🌿 Roots': 5, '🌺 Flowers': 5};
      case 'Teal Dye':
        return {'🍃 Leaves': 5, '🪵 Bark': 5};
      default:
        return {};
    }
  }

  void _addDyeToStorage() {
    setState(() {
      storedDyes.add(StoredDye(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: dyeType,
        color: dyeColor,
        volume: dyeProduced,
        isNew: true,
      ));
      _showStorageSuccess = true;
    });
    
    _bottlePlacementController.forward(from: 0);
    
    // Mark bottle as not new after animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && storedDyes.isNotEmpty) {
        setState(() {
          storedDyes.last.isNew = false;
        });
      }
    });
  }

  void _startCrushing() {
    if (selectedRecipe == null) return;

    // Deduct materials
    Map<String, int> required = _getRecipeRequirements(selectedRecipe!);
    required.forEach((key, value) {
      materials[key] = (materials[key] ?? 0) - value;
    });

    setState(() {
      currentPhase = 2;
      tapCount = 0;
    });
  }

  void _onCrushTap() {
    setState(() {
      tapCount++;
      _crushingController.forward(from: 0);

      // Check if crushing is complete (100%)
      double crushingProgress = (tapCount / 80.0 * 100).clamp(0.0, 100.0);
      if (crushingProgress >= 100.0) {
        _calculateCrushingScore();
      }
    });
  }

  void _calculateCrushingScore() {
    double crushingProgress = (tapCount / 80.0 * 100).clamp(0.0, 100.0);

    if (crushingProgress >= 90) {
      crushingEfficiency = 1.3; // +30% bonus for perfect crushing
    } else if (crushingProgress >= 70) {
      crushingEfficiency = 1.15; // +15% bonus for good crushing
    } else if (crushingProgress >= 50) {
      crushingEfficiency = 1.0; // Standard yield
    } else {
      crushingEfficiency = 0.85; // -15% penalty for poor crushing
    }

    setState(() {
      currentPhase = 3;
      temperature = 70.0;
    });

    _startTemperatureGame();
  }

  void _startTemperatureGame() {
    setState(() {
      heatingProgress = 0.0;
      damageAccumulated = 0.0;
      timeInOptimalZone = 0;
      timeInDangerZone = 0;
      heatingComplete = false;
    });

    temperatureTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      setState(() {
        // Natural temperature drift (simulating heat loss/gain)
        temperature += (math.Random().nextDouble() - 0.5) * 1.5;
        temperature = temperature.clamp(40.0, 100.0);

        // OPTIMAL ZONE: 60-80°C (Fast heating progress)
        if (temperature >= 60 && temperature <= 80) {
          timeInOptimalZone++;
          heatingProgress += 0.8; // Fast progress in optimal zone
          timeInDangerZone = 0; // Reset danger counter
        }
        // ACCEPTABLE ZONE: 50-60°C or 80-85°C (Slow heating progress)
        else if ((temperature >= 50 && temperature < 60) ||
            (temperature > 80 && temperature <= 85)) {
          heatingProgress += 0.3; // Slower progress
          timeInDangerZone = 0;
        }
        // DANGER ZONE: 85-95°C (Very slow progress + damage accumulation)
        else if (temperature > 85 && temperature <= 95) {
          heatingProgress += 0.1; // Very slow progress
          timeInDangerZone++;

          // Accumulate damage gradually in danger zone
          if (timeInDangerZone > 10) {
            // After 1 second in danger zone
            damageAccumulated += 0.15; // Gradual damage
          }
        }
        // CRITICAL ZONE: 95-100°C (Rapid damage, minimal progress)
        else if (temperature > 95) {
          heatingProgress += 0.05; // Minimal progress
          timeInDangerZone++;
          damageAccumulated += 0.5; // Rapid damage accumulation
        }
        // TOO COLD ZONE: Below 50°C (No progress)
        else {
          // No progress, but no damage either
          timeInDangerZone = 0;
        }

        // Clamp values
        heatingProgress = heatingProgress.clamp(0.0, 100.0);
        damageAccumulated = damageAccumulated.clamp(0.0, 100.0);

        // Check if heating is complete
        if (heatingProgress >= 100.0 && !heatingComplete) {
          heatingComplete = true;
          timer.cancel();
          _calculateTemperatureScore();
        }
      });
    });
  }

  void _adjustTemperature(double delta) {
    setState(() {
      temperature = (temperature + delta).clamp(40.0, 100.0);
    });
  }

  void _calculateTemperatureScore() {
    // Calculate temperature maintenance quality based on damage
    if (damageAccumulated <= 5) {
      temperatureMaintained = 1.2; // Perfect heating: +20% bonus
    } else if (damageAccumulated <= 15) {
      temperatureMaintained = 1.0; // Good heating: standard yield
    } else if (damageAccumulated <= 30) {
      temperatureMaintained = 0.85; // Fair heating: -15% penalty
    } else if (damageAccumulated <= 50) {
      temperatureMaintained = 0.7; // Poor heating: -30% penalty
    } else {
      temperatureMaintained = 0.5; // Critical damage: -50% penalty
    }

    setState(() {
      currentPhase = 4;
      swipeCount = 0;
      filteringTimeLeft = 15;
      filterPosition = 0.0;
    });

    _startFilteringGame();
  }

  void _startFilteringGame() {
    // Initialize impurity particles
    final random = math.Random();
    impurityParticles = List.generate(25, (index) {
      return {
        'id': index,
        'x': 40.0 + random.nextDouble() * 200, // Spread across filter area
        'y': 20.0 + random.nextDouble() * 80, // Top section
        'size': 8.0 + random.nextDouble() * 12, // Varied sizes
        'removed': false,
        'falling': false,
        'fallSpeed': 0.5 + random.nextDouble() * 1.0,
      };
    });

    setState(() {
      filteringProgress = 0.0;
      impurityLevel = 100.0;
      swipeCount = 0;
      filteringTimeLeft = 30;
      consecutiveSwipes = 0;
      isFiltering = false;
    });

    filteringTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        filteringTimeLeft--;

        // Natural settling - small progress even without swiping
        if (filteringProgress < 100) {
          filteringProgress += 0.3;
          impurityLevel = math.max(0, 100 - filteringProgress);
        }

        // Reset consecutive swipes if no recent activity
        if (lastSwipeTime != null &&
            DateTime.now().difference(lastSwipeTime!).inSeconds > 2) {
          consecutiveSwipes = 0;
        }

        // Auto-complete if progress reaches 100% OR time runs out
        if (filteringProgress >= 100.0 || filteringTimeLeft <= 0) {
          timer.cancel();
          _calculateFilteringScore();
        }
      });
    });
  }

  void _onFilterSwipe(DragUpdateDetails details) {
    // Safety check: Don't process if filtering is complete
    if (filteringProgress >= 100.0) return;
    
    // Safety check: Don't process if timer is cancelled
    if (filteringTimer == null || !filteringTimer!.isActive) return;
    
    // Safety check: Ensure we have valid delta information
    if (details.delta.dx.isNaN || details.delta.dx.isInfinite) return;

    setState(() {
      filterPosition += details.delta.dx;
      isFiltering = true;

      // Track consecutive swipes for bonus
      if (lastSwipeTime != null &&
          DateTime.now().difference(lastSwipeTime!).inMilliseconds < 500) {
        consecutiveSwipes = math.min(consecutiveSwipes + 1, 10);
      } else {
        consecutiveSwipes = 1;
      }
      lastSwipeTime = DateTime.now();

      // Complete swipe cycle
      if (filterPosition.abs() > 60) {
        swipeCount++;
        filterPosition = 0;

        // Calculate progress boost based on consecutive swipes (bonus for rhythm)
        double progressBoost = 3.5 + (consecutiveSwipes * 0.3);
        filteringProgress = math.min(100.0, filteringProgress + progressBoost);
        impurityLevel = math.max(0, 100 - filteringProgress);

        // Visual feedback
        filterClothSag = 15.0;

        // Remove impurity particles progressively
        int particlesToRemove = (swipeCount / 3).floor();
        for (
          int i = 0;
          i < impurityParticles.length && particlesToRemove > 0;
          i++
        ) {
          if (!impurityParticles[i]['removed'] &&
              !impurityParticles[i]['falling']) {
            impurityParticles[i]['falling'] = true;
            particlesToRemove--;
          }
        }

        // Animate particles falling - with safety check
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && filteringTimer != null && filteringTimer!.isActive) {
            setState(() {
              for (var particle in impurityParticles) {
                if (particle['falling'] && !particle['removed']) {
                  particle['y'] += particle['fallSpeed'] * 20;
                  if (particle['y'] > 300) {
                    particle['removed'] = true;
                  }
                }
              }
            });
          }
        });
        
        // Check if we've reached 100% and auto-complete
        if (filteringProgress >= 100.0) {
          filteringTimer?.cancel();
          // Delay slightly to allow final animation frame
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _calculateFilteringScore();
            }
          });
        }
      }

      // Reset sag animation - with safety check
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && filteringTimer != null && filteringTimer!.isActive) {
          setState(() {
            filterClothSag = 0.0;
            isFiltering = false;
          });
        }
      });
    });
  }

  void _calculateFilteringScore() {
    // Base purity on actual progress achieved
    double achievedPurity = filteringProgress / 100.0;

    // Time bonus: finished faster = better quality
    double timeBonus = filteringTimeLeft > 0
        ? (filteringTimeLeft / 30.0) * 0.15
        : 0.0;

    // Technique bonus: consistent swiping
    double techniqueBonus = math.min(consecutiveSwipes / 50.0, 0.1);

    // Calculate final purity (0.7 to 1.0 range)
    filteringPurity =
        (0.7 + (achievedPurity * 0.3) + timeBonus + techniqueBonus).clamp(
          0.7,
          1.0,
        );

    _calculateFinalResults();
  }

  void _calculateFinalResults() {
    // Base yield from recipe
    int baseYield = 8; // ml per recipe

    // Apply all multipliers
    double finalYield =
        baseYield *
        qualityMultiplier *
        crushingEfficiency *
        temperatureMaintained *
        filteringPurity;

    dyeProduced = finalYield.round();

    // Calculate EcoCoins (base 5 per ml)
    ecoCoinsEarned = (dyeProduced * 5).toInt();

    // Bonus for high performance
    if (crushingEfficiency > 1.1 && filteringPurity > 0.9) {
      ecoCoinsEarned = (ecoCoinsEarned * 1.3).toInt();
    }

    setState(() {
      currentPhase = 5;
    });
  }


  bool _hasEnoughMaterialsForAnyCraft() {
    return materials.values.any((amount) => amount >= 5);
  }

  List<String> _getCraftableRecipes() {
    List<String> craftable = [];
    Map<String, Map<String, int>> allRecipes = {
      'Green Dye': {'🍃 Leaves': 10},
      'Brown Dye': {'🪵 Bark': 10},
      'Yellow Dye': {'🌿 Roots': 10},
      'Red Dye': {'🌺 Flowers': 10},
      'Purple Dye': {'🫐 Fruits': 10},
      'Blue Dye': {'🍃 Leaves': 5, '🫐 Fruits': 5},
      'Orange Dye': {'🌿 Roots': 5, '🌺 Flowers': 5},
      'Teal Dye': {'🍃 Leaves': 5, '🪵 Bark': 5},
    };

    allRecipes.forEach((recipe, requirements) {
      bool canCraft = true;
      requirements.forEach((material, needed) {
        if ((materials[material] ?? 0) < needed) {
          canCraft = false;
        }
      });
      if (canCraft) craftable.add(recipe);
    });

    return craftable;
  }

  void _showInsufficientMaterialsDialog() {
    List<String> craftable = _getCraftableRecipes();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1E17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Insufficient Materials',
          style: GoogleFonts.vt323(fontSize: 22, color: Colors.amber),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              craftable.isEmpty
                  ? 'You don\'t have enough materials to craft any more dyes.'
                  : 'You can still craft:',
              style: GoogleFonts.vt323(fontSize: 16, color: Colors.white70),
            ),
            if (craftable.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...craftable.map(
                (recipe) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '• $recipe',
                    style: GoogleFonts.vt323(fontSize: 16, color: Colors.green),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.vt323(fontSize: 18, color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A1B),
      body: SafeArea(child: _buildCurrentPhase()),
    );
  }

  Widget _buildCurrentPhase() {
    switch (currentPhase) {
      case 0:
        return _buildTransitionScreen();
      case 1:
        return _buildWorkshopScreen();
      case 2:
        return _buildCrushingGame();
      case 3:
        return _buildTemperatureGame();
      case 4:
        return _buildFilteringGame();
      case 5:
        return _buildCompletionScreen();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTransitionScreen() {
    // Determine quality color
    Color qualityColor;
    if (materialQuality == 'Premium Harvest') {
      qualityColor = Colors.greenAccent;
    } else if (materialQuality == 'Quality Harvest') {
      qualityColor = Colors.amber;
    } else {
      qualityColor = Colors.orange;
    }

    return FadeTransition(
      opacity: _transitionController,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FOREST RESTORED!',
                  style: GoogleFonts.vt323(
                    fontSize: 36,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade900.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Materials Harvested:',
                        style: GoogleFonts.vt323(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...materials.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${entry.key}:',
                                  style: GoogleFonts.vt323(
                                    fontSize: 20,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              Text(
                                '${entry.value}',
                                style: GoogleFonts.vt323(
                                  fontSize: 20,
                                  color: qualityColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // UPDATED: Better quality display with detailed info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: qualityColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: qualityColor, width: 2),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  materialQuality == 'Premium Harvest'
                                      ? Icons.stars
                                      : materialQuality == 'Quality Harvest'
                                      ? Icons.star
                                      : Icons.eco,
                                  color: qualityColor,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        materialQuality.toUpperCase(),
                                        style: GoogleFonts.vt323(
                                          fontSize: 20,
                                          color: qualityColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _getQualityDescription(),
                                        style: GoogleFonts.vt323(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.trending_up,
                                    color: qualityColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Dye Yield Bonus: +${((qualityMultiplier - 1) * 100).toInt()}%',
                                    style: GoogleFonts.vt323(
                                      fontSize: 18,
                                      color: qualityColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _startWorkshop,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    'PROCEED TO DYE WORKSHOP',
                    style: GoogleFonts.vt323(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getQualityDescription() {
    switch (materialQuality) {
      case 'Premium Harvest':
        return 'Swift restoration! Materials collected at peak potency.';
      case 'Quality Harvest':
        return 'Efficient work! Materials in good condition.';
      case 'Basic Harvest':
        return 'Task completed. Materials suitable for processing.';
      default:
        return '';
    }
  }

  Widget _buildWorkshopScreen() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Text(
                'DYE EXTRACTION WORKSHOP',
                style: GoogleFonts.vt323(
                  fontSize: 28,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Materials Inventory
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade900.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AVAILABLE MATERIALS',
                      style: GoogleFonts.vt323(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Colors.green),
                    ...materials.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                entry.key,
                                style: GoogleFonts.vt323(
                                  fontSize: 18,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: GoogleFonts.vt323(
                                fontSize: 18,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Recipe Book
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1E17),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DYE RECIPES',
                      style: GoogleFonts.vt323(
                        fontSize: 20,
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Colors.amber),

                    // Basic Dyes
                    Text(
                      'BASIC DYES:',
                      style: GoogleFonts.vt323(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildRecipeButton(
                      'Green Dye',
                      '10 Leaves',
                      Colors.green,
                      _canCraftRecipe('Green Dye'),
                    ),
                    _buildRecipeButton(
                      'Brown Dye',
                      '10 Bark',
                      Colors.brown,
                      _canCraftRecipe('Brown Dye'),
                    ),
                    _buildRecipeButton(
                      'Yellow Dye',
                      '10 Roots',
                      Colors.yellow,
                      _canCraftRecipe('Yellow Dye'),
                    ),
                    _buildRecipeButton(
                      'Red Dye',
                      '10 Flowers',
                      Colors.red,
                      _canCraftRecipe('Red Dye'),
                    ),
                    _buildRecipeButton(
                      'Purple Dye',
                      '10 Fruits',
                      Colors.purple,
                      _canCraftRecipe('Purple Dye'),
                    ),

                    const SizedBox(height: 12),

                    // Mixed Dyes
                    Text(
                      'MIXED DYES:',
                      style: GoogleFonts.vt323(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildRecipeButton(
                      'Blue Dye',
                      '5 Leaves + 5 Fruits',
                      Colors.blue,
                      _canCraftRecipe('Blue Dye'),
                    ),
                    _buildRecipeButton(
                      'Orange Dye',
                      '5 Roots + 5 Flowers',
                      Colors.orange,
                      _canCraftRecipe('Orange Dye'),
                    ),
                    _buildRecipeButton(
                      'Teal Dye',
                      '5 Leaves + 5 Bark',
                      Colors.teal,
                      _canCraftRecipe('Teal Dye'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (selectedRecipe != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dyeColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dyeColor, width: 3),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Selected: $selectedRecipe',
                        style: GoogleFonts.vt323(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _startCrushing,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          'START EXTRACTION',
                          style: GoogleFonts.vt323(fontSize: 20),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Extra padding at bottom
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeButton(
    String name,
    String requirements,
    Color color,
    bool canCraft,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: canCraft ? () => _selectRecipe(name, color, name) : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: canCraft
                ? color.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedRecipe == name
                  ? Colors.amber
                  : (canCraft ? color : Colors.grey),
              width: selectedRecipe == name ? 3 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: canCraft ? color : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.vt323(
                        fontSize: 18,
                        color: canCraft ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      requirements,
                      style: GoogleFonts.vt323(
                        fontSize: 14,
                        color: canCraft ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (!canCraft)
                const Icon(Icons.lock, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrushingGame() {
    // Calculate crushing progress (0-100%)
    double crushingProgress = (tapCount / 80.0 * 100).clamp(0.0, 100.0);

    // Determine crushing quality based on progress
    String crushingQuality;
    Color qualityColor;
    if (crushingProgress >= 90) {
      crushingQuality = 'PERFECTLY CRUSHED';
      qualityColor = Colors.greenAccent;
    } else if (crushingProgress >= 70) {
      crushingQuality = 'WELL CRUSHED';
      qualityColor = Colors.amber;
    } else if (crushingProgress >= 50) {
      crushingQuality = 'MODERATELY CRUSHED';
      qualityColor = Colors.orange;
    } else {
      crushingQuality = 'COARSELY CRUSHED';
      qualityColor = Colors.red;
    }

    // Dynamic particle system based on crushing progress
    double particleSize = math.max(8.0, 40 - (crushingProgress * 0.32));
    int particleCount = math.min(20, 5 + (crushingProgress / 5).floor());
    double dustOpacity = math.min(0.6, crushingProgress / 150);

    return SafeArea(
      child: Container(
        color: const Color(0xFF1B3A1B),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Text(
                    'CRUSH THE MATERIALS!',
                    style: GoogleFonts.vt323(
                      fontSize: 32,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the mortar rapidly for better extraction',
                    style: GoogleFonts.vt323(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Enhanced Mortar & Pestle Scene
                  GestureDetector(
                    onTapDown: (_) => _onCrushTap(),
                    child: SizedBox(
                      width: 300,
                      height: 320,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Wooden base/table
                          Positioned(
                            bottom: -10,
                            child: Container(
                              width: 320,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.brown.shade600,
                                    Colors.brown.shade800,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Main mortar bowl - outer rim
                          Positioned(
                            bottom: 20,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: const Alignment(-0.3, -0.4),
                                  radius: 1.2,
                                  colors: [
                                    Colors.grey.shade400,
                                    Colors.grey.shade600,
                                    Colors.grey.shade800,
                                    Colors.grey.shade900,
                                  ],
                                  stops: const [0.0, 0.4, 0.7, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 15),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 60,
                                    spreadRadius: 10,
                                    offset: const Offset(0, 25),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Inner mortar bowl with materials
                          Positioned(
                            bottom: 40,
                            child: Container(
                              width: 240,
                              height: 240,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.85,
                                  colors: [
                                    Colors.grey.shade800,
                                    Colors.grey.shade900,
                                    Colors.black87,
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                              ),
                              child: ClipOval(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Background dust/powder cloud
                                    if (crushingProgress > 20)
                                      Positioned.fill(
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          opacity: dustOpacity,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  dyeColor.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  dyeColor.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  Colors.transparent,
                                                ],
                                                stops: const [0.0, 0.5, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Scattered material particles
                                    ...List.generate(particleCount, (index) {
                                      // Create consistent random positions using index as seed
                                      final random = math.Random(index);
                                      double angle =
                                          (index / particleCount) *
                                              2 *
                                              math.pi +
                                          (random.nextDouble() * 0.5);
                                      double radius =
                                          20 + (random.nextDouble() * 65);
                                      double xPos = math.cos(angle) * radius;
                                      double yPos = math.sin(angle) * radius;

                                      // Particle rotation for more natural look
                                      double rotation =
                                          random.nextDouble() * math.pi;

                                      return AnimatedPositioned(
                                        duration: const Duration(
                                          milliseconds: 400,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        left: 120 + xPos - (particleSize / 2),
                                        top: 120 + yPos - (particleSize / 2),
                                        child: Transform.rotate(
                                          angle: rotation,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 400,
                                            ),
                                            width: particleSize,
                                            height: particleSize,
                                            decoration: BoxDecoration(
                                              color: dyeColor.withValues(
                                                alpha:
                                                    0.7 +
                                                    (crushingProgress / 333),
                                              ),
                                              borderRadius: BorderRadius.circular(
                                                // Becomes more rounded/powder-like as crushing progresses
                                                particleSize *
                                                    (0.2 +
                                                        (crushingProgress /
                                                            200)),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: dyeColor.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  blurRadius: 3,
                                                  spreadRadius: 0.5,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),

                                    // Fine dust particles (appear at higher progress)
                                    if (crushingProgress > 40)
                                      ...List.generate(12, (index) {
                                        final random = math.Random(index + 100);
                                        double angle =
                                            (index / 12) * 2 * math.pi +
                                            (random.nextDouble() * 0.8);
                                        double radius =
                                            30 + (random.nextDouble() * 50);
                                        double xPos = math.cos(angle) * radius;
                                        double yPos = math.sin(angle) * radius;

                                        return Positioned(
                                          left: 120 + xPos - 3,
                                          top: 120 + yPos - 3,
                                          child: AnimatedOpacity(
                                            duration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            opacity: dustOpacity * 0.8,
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: dyeColor.withValues(
                                                  alpha: 0.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: dyeColor.withValues(
                                                      alpha: 0.3,
                                                    ),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),

                                    // Powder accumulation at bottom (high progress)
                                    if (crushingProgress > 60)
                                      Positioned(
                                        bottom: 0,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          width: 180,
                                          height: 40 + (crushingProgress / 5),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                dyeColor.withValues(alpha: 0.0),
                                                dyeColor.withValues(alpha: 0.4),
                                                dyeColor.withValues(alpha: 0.7),
                                              ],
                                            ),
                                            borderRadius:
                                                const BorderRadius.only(
                                                  bottomLeft: Radius.circular(
                                                    100,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    100,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Animated Pestle with realistic crushing motion
                          AnimatedBuilder(
                            animation: _crushingController,
                            builder: (context, child) {
                              // Smooth crushing motion with easing
                              double pestleOffset =
                                  -30 *
                                  math.sin(_crushingController.value * math.pi);
                              double pestleRotation =
                                  0.15 *
                                  math.sin(
                                    _crushingController.value * math.pi * 2,
                                  );
                              double pestleScale =
                                  1.0 - (0.05 * _crushingController.value);

                              return Positioned(
                                top: 0,
                                right: 40,
                                child: Transform.scale(
                                  scale: pestleScale,
                                  child: Transform.translate(
                                    offset: Offset(0, pestleOffset),
                                    child: Transform.rotate(
                                      angle: pestleRotation - 0.3,
                                      origin: const Offset(0, 80),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Pestle handle (wooden)
                                          Container(
                                            width: 22,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                              gradient: LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                colors: [
                                                  Colors.brown.shade400,
                                                  Colors.brown.shade600,
                                                  Colors.brown.shade400,
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(4, 4),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Handle grip texture
                                          Container(
                                            width: 24,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Colors.brown.shade700,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            width: 24,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Colors.brown.shade700,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Pestle head (stone)
                                          Container(
                                            width: 40,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(
                                                      20,
                                                    ),
                                                    topRight: Radius.circular(
                                                      20,
                                                    ),
                                                    bottomLeft: Radius.circular(
                                                      20,
                                                    ),
                                                    bottomRight:
                                                        Radius.circular(20),
                                                  ),
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.grey.shade300,
                                                  Colors.grey.shade500,
                                                  Colors.grey.shade700,
                                                  Colors.grey.shade600,
                                                ],
                                                stops: const [
                                                  0.0,
                                                  0.3,
                                                  0.7,
                                                  1.0,
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 12,
                                                  offset: const Offset(3, 5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Impact effect particles (spawn on tap)
                          if (_crushingController.isAnimating &&
                              crushingProgress < 95)
                            Positioned(
                              bottom: 140,
                              child: AnimatedBuilder(
                                animation: _crushingController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: 1.0 - _crushingController.value,
                                    child: Container(
                                      width: 60 * _crushingController.value,
                                      height: 60 * _crushingController.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: dyeColor.withValues(
                                            alpha:
                                                0.6 *
                                                (1.0 -
                                                    _crushingController.value),
                                          ),
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                          // Tap prompt indicator
                          Positioned(
                            bottom: 10,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: crushingProgress < 20 ? 1.0 : 0.0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.touch_app,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'TAP HERE',
                                      style: GoogleFonts.vt323(
                                        fontSize: 18,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Enhanced Progress Display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: qualityColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: qualityColor.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Quality Status with icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              crushingProgress >= 90
                                  ? Icons.workspace_premium
                                  : crushingProgress >= 70
                                  ? Icons.thumb_up
                                  : crushingProgress >= 50
                                  ? Icons.trending_up
                                  : Icons.hourglass_bottom,
                              color: qualityColor,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                crushingQuality,
                                style: GoogleFonts.vt323(
                                  fontSize: 24,
                                  color: qualityColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Large progress percentage
                        Text(
                          '${crushingProgress.toInt()}%',
                          style: GoogleFonts.vt323(
                            fontSize: 48,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: qualityColor.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Animated progress bar
                        Container(
                          width: double.infinity,
                          height: 35,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.amber, width: 2),
                          ),
                          child: Stack(
                            children: [
                              // Animated progress fill
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width:
                                    (MediaQuery.of(context).size.width - 88) *
                                    (crushingProgress / 100),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      qualityColor,
                                      qualityColor.withValues(alpha: 0.7),
                                      qualityColor,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: qualityColor.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              // Milestone markers
                              Positioned.fill(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [50, 70, 90].map((milestone) {
                                    bool reached =
                                        crushingProgress >= milestone;
                                    return Container(
                                      width: 3,
                                      decoration: BoxDecoration(
                                        color: reached
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                        boxShadow: reached
                                            ? [
                                                BoxShadow(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Stats grid
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildCrushingStat(
                              icon: Icons.touch_app,
                              label: 'Taps',
                              value: '$tapCount',
                              color: Colors.blue,
                            ),
                            _buildCrushingStat(
                              icon: Icons.speed,
                              label: 'Rate',
                              value:
                                  '${(tapCount / 80 * 100).toStringAsFixed(0)}%',
                              color: Colors.green,
                            ),
                            _buildCrushingStat(
                              icon: Icons.flag,
                              label: 'Goal',
                              value: '100%',
                              color: Colors.amber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quality tier indicators with better visuals
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Quality Tiers & Bonuses:',
                              style: GoogleFonts.vt323(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildQualityTier(
                          '90-100%',
                          'Perfect (+30% yield)',
                          Colors.greenAccent,
                          crushingProgress >= 90,
                        ),
                        _buildQualityTier(
                          '70-89%',
                          'Good (+15% yield)',
                          Colors.amber,
                          crushingProgress >= 70 && crushingProgress < 90,
                        ),
                        _buildQualityTier(
                          '50-69%',
                          'Fair (standard)',
                          Colors.orange,
                          crushingProgress >= 50 && crushingProgress < 70,
                        ),
                        _buildQualityTier(
                          '0-49%',
                          'Poor (-15% yield)',
                          Colors.red,
                          crushingProgress < 50,
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
    );
  }

  Widget _buildCrushingStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.vt323(fontSize: 14, color: Colors.white70),
        ),
        Text(
          value,
          style: GoogleFonts.vt323(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQualityTier(
    String range,
    String label,
    Color color,
    bool active,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : Colors.grey.shade700,
              border: Border.all(
                color: active ? color : Colors.grey.shade600,
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$range - $label',
            style: GoogleFonts.vt323(
              fontSize: 14,
              color: active ? color : Colors.white54,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureGame() {
    bool inOptimalZone = temperature >= 60 && temperature <= 80;
    bool inAcceptableZone =
        (temperature >= 50 && temperature < 60) ||
        (temperature > 80 && temperature <= 85);
    bool inDangerZone = temperature > 85 && temperature <= 95;
    bool inCriticalZone = temperature > 95;
    //bool tooCold = temperature < 50;

    // Determine current zone status
    String zoneStatus;
    Color zoneColor;
    IconData zoneIcon;

    if (inCriticalZone) {
      zoneStatus = 'CRITICAL! BURNING!';
      zoneColor = Colors.red;
      zoneIcon = Icons.local_fire_department;
    } else if (inDangerZone) {
      zoneStatus = 'DANGER ZONE!';
      zoneColor = Colors.orange;
      zoneIcon = Icons.warning;
    } else if (inOptimalZone) {
      zoneStatus = 'OPTIMAL HEATING';
      zoneColor = Colors.green;
      zoneIcon = Icons.check_circle;
    } else if (inAcceptableZone) {
      zoneStatus = 'ACCEPTABLE';
      zoneColor = Colors.amber;
      zoneIcon = Icons.schedule;
    } else {
      zoneStatus = 'TOO COLD';
      zoneColor = Colors.blue;
      zoneIcon = Icons.ac_unit;
    }

    // Calculate bubble intensity and color based on temperature
    int bubbleCount = ((temperature - 40) / 10).floor().clamp(0, 6);
    Color liquidColor = inCriticalZone
        ? Colors.red.withValues(alpha: 0.8)
        : inDangerZone
        ? Colors.orange.withValues(alpha: 0.7)
        : dyeColor.withValues(alpha: 0.6);

    return SafeArea(
      child: Container(
        color: const Color(0xFF1B3A1B),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Text(
                    'HEAT EXTRACTION PROCESS',
                    style: GoogleFonts.vt323(
                      fontSize: 32,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Maintain optimal temperature to complete heating',
                    style: GoogleFonts.vt323(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  // 3D-styled Laboratory Heating Setup
                  SizedBox(
                    height: 400,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Laboratory table/surface
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: 350,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.grey.shade700,
                                  Colors.grey.shade900,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Bunsen burner / Heat source base
                        Positioned(
                          bottom: 40,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Flame effect
                              AnimatedBuilder(
                                animation: _bubbleController,
                                builder: (context, child) {
                                  double flameHeight = temperature > 50
                                      ? 60 + (temperature - 50) * 1.5
                                      : 30;
                                  double flameWidth =
                                      40 + (temperature - 50) * 0.5;

                                  return Container(
                                    width: flameWidth.clamp(30, 100),
                                    height: flameHeight.clamp(20, 140),
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment.bottomCenter,
                                        radius: 1.2,
                                        colors: inCriticalZone
                                            ? [
                                                Colors.white,
                                                Colors.red,
                                                Colors.deepOrange,
                                                Colors.orange.withValues(
                                                  alpha: 0.0,
                                                ),
                                              ]
                                            : inDangerZone
                                            ? [
                                                Colors.yellow,
                                                Colors.orange,
                                                Colors.deepOrange,
                                                Colors.orange.withValues(
                                                  alpha: 0.0,
                                                ),
                                              ]
                                            : [
                                                Colors.blue.shade200,
                                                Colors.blue,
                                                Colors.orange,
                                                Colors.orange.withValues(
                                                  alpha: 0.0,
                                                ),
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        flameWidth / 2,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Burner base
                              Container(
                                width: 80,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.grey.shade600,
                                      Colors.grey.shade800,
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                  border: Border.all(
                                    color: Colors.grey.shade900,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Flask/Beaker with liquid
                        Positioned(
                          bottom: 140,
                          child: AnimatedBuilder(
                            animation: _bubbleController,
                            builder: (context, child) {
                              return Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  // Flask body - rounded bottom
                                  Container(
                                    width: 180,
                                    height: 220,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(20),
                                        bottomLeft: Radius.circular(90),
                                        bottomRight: Radius.circular(90),
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(18),
                                        topRight: Radius.circular(18),
                                        bottomLeft: Radius.circular(88),
                                        bottomRight: Radius.circular(88),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Liquid fill
                                          Positioned.fill(
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    liquidColor.withValues(
                                                      alpha: 0.4,
                                                    ),
                                                    liquidColor,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Steam/vapor effect at top
                                          if (temperature > 70)
                                            Positioned(
                                              top: -20,
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 500,
                                                ),
                                                opacity:
                                                    ((temperature - 70) / 30)
                                                        .clamp(0.0, 0.8),
                                                child: Container(
                                                  width: 100,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment
                                                          .bottomCenter,
                                                      end: Alignment.topCenter,
                                                      colors: [
                                                        Colors.white.withValues(
                                                          alpha: 0.5,
                                                        ),
                                                        Colors.white.withValues(
                                                          alpha: 0.2,
                                                        ),
                                                        Colors.white.withValues(
                                                          alpha: 0.0,
                                                        ),
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          50,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Animated bubbles
                                          ...List.generate(bubbleCount, (
                                            index,
                                          ) {
                                            double offset =
                                                (_bubbleController.value *
                                                    180) +
                                                (index * 30);
                                            double x =
                                                30 +
                                                (index * 25.0) +
                                                (math.sin(
                                                      _bubbleController.value *
                                                              2 *
                                                              math.pi +
                                                          index,
                                                    ) *
                                                    15);

                                            return Positioned(
                                              bottom: offset % 180,
                                              left: x,
                                              child: Container(
                                                width: 8 + (index * 2.0),
                                                height: 8 + (index * 2.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.6),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.4),
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),

                                          // Temperature display inside flask
                                          Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.6,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: zoneColor,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Text(
                                                '${temperature.toInt()}°C',
                                                style: GoogleFonts.vt323(
                                                  fontSize: 36,
                                                  color: zoneColor,
                                                  fontWeight: FontWeight.bold,
                                                  shadows: [
                                                    Shadow(
                                                      color: zoneColor
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                      blurRadius: 10,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Flask neck/opening
                                  Positioned(
                                    top: -30,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 4,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          topRight: Radius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Heating Progress & Status Display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: zoneColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: zoneColor.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Zone Status with icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(zoneIcon, color: zoneColor, size: 32),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                zoneStatus,
                                style: GoogleFonts.vt323(
                                  fontSize: 24,
                                  color: zoneColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Heating Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'HEATING PROGRESS',
                                  style: GoogleFonts.vt323(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${heatingProgress.toInt()}%',
                                  style: GoogleFonts.vt323(
                                    fontSize: 24,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width:
                                        (MediaQuery.of(context).size.width -
                                            88) *
                                        (heatingProgress / 100),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(13),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green,
                                          Colors.greenAccent,
                                          Colors.green,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withValues(
                                            alpha: 0.6,
                                          ),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Damage Indicator
                        if (damageAccumulated > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'DAMAGE',
                                        style: GoogleFonts.vt323(
                                          fontSize: 18,
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${damageAccumulated.toInt()}%',
                                    style: GoogleFonts.vt323(
                                      fontSize: 20,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width:
                                          (MediaQuery.of(context).size.width -
                                              88) *
                                          (damageAccumulated / 100),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.red,
                                            Colors.orange,
                                            Colors.red,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Temperature Control Slider
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TEMPERATURE CONTROL',
                          style: GoogleFonts.vt323(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Visual temperature scale
                        Row(
                          children: [
                            // Cold indicator
                            Column(
                              children: [
                                Icon(
                                  Icons.ac_unit,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                Text(
                                  '40°',
                                  style: GoogleFonts.vt323(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),

                            // Slider
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 20,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 15,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 25,
                                  ),
                                ),
                                child: Slider(
                                  value: temperature,
                                  min: 40,
                                  max: 100,
                                  divisions: 60,
                                  activeColor: zoneColor,
                                  inactiveColor: Colors.grey.shade700,
                                  thumbColor: Colors.white,
                                  onChanged: (value) {
                                    setState(() {
                                      temperature = value;
                                    });
                                  },
                                ),
                              ),
                            ),

                            // Hot indicator
                            Column(
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                Text(
                                  '100°',
                                  style: GoogleFonts.vt323(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Quick adjustment buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildTempButton(
                              icon: Icons.remove_circle,
                              label: '-5°',
                              color: Colors.blue,
                              onPressed: () => _adjustTemperature(-5),
                            ),
                            _buildTempButton(
                              icon: Icons.remove,
                              label: '-1°',
                              color: Colors.lightBlue,
                              onPressed: () => _adjustTemperature(-1),
                            ),
                            _buildTempButton(
                              icon: Icons.add,
                              label: '+1°',
                              color: Colors.orange,
                              onPressed: () => _adjustTemperature(1),
                            ),
                            _buildTempButton(
                              icon: Icons.add_circle,
                              label: '+5°',
                              color: Colors.red,
                              onPressed: () => _adjustTemperature(5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Temperature Zone Guide
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Temperature Zones:',
                              style: GoogleFonts.vt323(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTempZoneInfo(
                          '60-80°C',
                          'Optimal (Fast progress)',
                          Colors.green,
                        ),
                        _buildTempZoneInfo(
                          '50-60°C, 80-85°C',
                          'Acceptable (Slow)',
                          Colors.amber,
                        ),
                        _buildTempZoneInfo(
                          '85-95°C',
                          'Danger (Damage!)',
                          Colors.orange,
                        ),
                        _buildTempZoneInfo(
                          '95-100°C',
                          'Critical (High damage!)',
                          Colors.red,
                        ),
                        _buildTempZoneInfo(
                          'Below 50°C',
                          'Too cold (No progress)',
                          Colors.blue,
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
    );
  }

  Widget _buildTempButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.vt323(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildTempZoneInfo(String range, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$range: ',
                    style: GoogleFonts.vt323(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: GoogleFonts.vt323(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteringGame() {
    // Calculate quality indicators
    String qualityStatus;
    Color qualityColor;
    IconData qualityIcon;

    if (filteringProgress >= 90) {
      qualityStatus = 'CRYSTAL CLEAR';
      qualityColor = Colors.greenAccent;
      qualityIcon = Icons.water_drop;
    } else if (filteringProgress >= 70) {
      qualityStatus = 'WELL FILTERED';
      qualityColor = Colors.green;
      qualityIcon = Icons.check_circle;
    } else if (filteringProgress >= 50) {
      qualityStatus = 'FILTERING...';
      qualityColor = Colors.amber;
      qualityIcon = Icons.hourglass_empty;
    } else if (filteringProgress >= 30) {
      qualityStatus = 'MURKY';
      qualityColor = Colors.orange;
      qualityIcon = Icons.warning;
    } else {
      qualityStatus = 'VERY CLOUDY';
      qualityColor = Colors.red;
      qualityIcon = Icons.cloud;
    }

    // Calculate liquid color - transitions from murky to clear
    Color liquidColor = Color.lerp(
      dyeColor.withValues(alpha: 0.3), // Murky/diluted
      dyeColor.withValues(alpha: 0.9), // Clear/vibrant
      filteringProgress / 100.0,
    )!;

    return SafeArea(
      child: Container(
        color: const Color(0xFF1B3A1B),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Text(
                    'FILTRATION PROCESS',
                    style: GoogleFonts.vt323(
                      fontSize: 32,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Swipe the filter cloth back and forth to remove impurities',
                    style: GoogleFonts.vt323(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  // 3D Filtration Setup
                  SizedBox(
                    height: 450,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Laboratory bench/table
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: 360,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.brown.shade600,
                                  Colors.brown.shade800,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Collection beaker (bottom)
                        Positioned(
                          bottom: 50,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Beaker body
                              Container(
                                width: 200,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 4,
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(15),
                                    bottomRight: Radius.circular(15),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    // Collected filtered dye
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      width: 192,
                                      height: (filteringProgress / 100.0) * 160,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            liquidColor.withValues(alpha: 0.6),
                                            liquidColor,
                                          ],
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                      ),
                                    ),

                                    // Surface shimmer effect
                                    if (filteringProgress > 10)
                                      Positioned(
                                        top:
                                            20 +
                                            ((100 - filteringProgress) /
                                                    100.0) *
                                                140,
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          opacity: 0.3,
                                          child: Container(
                                            width: 180,
                                            height: 3,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white.withValues(
                                                    alpha: 0.6,
                                                  ),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Volume markings
                                    Positioned(
                                      left: 8,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: List.generate(4, (index) {
                                          int ml = 50 + (index * 50);
                                          bool filled =
                                              filteringProgress >= (ml / 2);
                                          return Row(
                                            children: [
                                              Container(
                                                width: 15,
                                                height: 1,
                                                color: filled
                                                    ? Colors.white.withValues(
                                                        alpha: 0.6,
                                                      )
                                                    : Colors.white.withValues(
                                                        alpha: 0.3,
                                                      ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${ml}ml',
                                                style: GoogleFonts.vt323(
                                                  fontSize: 12,
                                                  color: filled
                                                      ? Colors.white.withValues(
                                                          alpha: 0.8,
                                                        )
                                                      : Colors.white.withValues(
                                                          alpha: 0.4,
                                                        ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Beaker rim
                              Positioned(
                                top: -4,
                                child: Container(
                                  width: 208,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Funnel with filter cloth
                        Positioned(
                          top: 80,
                          child: GestureDetector(
                            onPanUpdate: _onFilterSwipe,
                            onPanEnd: (_) {
                              setState(() {
                                isFiltering = false;
                              });
                            },
                            child: Stack(
                              alignment: Alignment.topCenter,
                              clipBehavior: Clip.none,
                              children: [
                                // Funnel structure
                                CustomPaint(
                                  size: const Size(280, 200),
                                  painter: FunnelPainter(
                                    rimColor: Colors.grey.shade300,
                                    bodyColor: Colors.grey.shade600,
                                  ),
                                ),

                                // Heated mixture being poured (source)
                                Positioned(
                                  top: -60,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 300),
                                    opacity: filteringProgress < 95 ? 0.8 : 0.2,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            dyeColor.withValues(alpha: 0.7),
                                            dyeColor.withValues(alpha: 0.4),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 3,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.science,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Pour stream
                                if (filteringProgress < 95)
                                  Positioned(
                                    top: 10,
                                    child: Container(
                                      width: 20,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            dyeColor.withValues(alpha: 0.5),
                                            dyeColor.withValues(alpha: 0.7),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),

                                // Filter cloth (moveable) with impurities
                                Positioned(
                                  top: 55,
                                  child: Transform.translate(
                                    offset: Offset(
                                      filterPosition,
                                      filterClothSag,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        clipBehavior: Clip.none,
                                        children: [
                                          // Cloth mesh
                                          Container(
                                            width: 240,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0.9,
                                                  ),
                                                  Colors.grey.shade200
                                                      .withValues(alpha: 0.8),
                                                  Colors.white.withValues(
                                                    alpha: 0.9,
                                                  ),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey.shade400,
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: CustomPaint(
                                              painter: ClothMeshPainter(),
                                            ),
                                          ),

                                          // Impurity particles on filter
                                          ...impurityParticles.map((particle) {
                                            if (particle['removed']) {
                                              return const SizedBox.shrink();
                                            }

                                            double particleX = particle['x'];
                                            double particleY = particle['y'];
                                            double particleSize =
                                                particle['size'];
                                            bool falling = particle['falling'];

                                            return AnimatedPositioned(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              left:
                                                  particleX -
                                                  (particleSize / 2),
                                              top:
                                                  particleY -
                                                  (particleSize / 2),
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                opacity: falling ? 0.3 : 0.9,
                                                child: Container(
                                                  width: particleSize,
                                                  height: particleSize,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.brown.shade700,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          Colors.brown.shade900,
                                                      width: 1,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                        blurRadius: 3,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),

                                          // Active filtering indicator
                                          if (isFiltering)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.blue
                                                        .withValues(alpha: 0.6),
                                                    width: 3,
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Swipe direction indicator
                                          if (filteringProgress < 20)
                                            Positioned(
                                              bottom: -40,
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 500,
                                                ),
                                                opacity: isFiltering
                                                    ? 0.0
                                                    : 1.0,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.arrow_back,
                                                      color: Colors.amber,
                                                      size: 24,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber
                                                            .withValues(
                                                              alpha: 0.9,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'SWIPE HERE',
                                                        style:
                                                            GoogleFonts.vt323(
                                                              fontSize: 16,
                                                              color:
                                                                  Colors.black,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      Icons.arrow_forward,
                                                      color: Colors.amber,
                                                      size: 24,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Filtered droplets falling
                                if (swipeCount > 0)
                                  ...List.generate(3, (index) {
                                    double offset =
                                        (index * 40.0) +
                                        (swipeCount % 3) * 15.0;
                                    return Positioned(
                                      top: 160 + offset,
                                      left: 130 + (index * 15.0),
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 800,
                                        ),
                                        opacity: offset < 80 ? 0.8 : 0.0,
                                        child: Icon(
                                          Icons.water_drop,
                                          color: liquidColor,
                                          size: 16,
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Progress Display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: qualityColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: qualityColor.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Quality Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(qualityIcon, color: qualityColor, size: 32),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                qualityStatus,
                                style: GoogleFonts.vt323(
                                  fontSize: 24,
                                  color: qualityColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Filtration Progress
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'FILTRATION',
                              style: GoogleFonts.vt323(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${filteringProgress.toInt()}%',
                              style: GoogleFonts.vt323(
                                fontSize: 24,
                                color: qualityColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: qualityColor, width: 2),
                          ),
                          child: Stack(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width:
                                    (MediaQuery.of(context).size.width - 88) *
                                    (filteringProgress / 100),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  gradient: LinearGradient(
                                    colors: [
                                      qualityColor,
                                      qualityColor.withValues(alpha: 0.7),
                                      qualityColor,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: qualityColor.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Stats Grid
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFilteringStat(
                              icon: Icons.swap_horiz,
                              label: 'Swipes',
                              value: '$swipeCount',
                              color: Colors.blue,
                            ),
                            _buildFilteringStat(
                              icon: Icons.cleaning_services,
                              label: 'Purity',
                              value: '${(100 - impurityLevel).toInt()}%',
                              color: Colors.green,
                            ),
                            _buildFilteringStat(
                              icon: Icons.timer,
                              label: 'Time',
                              value: '${filteringTimeLeft}s',
                              color: filteringTimeLeft > 15
                                  ? Colors.amber
                                  : Colors.red,
                            ),
                          ],
                        ),

                        // Consecutive swipes bonus indicator
                        if (consecutiveSwipes >= 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.purple,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.purple.shade200,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'RHYTHM BONUS: ${consecutiveSwipes}x',
                                    style: GoogleFonts.vt323(
                                      fontSize: 16,
                                      color: Colors.purple.shade200,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quality Tiers Guide
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Filtration Quality Guide:',
                              style: GoogleFonts.vt323(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildFilterQualityTier(
                          '90-100%',
                          'Crystal Clear (Best yield)',
                          Colors.greenAccent,
                          filteringProgress >= 90,
                        ),
                        _buildFilterQualityTier(
                          '70-89%',
                          'Clear (Good yield)',
                          Colors.green,
                          filteringProgress >= 70 && filteringProgress < 90,
                        ),
                        _buildFilterQualityTier(
                          '50-69%',
                          'Slightly cloudy (Fair)',
                          Colors.amber,
                          filteringProgress >= 50 && filteringProgress < 70,
                        ),
                        _buildFilterQualityTier(
                          '30-49%',
                          'Murky (Reduced yield)',
                          Colors.orange,
                          filteringProgress >= 30 && filteringProgress < 50,
                        ),
                        _buildFilterQualityTier(
                          '0-29%',
                          'Very cloudy (Poor)',
                          Colors.red,
                          filteringProgress < 30,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Technique tips
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.blue.shade200,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip: Maintain a steady swiping rhythm for bonus progress!',
                            style: GoogleFonts.vt323(
                              fontSize: 14,
                              color: Colors.blue.shade100,
                            ),
                          ),
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
    );
  }

  Widget _buildFilteringStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.vt323(fontSize: 14, color: Colors.white70),
        ),
        Text(
          value,
          style: GoogleFonts.vt323(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterQualityTier(
    String range,
    String label,
    Color color,
    bool active,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : Colors.grey.shade700,
              border: Border.all(
                color: active ? color : Colors.grey.shade600,
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$range - $label',
              style: GoogleFonts.vt323(
                fontSize: 14,
                color: active ? color : Colors.white54,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildCompletionScreen() {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF1B3A1B), const Color(0xFF0D1F0D)],
      ),
    ),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive sizing
          bool isPortrait = constraints.maxHeight > constraints.maxWidth;
          bool isTablet = constraints.maxWidth >= 600;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(constraints.maxWidth * 0.04),
            child: ConstrainedBox(
              // FIXED: Add minimum height constraint to prevent overflow
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - (constraints.maxWidth * 0.08),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // FIXED: Changed from max to min
                children: [
                  // Success Header
                  _buildSuccessHeader(constraints),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  // Extraction Summary Card
                  _buildExtractionSummary(constraints),

                  SizedBox(height: constraints.maxHeight * 0.04),

                  // 3D Shelf Display
                  _build3DShelfDisplay(constraints, isPortrait, isTablet),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  // Storage Success Message
                  if (_showStorageSuccess)
                    _buildStorageSuccessMessage(constraints),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  // Action Buttons
                  _buildActionButtons(constraints),
                  
                  // FIXED: Add bottom padding to ensure no overflow
                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildSuccessHeader(BoxConstraints constraints) {
    double iconSize = (constraints.maxWidth * 0.15).clamp(60.0, 120.0);
    double titleSize = (constraints.maxWidth * 0.06).clamp(24.0, 40.0);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Column(
              children: [
                // Animated success icon
                Container(
                  padding: EdgeInsets.all(constraints.maxWidth * 0.04),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.green.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.science,
                    size: iconSize,
                    color: Colors.greenAccent,
                  ),
                ),

                SizedBox(height: constraints.maxHeight * 0.02),

                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      const Color(0xFF86EFAC),
                      const Color(0xFFA7F3D0),
                      const Color(0xFF86EFAC),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'DYE EXTRACTION COMPLETE!',
                    style: GoogleFonts.exo2(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExtractionSummary(BoxConstraints constraints) {
    double cardPadding = constraints.maxWidth * 0.04;
    double fontSize = (constraints.maxWidth * 0.028).clamp(12.0, 18.0);

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dyeColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: dyeColor.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.assessment, color: dyeColor, size: fontSize * 1.5),
              SizedBox(width: cardPadding * 0.5),
              Text(
                'EXTRACTION REPORT',
                style: GoogleFonts.exo2(
                  fontSize: fontSize * 1.2,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          SizedBox(height: cardPadding * 0.6),
          Divider(color: dyeColor.withValues(alpha: 0.3)),
          SizedBox(height: cardPadding * 0.6),

          // Stats Grid
          _buildStatRow(
            'Dye Type:',
            selectedRecipe ?? 'Unknown',
            Icons.palette,
            fontSize,
          ),
          _buildStatRow(
            'Volume Produced:',
            '$dyeProduced ml',
            Icons.water_drop,
            fontSize,
          ),
          _buildStatRow(
            'Quality:',
            materialQuality,
            Icons.workspace_premium,
            fontSize,
          ),
          _buildStatRow(
            'Efficiency:',
            '${(crushingEfficiency * 100).toInt()}%',
            Icons.trending_up,
            fontSize,
          ),
          _buildStatRow(
            'Purity:',
            '${(filteringPurity * 100).toInt()}%',
            Icons.science,
            fontSize,
          ),

          SizedBox(height: cardPadding * 0.6),
          Divider(color: dyeColor.withValues(alpha: 0.3)),
          SizedBox(height: cardPadding * 0.6),

          // Rewards
          Container(
            padding: EdgeInsets.all(cardPadding * 0.8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monetization_on,
                  color: Colors.amber,
                  size: fontSize * 2,
                ),
                SizedBox(width: cardPadding * 0.5),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ECOCOINS EARNED',
                      style: GoogleFonts.exo2(
                        fontSize: fontSize * 0.8,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$ecoCoinsEarned',
                      style: GoogleFonts.exo2(
                        fontSize: fontSize * 2,
                        color: Colors.amber,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    IconData icon,
    double fontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: fontSize * 1.2,
            color: dyeColor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.exo2(
                fontSize: fontSize,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.exo2(
              fontSize: fontSize,
              color: dyeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DShelfDisplay(
    BoxConstraints constraints,
    bool isPortrait,
    bool isTablet,
  ) {
    // Calculate responsive dimensions
    double shelfWidth = constraints.maxWidth * (isPortrait ? 0.92 : 0.85);
    shelfWidth = shelfWidth.clamp(300.0, 800.0);

    double shelfHeight = isPortrait
        ? constraints.maxHeight * 0.45
        : constraints.maxHeight * 0.6;
    shelfHeight = shelfHeight.clamp(300.0, 600.0);

    if (!_showStorageSuccess && currentPhase == 5 && storedDyes.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_showStorageSuccess) {
          _addDyeToStorage();
        }
      });
    }

    return Container(
      width: shelfWidth,
      height: shelfHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.brown.shade800.withValues(alpha: 0.3),
            Colors.brown.shade900.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            // Background wood texture
            Positioned.fill(child: CustomPaint(painter: WoodTexturePainter())),

            // Shelf structure
            Positioned.fill(
              child: CustomPaint(
                painter: ShelfPainter(
                  shelfCount: _calculateShelfCount(shelfHeight),
                ),
              ),
            ),

            // Dye bottles
            Positioned.fill(
              child: _buildDyeBottlesGrid(
                shelfWidth,
                shelfHeight,
                isPortrait,
                isTablet,
              ),
            ),

            // Shine effect
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _shelfShineController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ShelfShinePainter(
                      progress: _shelfShineController.value,
                    ),
                  );
                },
              ),
            ),

            // Storage label
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: const Color(0xFFD4AF37),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DYE STORAGE CABINET',
                        style: GoogleFonts.exo2(
                          fontSize: (constraints.maxWidth * 0.025).clamp(
                            12.0,
                            16.0,
                          ),
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateShelfCount(double height) {
    if (height < 350) return 2;
    if (height < 450) return 3;
    return 4;
  }

  Widget _buildDyeBottlesGrid(
    double width,
    double height,
    bool isPortrait,
    bool isTablet,
  ) {
    int shelfCount = _calculateShelfCount(height);
    double bottleSpacing = width * 0.02;
    double shelfSpacing = height / (shelfCount + 1);

    // Calculate bottles per shelf based on width
    int bottlesPerShelf = isPortrait ? (isTablet ? 5 : 4) : (isTablet ? 7 : 6);

    double bottleWidth =
        (width - (bottleSpacing * (bottlesPerShelf + 1))) / bottlesPerShelf;
    bottleWidth = bottleWidth.clamp(40.0, 80.0);

    return Stack(
      children: storedDyes.asMap().entries.map((entry) {
        int index = entry.key;
        StoredDye dye = entry.value;

        int shelfIndex = index ~/ bottlesPerShelf;
        int positionOnShelf = index % bottlesPerShelf;

        // Skip if exceeds shelf count
        if (shelfIndex >= shelfCount) return const SizedBox.shrink();

        double left =
            bottleSpacing + (positionOnShelf * (bottleWidth + bottleSpacing));
        double top = shelfSpacing * (shelfIndex + 1) - (bottleWidth * 1.5);

        return Positioned(
          left: left,
          top: top,
          child: _buildDyeBottle(
            dye: dye,
            width: bottleWidth,
            delay: index * 0.15,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDyeBottle({
    required StoredDye dye,
    required double width,
    required double delay,
  }) {
    double height = width * 1.8;

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 800 + (delay * 1000).toInt()),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        // FIXED: Clamp animation value to prevent opacity issues
        final clampedValue = value.clamp(0.0, 1.0);
        
        return Transform.translate(
          offset: Offset(0, -50 * (1 - clampedValue)),
          child: Opacity(
            opacity: clampedValue, // Use clamped value
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Bottle body
                  CustomPaint(
                    size: Size(width, height),
                    painter: BottlePainter(color: dye.color),
                  ),

                  // Label
                  Positioned(
                    bottom: height * 0.15,
                    child: Container(
                      width: width * 0.8,
                      padding: EdgeInsets.symmetric(
                        vertical: height * 0.02,
                        horizontal: width * 0.05,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: dye.color, width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              dye.name,
                              style: GoogleFonts.exo2(
                                fontSize: width * 0.16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(height: height * 0.01),
                          Text(
                            '${dye.volume}ml',
                            style: GoogleFonts.exo2(
                              fontSize: width * 0.14,
                              color: dye.color,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sparkle effect on new bottle
                  if (dye.isNew)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shelfShineController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: SparkleEffectPainter(
                              progress: _shelfShineController.value.clamp(0.0, 1.0),
                              color: dye.color,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorageSuccessMessage(BoxConstraints constraints) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, double value, child) {
        // FIXED: Clamp opacity value to ensure it's always between 0.0 and 1.0
        final clampedOpacity = value.clamp(0.0, 1.0);
        
        return Transform.scale(
          scale: value.clamp(0.0, 1.5), // Also clamp scale to prevent issues
          child: Opacity(
            opacity: clampedOpacity, // Use clamped value
            child: Container(
              padding: EdgeInsets.all(constraints.maxWidth * 0.04),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withValues(alpha:0.2),
                    Colors.green.withValues(alpha:0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent, width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: constraints.maxWidth * 0.08,
                  ),
                  SizedBox(width: constraints.maxWidth * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Successfully Stored!',
                          style: GoogleFonts.exo2(
                            fontSize: (constraints.maxWidth * 0.032).clamp(
                              14.0,
                              20.0,
                            ),
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${dyeProduced}ml of $dyeType added to your collection',
                          style: GoogleFonts.exo2(
                            fontSize: (constraints.maxWidth * 0.024).clamp(
                              12.0,
                              16.0,
                            ),
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BoxConstraints constraints) {
    double fontSize = (constraints.maxWidth * 0.028).clamp(14.0, 18.0);

    bool canCraftMore = _hasEnoughMaterialsForAnyCraft();

    return Row(
      children: [
        // Craft Another Button
        Expanded(
          child: Opacity(
            opacity: canCraftMore ? 1.0 : 0.5,
            child: _buildActionButton(
              icon: Icons.replay,
              label: 'CRAFT ANOTHER',
              gradient: canCraftMore
                  ? const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                    )
                  : const LinearGradient(colors: [Colors.grey, Colors.grey]),
              onPressed: canCraftMore
                  ? () {
                      setState(() {
                        currentPhase = 1;
                        selectedRecipe = null;
                        _showStorageSuccess = false;
                      });
                    }
                  : () => _showInsufficientMaterialsDialog(),
              constraints: constraints,
              fontSize: fontSize,
            ),
          ),
        ),

        SizedBox(width: constraints.maxWidth * 0.03),

        // Finish Button
        Expanded(
          child: _buildActionButton(
            icon: Icons.check_circle,
            label: 'FINISH LEVEL',
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
            ),
            onPressed: () => _showFinalCompletionDialog(),
            constraints: constraints,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    required VoidCallback onPressed,
    required BoxConstraints constraints,
    required double fontSize,
  }) {
    double buttonHeight = (constraints.maxHeight * 0.08).clamp(50.0, 70.0);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: buttonHeight,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.4),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: fontSize * 1.5),
            SizedBox(width: fontSize * 0.5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: GoogleFonts.exo2(
                    fontSize: fontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFinalCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2D1E17),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Phase 2 Complete!',
                style: GoogleFonts.vt323(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 20),

              Text(
                'Total Dye Produced: $dyeProduced ml',
                style: GoogleFonts.vt323(color: Colors.amber, fontSize: 22),
              ),
              const SizedBox(height: 10),

              Text(
                'Total EcoCoins: $ecoCoinsEarned',
                style: GoogleFonts.vt323(color: Colors.green, fontSize: 22),
              ),
              const SizedBox(height: 20),

              Text(
                'Ready for the next challenge: Water Pollution Mission!',
                style: GoogleFonts.vt323(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDialogButton(
                    icon: Icons.replay,
                    label: 'Replay',
                    color: Colors.orange,
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back to previous screen
                      widget.game.restartGame();
                    },
                  ),
                  _buildDialogButton(
                    icon: Icons.play_arrow,
                    label: 'Next Mission',
                    color: Colors.green,
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back from DyeExtractionScreen
                      
                      // Calculate bacteria cultures from dye production
                      // Higher quality dye = more bacteria cultures
                      int bacteriaCultures = (dyeProduced / 2).floor();
                      if (crushingEfficiency > 1.1 && filteringPurity > 0.9) {
                        bacteriaCultures = (bacteriaCultures * 1.5).floor();
                      }
                      bacteriaCultures = bacteriaCultures.clamp(5, 30);
                      
                      // Prepare materials to carry forward
                      Map<String, int> materialsToCarry = {
                        'dye_produced': dyeProduced,
                        'eco_coins': ecoCoinsEarned,
                        'quality_bonus': (qualityMultiplier * 100).toInt(),
                        'crushing_efficiency': (crushingEfficiency * 100).toInt(),
                        'filtering_purity': (filteringPurity * 100).toInt(),
                      };
                      
                      // Navigate to Water Pollution Screen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => WaterPollutionScreen(
                            bacteriaCulturesAvailable: bacteriaCultures,
                            materialsFromPreviousLevel: materialsToCarry,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDialogButton(
                    icon: Icons.exit_to_app,
                    label: 'Exit',
                    color: Colors.red,
                    onPressed: () async {
                      await SystemChannels.platform.invokeMethod(
                        'SystemNavigator.pop',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.vt323(fontSize: 14, color: Colors.white),
        ),
      ],
    );
  }
}

class WoodTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Wood grain lines
    final random = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final y = random.nextDouble() * size.height;
      final path = Path();
      path.moveTo(0, y);

      double x = 0;
      while (x < size.width) {
        x += 20 + random.nextDouble() * 40;
        final controlY = y + (random.nextDouble() - 0.5) * 10;
        path.quadraticBezierTo(x - 20, controlY, x, y);
      }

      paint.color = Colors.brown.shade700.withValues(
        alpha: 0.1 + random.nextDouble() * 0.1,
      );
      paint.strokeWidth = 0.5 + random.nextDouble();
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ShelfPainter extends CustomPainter {
  final int shelfCount;

  ShelfPainter({required this.shelfCount});

  @override
  void paint(Canvas canvas, Size size) {
    final shelfPaint = Paint()..style = PaintingStyle.fill;

    final shelfSpacing = size.height / (shelfCount + 1);

    for (int i = 1; i <= shelfCount; i++) {
      final y = shelfSpacing * i;

      // Shelf board
      final shelfRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y - 8, size.width, 16),
        const Radius.circular(4),
      );

      // Gradient for 3D effect
      shelfPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.brown.shade600,
          Colors.brown.shade800,
          Colors.brown.shade900,
        ],
      ).createShader(shelfRect.outerRect);

      canvas.drawRRect(shelfRect, shelfPaint);

      // Shadow under shelf
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawRect(Rect.fromLTWH(0, y + 8, size.width, 4), shadowPaint);
    }

    // Side supports
    _drawSupport;
  }

  void _drawSupport(Canvas canvas, double x, Size size, Paint paint) {
    final supportRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, 0, 12, size.height),
      const Radius.circular(6),
    );

    paint.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.brown.shade700,
        Colors.brown.shade800,
        Colors.brown.shade700,
      ],
    ).createShader(supportRect.outerRect);

    canvas.drawRRect(supportRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BottlePainter extends CustomPainter {
  final Color color;
  
  BottlePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final bottlePaint = Paint()
      ..style = PaintingStyle.fill;
    
    // Glass bottle outline
    final bottlePath = Path();
    
    // Neck
    bottlePath.moveTo(size.width * 0.35, 0);
    bottlePath.lineTo(size.width * 0.35, size.height * 0.15);
    
    // Shoulder
    bottlePath.quadraticBezierTo(
      size.width * 0.35, size.height * 0.2,
      size.width * 0.2, size.height * 0.25,
    );
    
    // Body
    bottlePath.lineTo(size.width * 0.15, size.height * 0.85);
    
    // Bottom curve
    bottlePath.quadraticBezierTo(
      size.width * 0.15, size.height * 0.95,
      size.width * 0.5, size.height,
    );
    bottlePath.quadraticBezierTo(
      size.width * 0.85, size.height * 0.95,
      size.width * 0.85, size.height * 0.85,
    );
    
    // Right side body
    bottlePath.lineTo(size.width * 0.8, size.height * 0.25);
    
    // Right shoulder
    bottlePath.quadraticBezierTo(
      size.width * 0.65, size.height * 0.2,
      size.width * 0.65, size.height * 0.15,
    );
    
    // Right neck
    bottlePath.lineTo(size.width * 0.65, 0);
    bottlePath.close();
    
    // Draw glass with transparency
    bottlePaint.color = Colors.white.withValues(alpha: 0.3);
    canvas.drawPath(bottlePath, bottlePaint);
    
    // Draw liquid inside (75% full)
    final liquidPath = Path();
    final liquidLevel = size.height * 0.3; // Start of liquid
    
    liquidPath.moveTo(size.width * 0.2, liquidLevel);
    liquidPath.lineTo(size.width * 0.15, size.height * 0.85);
    liquidPath.quadraticBezierTo(
      size.width * 0.15, size.height * 0.95,
      size.width * 0.5, size.height * 0.98,
    );
    liquidPath.quadraticBezierTo(
      size.width * 0.85, size.height * 0.95,
      size.width * 0.85, size.height * 0.85,
    );
    liquidPath.lineTo(size.width * 0.8, liquidLevel);
    liquidPath.close();
    
    // Gradient for liquid
    bottlePaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.7),
        color,
      ],
    ).createShader(Rect.fromLTWH(0, liquidLevel, size.width, size.height));
    
    canvas.drawPath(liquidPath, bottlePaint);
    
    // Glass shine effect
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    final shinePath = Path();
    shinePath.moveTo(size.width * 0.25, size.height * 0.3);
    shinePath.lineTo(size.width * 0.22, size.height * 0.7);
    
    canvas.drawPath(shinePath, shinePaint);
    
    // Cork/cap
    final capRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.32,
        0,
        size.width * 0.36,
        size.height * 0.08,
      ),
      Radius.circular(size.width * 0.04),
    );
    
    bottlePaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.brown.shade400,
        Colors.brown.shade600,
      ],
    ).createShader(capRect.outerRect);
    
    canvas.drawRRect(capRect, bottlePaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ShelfShinePainter extends CustomPainter {
  final double progress;
  
  ShelfShinePainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.1 * progress),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(
        size.width * progress - size.width * 0.3,
        0,
        size.width * 0.6,
        size.height,
      ));
    
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * progress - size.width * 0.3,
        0,
        size.width * 0.6,
        size.height,
      ),
      shinePaint,
    );
  }
  
  @override
  bool shouldRepaint(ShelfShinePainter oldDelegate) => 
      oldDelegate.progress != progress;
}

class SparkleEffectPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  SparkleEffectPainter({required this.progress, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final sparklePaint = Paint()
      ..color = color.withValues(alpha: 0.6 * (1 - progress))
      ..style = PaintingStyle.fill;
    
    // Draw sparkles at corners
    final sparklePositions = [
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.8),
    ];
    
    for (final pos in sparklePositions) {
      _drawSparkle(canvas, pos, 8 + (progress * 12), sparklePaint);
    }
  }
  
  void _drawSparkle(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    
    // 4-pointed star
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) - math.pi / 4;
      final outerX = center.dx + math.cos(angle) * size;
      final outerY = center.dy + math.sin(angle) * size;
      
      final innerAngle = angle + math.pi / 4;
      final innerX = center.dx + math.cos(innerAngle) * (size * 0.4);
      final innerY = center.dy + math.sin(innerAngle) * (size * 0.4);
      
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(SparkleEffectPainter oldDelegate) => 
      oldDelegate.progress != progress;
}

class StoredDye {
  final String id;
  final String name;
  final Color color;
  final int volume;
  bool isNew; // For sparkle animation
  
  StoredDye({
    required this.id,
    required this.name,
    required this.color,
    required this.volume,
    this.isNew = false,
  });
}

// Custom painter for the funnel shape
class FunnelPainter extends CustomPainter {
  final Color rimColor;
  final Color bodyColor;

  FunnelPainter({required this.rimColor, required this.bodyColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [rimColor, bodyColor, bodyColor.withValues(alpha: 0.7)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();

    // Funnel top rim (wide opening)
    path.moveTo(size.width * 0.1, size.height * 0.15);
    path.lineTo(size.width * 0.9, size.height * 0.15);

    // Right side slope down to narrow spout
    path.lineTo(size.width * 0.6, size.height * 0.85);
    path.lineTo(size.width * 0.55, size.height);

    // Bottom spout
    path.lineTo(size.width * 0.45, size.height);
    path.lineTo(size.width * 0.4, size.height * 0.85);

    // Left side slope back up
    path.lineTo(size.width * 0.1, size.height * 0.15);
    path.close();

    canvas.drawPath(path, paint);

    // Draw rim highlight
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final rimPath = Path();
    rimPath.moveTo(size.width * 0.1, size.height * 0.15);
    rimPath.lineTo(size.width * 0.9, size.height * 0.15);
    canvas.drawPath(rimPath, rimPaint);

    // Draw outline
    final outlinePaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for filter cloth mesh pattern
class ClothMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400.withValues(alpha: 0.4)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw horizontal lines
    for (double i = 0; i < size.height; i += 6) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw vertical lines
    for (double i = 0; i < size.width; i += 6) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
