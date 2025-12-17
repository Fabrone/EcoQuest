import 'dart:async';
import 'dart:math' as math;
import 'package:ecoquest/game/eco_quest_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class DyeExtractionScreen extends StatefulWidget {
  final EcoQuestGame game;
  final int levelTimeRemaining; // Pass this from game
  
  const DyeExtractionScreen({
    super.key, 
    required this.game,
    this.levelTimeRemaining = 100,
  });

  @override
  State<DyeExtractionScreen> createState() => _DyeExtractionScreenState();
}

class _DyeExtractionScreenState extends State<DyeExtractionScreen> with TickerProviderStateMixin {
  // Material Quality System
  String materialQuality = 'Good';
  double qualityMultiplier = 1.0;
  Map<String, int> materials = {};
  Map<String, String> materialQualities = {};
  
  // Workshop State
  int currentPhase = 0; // 0=Transition, 1=Workshop, 2=Crushing, 3=Temperature, 4=Filtering, 5=Complete
  String? selectedRecipe;
  List<String> selectedMaterials = [];
  
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
  
  // Temperature mini-game
  double temperature = 70.0;
  double temperatureTarget = 70.0;
  Timer? temperatureTimer;
  int temperatureTimeCorrect = 0;
  
  // Crushing mini-game
  int tapCount = 0;
  Timer? crushingTimer;
  int crushingTimeLeft = 10;
  
  // Filtering mini-game
  double filterPosition = 0.0;
  int swipeCount = 0;
  Timer? filteringTimer;
  int filteringTimeLeft = 15;

  @override
  void initState() {
    super.initState();
    _initializeMaterials();
    _initializeAnimations();
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

  @override
  void dispose() {
    _transitionController.dispose();
    _crushingController.dispose();
    _bubbleController.dispose();
    temperatureTimer?.cancel();
    crushingTimer?.cancel();
    filteringTimer?.cancel();
    super.dispose();
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
      crushingTimeLeft = 10;
    });
    
    crushingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        crushingTimeLeft--;
        if (crushingTimeLeft <= 0) {
          timer.cancel();
          _calculateCrushingScore();
        }
      });
    });
  }

  void _onCrushTap() {
    setState(() {
      tapCount++;
      _crushingController.forward(from: 0);
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
      temperatureTimeCorrect = 0;
    });
    
    _startTemperatureGame();
  }

  void _startTemperatureGame() {
    temperatureTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        // Random temperature drift
        temperature += (math.Random().nextDouble() - 0.5) * 2;
        temperature = temperature.clamp(40.0, 100.0);
        
        // Check if in optimal zone (60-80°C)
        if (temperature >= 60 && temperature <= 80) {
          temperatureTimeCorrect++;
        }
      });
      
      if (temperatureTimeCorrect >= 150) { // 15 seconds
        timer.cancel();
        _calculateTemperatureScore();
      }
    });
  }

  void _adjustTemperature(double delta) {
    setState(() {
      temperature = (temperature + delta).clamp(40.0, 100.0);
    });
  }

  void _calculateTemperatureScore() {
    // If maintained for full time
    temperatureMaintained = 1.0;
    
    setState(() {
      currentPhase = 4;
      swipeCount = 0;
      filteringTimeLeft = 15;
      filterPosition = 0.0;
    });
    
    _startFilteringGame();
  }

  void _startFilteringGame() {
    filteringTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        filteringTimeLeft--;
        if (filteringTimeLeft <= 0) {
          timer.cancel();
          _calculateFilteringScore();
        }
      });
    });
  }

  void _onFilterSwipe(DragUpdateDetails details) {
    setState(() {
      filterPosition += details.delta.dx;
      if (filterPosition.abs() > 50) {
        swipeCount++;
        filterPosition = 0;
      }
    });
  }

  void _calculateFilteringScore() {
    filteringPurity = (swipeCount / 20.0).clamp(0.7, 1.0);
    _calculateFinalResults();
  }

  void _calculateFinalResults() {
    // Base yield from recipe
    int baseYield = 8; // ml per recipe
    
    // Apply all multipliers
    double finalYield = baseYield * 
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A1B),
      body: SafeArea(
        child: _buildCurrentPhase(),
      ),
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
                      ...materials.entries.map((entry) => Padding(
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
                      )),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                    ...materials.entries.map((entry) => Padding(
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
                    )),
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
                    _buildRecipeButton('Green Dye', '10 Leaves', Colors.green, _canCraftRecipe('Green Dye')),
                    _buildRecipeButton('Brown Dye', '10 Bark', Colors.brown, _canCraftRecipe('Brown Dye')),
                    _buildRecipeButton('Yellow Dye', '10 Roots', Colors.yellow, _canCraftRecipe('Yellow Dye')),
                    _buildRecipeButton('Red Dye', '10 Flowers', Colors.red, _canCraftRecipe('Red Dye')),
                    _buildRecipeButton('Purple Dye', '10 Fruits', Colors.purple, _canCraftRecipe('Purple Dye')),
                    
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
                    _buildRecipeButton('Blue Dye', '5 Leaves + 5 Fruits', Colors.blue, _canCraftRecipe('Blue Dye')),
                    _buildRecipeButton('Orange Dye', '5 Roots + 5 Flowers', Colors.orange, _canCraftRecipe('Orange Dye')),
                    _buildRecipeButton('Teal Dye', '5 Leaves + 5 Bark', Colors.teal, _canCraftRecipe('Teal Dye')),
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

  Widget _buildRecipeButton(String name, String requirements, Color color, bool canCraft) {
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
              minHeight: MediaQuery.of(context).size.height - 
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
                                          duration: const Duration(milliseconds: 300),
                                          opacity: dustOpacity,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  dyeColor.withValues(alpha: 0.3),
                                                  dyeColor.withValues(alpha: 0.1),
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
                                      double angle = (index / particleCount) * 2 * math.pi + (random.nextDouble() * 0.5);
                                      double radius = 20 + (random.nextDouble() * 65);
                                      double xPos = math.cos(angle) * radius;
                                      double yPos = math.sin(angle) * radius;
                                      
                                      // Particle rotation for more natural look
                                      double rotation = random.nextDouble() * math.pi;
                                      
                                      return AnimatedPositioned(
                                        duration: const Duration(milliseconds: 400),
                                        curve: Curves.easeOutCubic,
                                        left: 120 + xPos - (particleSize / 2),
                                        top: 120 + yPos - (particleSize / 2),
                                        child: Transform.rotate(
                                          angle: rotation,
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 400),
                                            width: particleSize,
                                            height: particleSize,
                                            decoration: BoxDecoration(
                                              color: dyeColor.withValues(
                                                alpha: 0.7 + (crushingProgress / 333)
                                              ),
                                              borderRadius: BorderRadius.circular(
                                                // Becomes more rounded/powder-like as crushing progresses
                                                particleSize * (0.2 + (crushingProgress / 200))
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: dyeColor.withValues(alpha: 0.3),
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
                                        double angle = (index / 12) * 2 * math.pi + (random.nextDouble() * 0.8);
                                        double radius = 30 + (random.nextDouble() * 50);
                                        double xPos = math.cos(angle) * radius;
                                        double yPos = math.sin(angle) * radius;
                                        
                                        return Positioned(
                                          left: 120 + xPos - 3,
                                          top: 120 + yPos - 3,
                                          child: AnimatedOpacity(
                                            duration: const Duration(milliseconds: 500),
                                            opacity: dustOpacity * 0.8,
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: dyeColor.withValues(alpha: 0.5),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: dyeColor.withValues(alpha: 0.3),
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
                                          duration: const Duration(milliseconds: 500),
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
                                            borderRadius: const BorderRadius.only(
                                              bottomLeft: Radius.circular(100),
                                              bottomRight: Radius.circular(100),
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
                              double pestleOffset = -30 * math.sin(_crushingController.value * math.pi);
                              double pestleRotation = 0.15 * math.sin(_crushingController.value * math.pi * 2);
                              double pestleScale = 1.0 - (0.05 * _crushingController.value);
                              
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
                                              borderRadius: BorderRadius.circular(11),
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
                                                  color: Colors.black.withValues(alpha: 0.4),
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
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            width: 24,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Colors.brown.shade700,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Pestle head (stone)
                                          Container(
                                            width: 40,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(20),
                                                topRight: Radius.circular(20),
                                                bottomLeft: Radius.circular(20),
                                                bottomRight: Radius.circular(20),
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
                                                stops: const [0.0, 0.3, 0.7, 1.0],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.5),
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
                          if (_crushingController.isAnimating && crushingProgress < 95)
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
                                            alpha: 0.6 * (1.0 - _crushingController.value)
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.touch_app, color: Colors.black, size: 20),
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
                                width: (MediaQuery.of(context).size.width - 88) * (crushingProgress / 100),
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
                                      color: qualityColor.withValues(alpha: 0.6),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              // Milestone markers
                              Positioned.fill(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [50, 70, 90].map((milestone) {
                                    bool reached = crushingProgress >= milestone;
                                    return Container(
                                      width: 3,
                                      decoration: BoxDecoration(
                                        color: reached 
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.3),
                                        boxShadow: reached ? [
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ] : null,
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
                              icon: Icons.timer,
                              label: 'Time',
                              value: '${crushingTimeLeft}s',
                              color: crushingTimeLeft <= 3 
                                  ? Colors.red 
                                  : Colors.amber,
                            ),
                            _buildCrushingStat(
                              icon: Icons.speed,
                              label: 'Rate',
                              value: crushingTimeLeft < 10 
                                  ? '${(tapCount / (10 - crushingTimeLeft)).toStringAsFixed(1)}/s'
                                  : '0.0/s',
                              color: Colors.green,
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
                        _buildQualityTier('90-100%', 'Perfect (+30% yield)', Colors.greenAccent, crushingProgress >= 90),
                        _buildQualityTier('70-89%', 'Good (+15% yield)', Colors.amber, crushingProgress >= 70 && crushingProgress < 90),
                        _buildQualityTier('50-69%', 'Fair (standard)', Colors.orange, crushingProgress >= 50 && crushingProgress < 70),
                        _buildQualityTier('0-49%', 'Poor (-15% yield)', Colors.red, crushingProgress < 50),
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
          style: GoogleFonts.vt323(
            fontSize: 14,
            color: Colors.white70,
          ),
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

  Widget _buildQualityTier(String range, String label, Color color, bool active) {
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
    
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MAINTAIN OPTIMAL HEAT!',
                  style: GoogleFonts.vt323(
                    fontSize: 32,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Beaker with bubbles
                AnimatedBuilder(
                  animation: _bubbleController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 150,
                          height: 200,
                          decoration: BoxDecoration(
                            color: dyeColor.withValues(alpha: 0.6),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(75),
                              bottomRight: Radius.circular(75),
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              '${temperature.toInt()}°C',
                              style: GoogleFonts.vt323(
                                fontSize: 32,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Animated bubbles
                        if (temperature > 70)
                          ...List.generate(3, (index) {
                            double offset = _bubbleController.value * 150;
                            return Positioned(
                              bottom: offset + (index * 50),
                              left: 50 + (index * 25.0),
                              child: Container(
                                width: 10 + (index * 5.0),
                                height: 10 + (index * 5.0),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Temperature Status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: inOptimalZone 
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: inOptimalZone ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    inOptimalZone ? 'OPTIMAL ZONE!' : 'ADJUST HEAT!',
                    style: GoogleFonts.vt323(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Temperature Slider
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'TOO COLD',
                        style: GoogleFonts.vt323(
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Slider(
                        value: temperature,
                        min: 40,
                        max: 100,
                        divisions: 60,
                        activeColor: inOptimalZone ? Colors.green : Colors.red,
                        inactiveColor: Colors.grey,
                        onChanged: (value) {
                          setState(() {
                            temperature = value;
                          });
                        },
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'TOO HOT',
                        style: GoogleFonts.vt323(
                          fontSize: 14,
                          color: Colors.red,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Temperature Controls
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _adjustTemperature(-5),
                      icon: const Icon(Icons.remove),
                      label: Text(
                        'COOL DOWN',
                        style: GoogleFonts.vt323(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _adjustTemperature(5),
                      icon: const Icon(Icons.add),
                      label: Text(
                        'HEAT UP',
                        style: GoogleFonts.vt323(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  'Time: ${(temperatureTimeCorrect / 10).toStringAsFixed(1)}s / 15s',
                  style: GoogleFonts.vt323(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilteringGame() {
    double purity = (swipeCount / 20.0 * 100).clamp(0.0, 100.0);
    
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FILTER THE MIXTURE!',
                  style: GoogleFonts.vt323(
                    fontSize: 32,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Filter Animation
                GestureDetector(
                  onPanUpdate: _onFilterSwipe,
                  child: Container(
                    width: double.infinity,
                    height: 300,
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Colors.brown.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Plant debris
                        Positioned(
                          top: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                Icons.circle,
                                size: 20,
                                color: Colors.brown.withValues(alpha: 0.7),
                              ),
                            )),
                          ),
                        ),
                        
                        // Filter screen
                        Transform.translate(
                          offset: Offset(filterPosition, 0),
                          child: Container(
                            width: 250,
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey.shade400,
                                  Colors.grey.shade600,
                                  Colors.grey.shade400,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Pure dye drops
                        Positioned(
                          bottom: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              (swipeCount / 4).floor().clamp(0, 5),
                              (index) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.water_drop,
                                  size: 30,
                                  color: dyeColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Purity Meter
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Purity: ${purity.toInt()}%',
                        style: GoogleFonts.vt323(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: purity / 100,
                        backgroundColor: Colors.grey.shade800,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          purity >= 85 ? Colors.green : Colors.orange,
                        ),
                        minHeight: 20,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  'Swipes: $swipeCount',
                  style: GoogleFonts.vt323(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                
                Text(
                  'Time: ${filteringTimeLeft}s',
                  style: GoogleFonts.vt323(
                    fontSize: 20,
                    color: Colors.amber,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  'Swipe the filter left & right rapidly!',
                  style: GoogleFonts.vt323(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            Text(
              'DYE EXTRACTION COMPLETE!',
              style: GoogleFonts.vt323(
                fontSize: 32,
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Dye Bottle
            Container(
              width: 150,
              height: 200,
              decoration: BoxDecoration(
                color: dyeColor.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(75),
                  bottomRight: Radius.circular(75),
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: dyeColor.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$dyeProduced ml',
                  style: GoogleFonts.vt323(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Results Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade900.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                children: [
                  _buildResultRow('Dye Type:', selectedRecipe ?? 'N/A', Colors.amber),
                  _buildResultRow('Material Quality:', materialQuality, 
                    materialQuality == 'Fresh' 
                        ? Colors.greenAccent 
                        : materialQuality == 'Good'
                            ? Colors.amber
                            : Colors.orange),
                  _buildResultRow('Quality Bonus:', '+${((qualityMultiplier - 1) * 100).toInt()}%', Colors.green),
                  const Divider(color: Colors.white30),
                  _buildResultRow('Crushing:', '${(crushingEfficiency * 100).toInt()}%', 
                    crushingEfficiency >= 1.1 ? Colors.greenAccent : Colors.white),
                  _buildResultRow('Temperature:', 'Perfect!', Colors.greenAccent),
                  _buildResultRow('Filtering:', '${(filteringPurity * 100).toInt()}%', 
                    filteringPurity >= 0.9 ? Colors.greenAccent : Colors.white),
                  const Divider(color: Colors.white30),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        '$ecoCoinsEarned EcoCoins',
                        style: GoogleFonts.vt323(
                          fontSize: 32,
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Unlocked Items
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade900.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    '🎨 UNLOCKED CUSTOMIZATION',
                    style: GoogleFonts.vt323(
                      fontSize: 22,
                      color: Colors.purple.shade200,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '✓ ${dyeType.split(' ')[0]} Face Paint\n'
                    '✓ ${dyeType.split(' ')[0]} Body Paint',
                    style: GoogleFonts.vt323(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.replay,
                  label: 'CRAFT\nANOTHER',
                  color: Colors.orange,
                  onPressed: () {
                    setState(() {
                      currentPhase = 1;
                      selectedRecipe = null;
                    });
                  },
                ),
                _buildActionButton(
                  icon: Icons.check_circle,
                  label: 'FINISH',
                  color: Colors.green,
                  onPressed: () => _showFinalCompletionDialog(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.vt323(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.vt323(
              fontSize: 18,
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.vt323(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
              
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 60,
              ),
              const SizedBox(height: 20),
              
              Text(
                'Total Dye Produced: $dyeProduced ml',
                style: GoogleFonts.vt323(
                  color: Colors.amber,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 10),
              
              Text(
                'Total EcoCoins: $ecoCoinsEarned',
                style: GoogleFonts.vt323(
                  color: Colors.green,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'This dye will be carried forward to future levels!',
                style: GoogleFonts.vt323(
                  color: Colors.white70,
                  fontSize: 16,
                ),
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
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      widget.game.restartGame();
                    },
                  ),
                  _buildDialogButton(
                    icon: Icons.play_arrow,
                    label: 'Next Level',
                    color: Colors.green,
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      widget.game.startNextLevel();
                    },
                  ),
                  _buildDialogButton(
                    icon: Icons.exit_to_app,
                    label: 'Exit',
                    color: Colors.red,
                    onPressed: () async {
                      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
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
              child: Icon(
                icon,
                size: 24,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.vt323(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}