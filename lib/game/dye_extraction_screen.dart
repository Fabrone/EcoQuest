// Dye Extraction Full Screen (Phase 2) - FIXED LAYOUT
import 'package:ecoquest/game/eco_quest_game.dart';
import 'package:ecoquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class DyeExtractionScreen extends StatefulWidget {
  final EcoQuestGame game;
  
  const DyeExtractionScreen({super.key, required this.game});

  @override
  State<DyeExtractionScreen> createState() => _DyeExtractionScreenState();
}

class _DyeExtractionScreenState extends State<DyeExtractionScreen> {
  int currentStep = 0;
  int dyeProduced = 0;
  double dyeValue = 0.0;
  
  final List<String> stepTitles = [
    'Collect Plant Materials',
    'Crush in Mortar',
    'Simmer in Beaker',
    'Filter the Mixture',
    'Dye Extracted!'
  ];
  
  final List<String> stepDescriptions = [
    'Tap to gather leaves, bark, roots, flowers, and fruits for dye extraction.',
    'Crush the collected materials using a mortar and pestle to break down cell walls.',
    'Heat the crushed materials in water to extract the natural pigments.',
    'Filter the mixture to separate the liquid dye from plant residue.',
    'Natural dye successfully extracted! Ready for use in customization and future levels.'
  ];
  
  final List<IconData> stepIcons = [
    Icons.spa,
    Icons.circle,
    Icons.science,
    Icons.filter_alt,
    Icons.colorize,
  ];

  @override
  void initState() {
    super.initState();
    // Calculate dye produced based on plants collected
    int plants = plantsCollectedNotifier.value;
    dyeProduced = (plants * 0.8).toInt(); // 80% conversion rate
    dyeValue = dyeProduced * 5.0; // Each unit worth 5 EcoCoins
  }

  void _nextStep() {
    if (currentStep < stepTitles.length - 1) {
      setState(() {
        currentStep++;
      });
    } else {
      // Show completion dialog
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Get screen constraints
            double screenWidth = MediaQuery.of(context).size.width;
            double screenHeight = MediaQuery.of(context).size.height;
            
            // Calculate responsive dimensions
            double dialogWidth = screenWidth * 0.85;
            dialogWidth = dialogWidth.clamp(280.0, 450.0);
            
            double iconSize = screenWidth * 0.12;
            iconSize = iconSize.clamp(40.0, 70.0);
            
            double titleFontSize = screenWidth * 0.055;
            titleFontSize = titleFontSize.clamp(18.0, 28.0);
            
            double bodyFontSize = screenWidth * 0.035;
            bodyFontSize = bodyFontSize.clamp(12.0, 16.0);
            
            double valueFontSize = screenWidth * 0.055;
            valueFontSize = valueFontSize.clamp(16.0, 22.0);
            
            double buttonIconSize = screenWidth * 0.05;
            buttonIconSize = buttonIconSize.clamp(18.0, 28.0);
            
            // Responsive spacing
            double spacing1 = screenHeight * 0.01;
            double spacing2 = screenHeight * 0.015;
            double spacing3 = screenHeight * 0.02;
            
            return SingleChildScrollView(
              child: Container(
                width: dialogWidth,
                margin: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.05,
                ),
                padding: EdgeInsets.all(screenWidth * 0.05),
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Phase 2 Complete!',
                        style: GoogleFonts.vt323(
                          color: Colors.white,
                          fontSize: titleFontSize,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing1),
                    
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: iconSize,
                    ),
                    SizedBox(height: spacing1),
                    
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Dye Produced: $dyeProduced ml',
                        style: GoogleFonts.vt323(
                          color: Colors.amber,
                          fontSize: valueFontSize,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing1 * 0.5),
                    
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Value: ${dyeValue.toStringAsFixed(1)} EcoCoins',
                        style: GoogleFonts.vt323(
                          color: Colors.green,
                          fontSize: valueFontSize,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing2),
                    
                    Text(
                      'This dye can be used for avatar customization and will be carried forward to future levels!',
                      style: GoogleFonts.vt323(
                        color: Colors.white70,
                        fontSize: bodyFontSize,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing3),
                    
                    // Icon-based action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCompactIconButton(
                          icon: Icons.replay,
                          label: 'Replay',
                          color: Colors.orange,
                          iconSize: buttonIconSize,
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog
                            Navigator.of(context).pop(); // Go back to game screen
                            widget.game.restartGame();
                          },
                        ),
                        _buildCompactIconButton(
                          icon: Icons.play_arrow,
                          label: 'Next Level',
                          color: Colors.green,
                          iconSize: buttonIconSize,
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog
                            Navigator.of(context).pop(); // Go back to game screen
                            widget.game.startNextLevel();
                          },
                        ),
                        _buildCompactIconButton(
                          icon: Icons.exit_to_app,
                          label: 'Exit',
                          color: Colors.red,
                          iconSize: buttonIconSize,
                          onPressed: () async {
                            await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper method for compact icon buttons
  Widget _buildCompactIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required double iconSize,
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
              padding: EdgeInsets.all(iconSize * 0.4),
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
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: iconSize * 0.15),
        Text(
          label,
          style: GoogleFonts.vt323(
            fontSize: iconSize * 0.5,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A1B), // Deep forest green background
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive sizing
            double screenWidth = constraints.maxWidth;
            double screenHeight = constraints.maxHeight;
            
            double headerFontSize = (screenWidth * 0.06).clamp(20.0, 32.0);
            double phaseFontSize = (screenWidth * 0.035).clamp(14.0, 18.0);
            double stepIconSize = (screenWidth * 0.075).clamp(28.0, 42.0);
            double contentIconSize = (screenWidth * 0.15).clamp(60.0, 100.0);
            double titleFontSize = (screenWidth * 0.045).clamp(18.0, 26.0);
            double descFontSize = (screenWidth * 0.034).clamp(13.0, 16.0);
            double buttonHeight = (screenHeight * 0.075).clamp(50.0, 70.0);
            double buttonFontSize = (screenWidth * 0.042).clamp(16.0, 22.0);
            
            return Column(
              children: [
                // Header Section - REDUCED PADDING
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.04,
                    vertical: screenHeight * 0.015,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade900.withValues(alpha: 0.8),
                        Colors.green.shade800.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        child: Text(
                          'DYE EXTRACTION PROCESS',
                          style: GoogleFonts.vt323(
                            fontSize: headerFontSize,
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        'Phase 2 of 2',
                        style: GoogleFonts.vt323(
                          fontSize: phaseFontSize,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: screenHeight * 0.012),
                
                // Progress Indicator - MADE MORE COMPACT
                Container(
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.012),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(stepTitles.length, (index) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: stepIconSize,
                              height: stepIconSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index <= currentStep 
                                    ? Colors.green 
                                    : Colors.grey.shade700,
                                border: Border.all(
                                  color: index == currentStep 
                                      ? Colors.amber 
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  if (index <= currentStep)
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                              child: Icon(
                                index < currentStep ? Icons.check : stepIcons[index],
                                color: Colors.white,
                                size: stepIconSize * 0.5,
                              ),
                            ),
                            if (index < stepTitles.length - 1)
                              Container(
                                width: screenWidth * 0.06,
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: index < currentStep 
                                      ? Colors.green 
                                      : Colors.grey.shade700,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                margin: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.015,
                                ),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                
                SizedBox(height: screenHeight * 0.008),
                
                // Main Content - SCROLLABLE WITH PROPER CONSTRAINTS
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(screenWidth * 0.045),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade900, Colors.green.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ICON - REDUCED SIZE
                          Icon(
                            stepIcons[currentStep],
                            size: contentIconSize,
                            color: Colors.amber,
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          
                          // TITLE - ALWAYS VISIBLE
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                              child: Text(
                                stepTitles[currentStep],
                                style: GoogleFonts.vt323(
                                  fontSize: titleFontSize,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          
                          SizedBox(height: screenHeight * 0.018),
                          
                          // DESCRIPTION - CONSTRAINED
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.025),
                            child: Text(
                              stepDescriptions[currentStep],
                              style: GoogleFonts.vt323(
                                fontSize: descFontSize,
                                color: Colors.white70,
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          SizedBox(height: screenHeight * 0.025),
                          
                          // STEP-SPECIFIC CONTENT - PROPERLY SIZED
                          if (currentStep == 0)
                            ValueListenableBuilder<int>(
                              valueListenable: plantsCollectedNotifier,
                              builder: (ctx, plants, _) => Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.06,
                                  vertical: screenHeight * 0.015,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Materials Available: $plants units',
                                    style: GoogleFonts.vt323(
                                      fontSize: titleFontSize * 0.95,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          
                          if (currentStep == 4)
                            Container(
                              padding: EdgeInsets.all(screenWidth * 0.04),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Dye Produced: $dyeProduced ml',
                                      style: GoogleFonts.vt323(
                                        fontSize: titleFontSize * 0.95,
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.01),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Estimated Value: ${dyeValue.toStringAsFixed(1)} EcoCoins',
                                      style: GoogleFonts.vt323(
                                        fontSize: descFontSize * 1.15,
                                        color: Colors.green.shade300,
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
                
                SizedBox(height: screenHeight * 0.01),
                
                // Action Button - FIXED AT BOTTOM WITH REDUCED PADDING
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.04,
                    screenHeight * 0.01,
                    screenWidth * 0.04,
                    screenHeight * 0.018,
                  ),
                  child: SizedBox(
                    height: buttonHeight,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _nextStep,
                      icon: Icon(
                        currentStep < stepTitles.length - 1 
                            ? Icons.arrow_forward 
                            : Icons.check_circle,
                        size: buttonHeight * 0.35,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currentStep < stepTitles.length - 1 
                              ? 'NEXT STEP' 
                              : 'COMPLETE',
                          style: GoogleFonts.vt323(
                            fontSize: buttonFontSize,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentStep < stepTitles.length - 1 
                            ? Colors.amber 
                            : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 10,
                        shadowColor: (currentStep < stepTitles.length - 1 
                            ? Colors.amber 
                            : Colors.green).withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}