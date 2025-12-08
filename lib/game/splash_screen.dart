import 'package:ecoquest/main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  bool _showMainMenu = false;
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _startLoading();
  }

  void _startLoading() {
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _progress += 0.02;
        if (_progress >= 1.0) {
          _progress = 1.0;
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() => _showMainMenu = true);
            }
          });
        }
      });
    });
  }

  String _getLoadingText() {
    if (_progress < 0.3) return '🌱 Planting seeds...';
    if (_progress < 0.6) return '💧 Watering the forest...';
    if (_progress < 0.9) return '🌳 Growing trees...';
    return '✨ Almost ready...';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF064E3B), // emerald-900
              Color(0xFF166534), // green-800
              Color(0xFF78350F), // amber-900
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Background pattern
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: CustomPaint(
                      painter: DotPatternPainter(),
                    ),
                  ),
                ),
                
                // Floating leaves - responsive count based on screen size
                ...List.generate(
                  (constraints.maxWidth / 100).floor().clamp(5, 15),
                  (index) => FloatingLeaf(
                    delay: index * 0.3,
                    left: (index * (constraints.maxWidth / 15)) % constraints.maxWidth,
                  ),
                ),
                
                // Main content - Scrollable
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth * 0.05,
                          vertical: constraints.maxHeight * 0.02,
                        ),
                        child: _showMainMenu 
                            ? _buildMainMenu(constraints) 
                            : _buildLoadingScreen(constraints),
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

  Widget _buildLoadingScreen(BoxConstraints constraints) {
    // Responsive sizing
    double logoSize = (constraints.maxWidth * 0.15).clamp(60.0, 120.0);
    double titleFontSize = (constraints.maxWidth * 0.08).clamp(32.0, 56.0);
    double subtitleFontSize = (constraints.maxWidth * 0.04).clamp(18.0, 28.0);
    double taglineFontSize = (constraints.maxWidth * 0.02).clamp(12.0, 14.0);
    double progressBarWidth = (constraints.maxWidth * 0.7).clamp(250.0, 320.0);
    double spacing = constraints.maxHeight * 0.03;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated logo
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.1),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3 * _pulseController.value),
                      blurRadius: logoSize * 0.5,
                      spreadRadius: logoSize * 0.15,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.park,
                  size: logoSize,
                  color: const Color(0xFF86EFAC),
                ),
              ),
            );
          },
        ),
        
        SizedBox(height: spacing),
        
        // Title
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF86EFAC), Color(0xFFA7F3D0), Color(0xFF86EFAC)],
          ).createShader(bounds),
          child: Text(
            'EcoQuest',
            style: GoogleFonts.merriweather(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        SizedBox(height: spacing * 0.25),
        
        Text(
          'The Heritage Hunt',
          style: GoogleFonts.vt323(
            fontSize: subtitleFontSize,
            color: const Color(0xFFFCD34D),
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: spacing * 0.2),
        
        Text(
          'Restoring Nature, One Match at a Time',
          style: GoogleFonts.vt323(
            fontSize: taglineFontSize,
            color: const Color(0xFFBBF7D0),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: spacing * 1.5),
        
        // Progress bar
        SizedBox(
          width: progressBarWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: (constraints.maxHeight * 0.015).clamp(8.0, 12.0),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF16A34A), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E)),
                  ),
                ),
              ),
              SizedBox(height: spacing * 0.3),
              Text(
                _getLoadingText(),
                style: GoogleFonts.vt323(
                  fontSize: (constraints.maxWidth * 0.025).clamp(14.0, 16.0),
                  color: const Color(0xFF86EFAC),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        SizedBox(height: spacing),
        
        // Credits
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Developed by Yonder Spaces Ltd',
              style: GoogleFonts.vt323(
                fontSize: (constraints.maxWidth * 0.018).clamp(10.0, 12.0),
                color: const Color(0xFFBBF7D0).withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainMenu(BoxConstraints constraints) {
    // Responsive sizing
    double logoSize = (constraints.maxWidth * 0.12).clamp(60.0, 100.0);
    double titleFontSize = (constraints.maxWidth * 0.1).clamp(40.0, 64.0);
    double subtitleFontSize = (constraints.maxWidth * 0.045).clamp(20.0, 32.0);
    double cardWidth = (constraints.maxWidth * 0.85).clamp(300.0, 400.0);
    double buttonPadding = (constraints.maxWidth * 0.03).clamp(12.0, 20.0);
    double spacing = constraints.maxHeight * 0.025;
    
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.05),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: logoSize * 0.5,
                        spreadRadius: logoSize * 0.15,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.park,
                    size: logoSize,
                    color: const Color(0xFF86EFAC),
                  ),
                ),
              );
            },
          ),
          
          SizedBox(height: spacing),
          
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF86EFAC), Color(0xFFA7F3D0), Color(0xFF86EFAC)],
            ).createShader(bounds),
            child: Text(
              'EcoQuest',
              style: GoogleFonts.merriweather(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          SizedBox(height: spacing * 0.3),
          
          Text(
            'The Heritage Hunt',
            style: GoogleFonts.vt323(
              fontSize: subtitleFontSize,
              color: const Color(0xFFFCD34D),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: spacing * 1.5),
          
          // Level preview card
          Container(
            width: cardWidth,
            padding: EdgeInsets.all(constraints.maxWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF22C55E), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.eco,
                      color: const Color(0xFF86EFAC),
                      size: (constraints.maxWidth * 0.05).clamp(24.0, 32.0),
                    ),
                    SizedBox(width: constraints.maxWidth * 0.02),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Level 1: Kiambu County',
                              style: GoogleFonts.vt323(
                                fontSize: (constraints.maxWidth * 0.032).clamp(16.0, 22.0),
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Deforestation Challenge',
                              style: GoogleFonts.vt323(
                                fontSize: (constraints.maxWidth * 0.024).clamp(14.0, 16.0),
                                color: const Color(0xFF86EFAC),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing * 0.6),
                ...[
                  '• Restore Kinale Forest',
                  '• Extract Natural Dyes',
                  '• Learn Traditional Practices',
                ].map((text) => Padding(
                  padding: EdgeInsets.only(bottom: spacing * 0.25),
                  child: Row(
                    children: [
                      Container(
                        width: (constraints.maxWidth * 0.012).clamp(6.0, 8.0),
                        height: (constraints.maxWidth * 0.012).clamp(6.0, 8.0),
                        decoration: const BoxDecoration(
                          color: Color(0xFF86EFAC),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: constraints.maxWidth * 0.02),
                      Expanded(
                        child: Text(
                          text.substring(2),
                          style: GoogleFonts.vt323(
                            fontSize: (constraints.maxWidth * 0.024).clamp(13.0, 16.0),
                            color: const Color(0xFFBBF7D0),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          
          SizedBox(height: spacing * 1.2),
          
          // Start button
          SizedBox(
            width: cardWidth,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const GameScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                padding: EdgeInsets.symmetric(
                  horizontal: buttonPadding,
                  vertical: buttonPadding * 0.8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                elevation: 10,
                shadowColor: const Color(0xFF22C55E).withValues(alpha: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow,
                    size: (constraints.maxWidth * 0.04).clamp(20.0, 28.0),
                  ),
                  SizedBox(width: constraints.maxWidth * 0.02),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'START GAME',
                        style: GoogleFonts.vt323(
                          fontSize: (constraints.maxWidth * 0.035).clamp(18.0, 24.0),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: constraints.maxWidth * 0.02),
                  Icon(
                    Icons.auto_awesome,
                    size: (constraints.maxWidth * 0.035).clamp(18.0, 24.0),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: spacing * 0.8),
          
          // UPDATED: Modern Grid Layout for Secondary Buttons
          _buildModernButtonGrid(constraints, cardWidth),
        ],
      ),
    );
  }

  Widget _buildModernButtonGrid(BoxConstraints constraints, double cardWidth) {
    double buttonHeight = (constraints.maxHeight * 0.065).clamp(50.0, 70.0);
    double iconSize = (constraints.maxWidth * 0.055).clamp(24.0, 32.0);
    double fontSize = (constraints.maxWidth * 0.028).clamp(14.0, 18.0);
    
    return Container(
      width: cardWidth,
      padding: EdgeInsets.all(constraints.maxWidth * 0.025),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Row 1: How to Play
          _buildModernButton(
            context: context,
            icon: Icons.menu_book,
            label: 'How to Play',
            gradient: const LinearGradient(
              colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
            ),
            onTap: () => _navigateToHowToPlay(context),
            height: buttonHeight,
            iconSize: iconSize,
            fontSize: fontSize,
          ),
          
          SizedBox(height: constraints.maxWidth * 0.025),
          
          // Row 2: Scores & Settings
          Row(
            children: [
              Expanded(
                child: _buildModernButton(
                  context: context,
                  icon: Icons.emoji_events,
                  label: 'Scores',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  ),
                  onTap: () => _navigateToScores(context),
                  height: buttonHeight,
                  iconSize: iconSize,
                  fontSize: fontSize,
                ),
              ),
              SizedBox(width: constraints.maxWidth * 0.025),
              Expanded(
                child: _buildModernButton(
                  context: context,
                  icon: Icons.settings,
                  label: 'Settings',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                  ),
                  onTap: () => _navigateToSettings(context),
                  height: buttonHeight,
                  iconSize: iconSize,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    required VoidCallback onTap,
    required double height,
    required double iconSize,
    required double fontSize,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: height,
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
            Icon(icon, color: Colors.white, size: iconSize),
            SizedBox(width: iconSize * 0.3),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: GoogleFonts.vt323(
                    fontSize: fontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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

  void _navigateToHowToPlay(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HowToPlayScreen(),
      ),
    );
  }

  void _navigateToScores(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ScoresScreen(),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }
}

// Floating Leaf Component (unchanged)
class FloatingLeaf extends StatefulWidget {
  final double delay;
  final double left;

  const FloatingLeaf({super.key, required this.delay, required this.left});

  @override
  State<FloatingLeaf> createState() => _FloatingLeafState();
}

class _FloatingLeafState extends State<FloatingLeaf> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 8 + (widget.delay * 2).toInt()),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.left,
          bottom: -30 + (_controller.value * (screenHeight + 60)),
          child: Transform.rotate(
            angle: _controller.value * 6.28,
            child: Opacity(
              opacity: _controller.value < 0.1 || _controller.value > 0.9 ? 0 : 0.6,
              child: Icon(
                Icons.eco,
                color: const Color(0xFF86EFAC),
                size: (MediaQuery.of(context).size.width * 0.035).clamp(18.0, 24.0),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Dot Pattern Painter (unchanged)
class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    double spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// HOW TO PLAY SCREEN - WITH ANIMATED TYPING TEXT
// ============================================================================

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final ScrollController _scrollController = ScrollController();
  
  final List<String> _sections = [
    '🎯 GAME OBJECTIVE',
    'Restore the degraded Kinale Forest by matching 3 or more identical eco-items. Your goal is to turn all brown (degraded) tiles green (restored) before time runs out! ⏰',
    '',
    '🎮 HOW TO PLAY',
    '1️⃣ Swipe any eco-item (rain 💧, hummingbird 🐦, summer ☀️, rose 🌹, or man 👨) in any direction (up, down, left, right).',
    '2️⃣ Match 3 or more items of the same type horizontally or vertically.',
    '3️⃣ When items match, they disappear and the tile underneath turns green! 🌿',
    '4️⃣ New items fall from the top to fill empty spaces.',
    '5️⃣ Keep matching until ALL tiles are green! 🎉',
    '',
    '⚡ SCORING SYSTEM',
    '• Each matched item = 10 EcoPoints 💎',
    '• Higher scores unlock better rewards! 🏆',
    '• Complete levels faster for TIME BONUSES ⏱️',
    '',
    '🌱 PHASE 2: DYE EXTRACTION',
    'After restoring the forest, you collect plant materials to extract natural dyes. The more tiles you restore and the faster you complete, the more materials you gather! 🎨',
    '',
    '💡 TIPS & TRICKS',
    '• Use the HINT button (💡) when stuck - you have 5 hints per level!',
    '• Plan ahead: look for potential matches before swiping!',
    '• If no moves are available, the board auto-shuffles! 🔄',
    '• Collect materials quickly to maximize dye production! 🧪',
    '',
    '🎊 Ready to restore the forest? Let\'s go! 🌳✨',
  ];

  String _displayedText = '';
  int _currentSectionIndex = 0;
  int _currentCharIndex = 0;
  Timer? _typingTimer;
  bool _isTypingComplete = false;

  @override
  void initState() {
    super.initState();
    _startTypingAnimation();
  }

  void _startTypingAnimation() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentSectionIndex < _sections.length) {
        String currentSection = _sections[_currentSectionIndex];
        
        if (_currentCharIndex < currentSection.length) {
          setState(() {
            _displayedText += currentSection[_currentCharIndex];
            _currentCharIndex++;
          });
          
          // Smooth auto-scroll as content grows
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          });
        } else {
          // Move to next section with consistent spacing
          setState(() {
            _displayedText += '\n\n';
            _currentSectionIndex++;
            _currentCharIndex = 0;
          });
        }
      } else {
        // Typing complete
        setState(() {
          _isTypingComplete = true;
        });
        timer.cancel();
      }
    });
  }

  void _skipAnimation() {
    _typingTimer?.cancel();
    setState(() {
      _displayedText = _sections.join('\n\n');
      _isTypingComplete = true;
    });
    
    // Scroll to top after skipping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF064E3B),
              Color(0xFF166534),
              Color(0xFF78350F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        '📖 How to Play',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Skip button (shown during animation)
              if (!_isTypingComplete)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextButton.icon(
                    onPressed: _skipAnimation,
                    icon: const Icon(Icons.fast_forward, color: Colors.amber, size: 20),
                    label: Text(
                      'Skip Animation',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.amber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ),
              
              // Content with smooth scrolling
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF22C55E),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.notoSans(
                              fontSize: 17,
                              color: Colors.white,
                              height: 1.8,
                              letterSpacing: 0.3,
                            ),
                            children: _buildStyledText(_displayedText),
                          ),
                        ),
                        // Blinking cursor during animation
                        if (!_isTypingComplete)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _BlinkingCursor(),
                          ),
                        // Extra padding at bottom for smooth scrolling
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build styled text with proper formatting
  List<TextSpan> _buildStyledText(String text) {
    List<TextSpan> spans = [];
    List<String> lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      
      // Headers (lines with emojis at start)
      if (line.startsWith('🎯') || 
          line.startsWith('🎮') || 
          line.startsWith('⚡') || 
          line.startsWith('🌱') || 
          line.startsWith('💡') ||
          line.startsWith('🎊')) {
        spans.add(TextSpan(
          text: line,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFCD34D),
            height: 2.0,
          ),
        ));
      }
      // Numbered items
      else if (line.contains('1️⃣') || 
               line.contains('2️⃣') || 
               line.contains('3️⃣') || 
               line.contains('4️⃣') || 
               line.contains('5️⃣')) {
        spans.add(TextSpan(
          text: line,
          style: GoogleFonts.notoSans(
            fontSize: 16,
            color: const Color(0xFF86EFAC),
            height: 1.8,
            fontWeight: FontWeight.w500,
          ),
        ));
      }
      // Bullet points
      else if (line.startsWith('•')) {
        spans.add(TextSpan(
          text: line,
          style: GoogleFonts.notoSans(
            fontSize: 16,
            color: const Color(0xFFBBF7D0),
            height: 1.8,
          ),
        ));
      }
      // Regular text
      else if (line.trim().isNotEmpty) {
        spans.add(TextSpan(
          text: line,
          style: GoogleFonts.notoSans(
            fontSize: 16,
            color: Colors.white,
            height: 1.8,
          ),
        ));
      }
      
      // Add newline between sections (except for last line)
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    
    return spans;
  }
}

// Smooth blinking cursor widget
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFF86EFAC),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ============================================================================
// SCORES SCREEN - PLACEHOLDER
// ============================================================================

class ScoresScreen extends StatelessWidget {
  const ScoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF064E3B),
              Color(0xFF166534),
              Color(0xFF78350F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        '🏆 Leaderboard',
                        style: GoogleFonts.vt323(
                          fontSize: 28,
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2563EB),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          size: 80,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Leaderboard Coming Soon!',
                          style: GoogleFonts.vt323(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'User accounts and scoring system\nwill be implemented soon.\n\nCompete with friends and climb\nto the top of the leaderboard! 🚀',
                          style: GoogleFonts.vt323(
                            fontSize: 16,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
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
    );
  }
}

// ============================================================================
// SETTINGS SCREEN
// ============================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _vibrationsEnabled = true;
  bool _notificationsEnabled = true;
  double _gameDifficulty = 1.0; // 0=Easy, 1=Normal, 2=Hard

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF064E3B),
              Color(0xFF166534),
              Color(0xFF78350F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        '⚙️ Settings',
                        style: GoogleFonts.vt323(
                          fontSize: 28,
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Settings Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildSettingsSection(
                        title: '🔊 Audio Settings',
                        children: [
                          _buildSwitchTile(
                            title: 'Sound Effects',
                            subtitle: 'Enable/disable game sounds',
                            value: _soundEnabled,
                            onChanged: (val) => setState(() => _soundEnabled = val),
                          ),
                          _buildSwitchTile(
                            title: 'Background Music',
                            subtitle: 'Enable/disable music',
                            value: _musicEnabled,
                            onChanged: (val) => setState(() => _musicEnabled = val),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildSettingsSection(
                        title: '📱 Gameplay Settings',
                        children: [
                          _buildSwitchTile(
                            title: 'Vibrations',
                            subtitle: 'Haptic feedback on matches',
                            value: _vibrationsEnabled,
                            onChanged: (val) => setState(() => _vibrationsEnabled = val),
                          ),
                          _buildDifficultySlider(),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildSettingsSection(
                        title: '🔔 Notifications',
                        children: [
                          _buildSwitchTile(
                            title: 'Push Notifications',
                            subtitle: 'Receive game updates',
                            value: _notificationsEnabled,
                            onChanged: (val) => setState(() => _notificationsEnabled = val),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildSettingsSection(
                        title: 'ℹ️ About',
                        children: [
                          _buildInfoTile(
                            title: 'Version',
                            value: '1.0.0',
                          ),
                          _buildInfoTile(
                            title: 'Developer',
                            value: 'Yonder Spaces Ltd',
                          ),
                          _buildActionTile(
                            title: 'Privacy Policy',
                            icon: Icons.privacy_tip,
                            onTap: () {
                              // Implement privacy policy view
                            },
                          ),
                          _buildActionTile(
                            title: 'Terms of Service',
                            icon: Icons.description,
                            onTap: () {
                              // Implement terms view
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Reset Progress Button
                      ElevatedButton.icon(
                        onPressed: () => _showResetDialog(),
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          'Reset Game Progress',
                          style: GoogleFonts.vt323(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF22C55E),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: GoogleFonts.vt323(
                fontSize: 22,
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.vt323(
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.vt323(
          fontSize: 14,
          color: Colors.white60,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF22C55E),
      ),
    );
  }

  Widget _buildDifficultySlider() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Difficulty',
            style: GoogleFonts.vt323(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _gameDifficulty,
                  min: 0,
                  max: 2,
                  divisions: 2,
                  activeColor: const Color(0xFF22C55E),
                  onChanged: (val) => setState(() => _gameDifficulty = val),
                ),
              ),
              Text(
                _gameDifficulty == 0
                    ? 'Easy'
                    : _gameDifficulty == 1
                        ? 'Normal'
                        : 'Hard',
                style: GoogleFonts.vt323(
                  fontSize: 16,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
  }) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.vt323(
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      trailing: Text(
        value,
        style: GoogleFonts.vt323(
          fontSize: 16,
          color: Colors.amber,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.vt323(
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      trailing: Icon(icon, color: Colors.amber),
      onTap: onTap,
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1E17),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.red, width: 3),
        ),
        title: Text(
          '⚠️ Reset Progress?',
          style: GoogleFonts.vt323(color: Colors.white, fontSize: 24),
        ),
        content: Text(
          'This will delete all your game progress, scores, and unlocked items. This action cannot be undone!',
          style: GoogleFonts.vt323(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.vt323(fontSize: 16, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement reset functionality
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Progress reset functionality will be implemented soon',
                    style: GoogleFonts.vt323(fontSize: 16),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('RESET', style: GoogleFonts.vt323(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}