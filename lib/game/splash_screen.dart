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
            Text(
              'For Peter N. Njuguna & Marsha W. Kimani',
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
          
          // Secondary buttons - responsive layout
          LayoutBuilder(
            builder: (context, buttonConstraints) {
              bool shouldStack = constraints.maxWidth < 500;
              double buttonFontSize = (constraints.maxWidth * 0.024).clamp(13.0, 16.0);
              
              if (shouldStack) {
                // Stack vertically on small screens
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSecondaryButton(
                      '📖 How to Play',
                      const Color(0xFFD97706),
                      cardWidth,
                      buttonFontSize,
                    ),
                    SizedBox(height: spacing * 0.3),
                    _buildSecondaryButton(
                      '🏆 Scores',
                      const Color(0xFF2563EB),
                      cardWidth,
                      buttonFontSize,
                    ),
                    SizedBox(height: spacing * 0.3),
                    _buildSecondaryButton(
                      '⚙️ Settings',
                      const Color(0xFF7C3AED),
                      cardWidth,
                      buttonFontSize,
                    ),
                  ],
                );
              } else {
                // Horizontal layout on larger screens
                return Wrap(
                  alignment: WrapAlignment.center,
                  spacing: constraints.maxWidth * 0.02,
                  runSpacing: spacing * 0.3,
                  children: [
                    _buildSecondaryButton(
                      '📖 How to Play',
                      const Color(0xFFD97706),
                      null,
                      buttonFontSize,
                    ),
                    _buildSecondaryButton(
                      '🏆 Scores',
                      const Color(0xFF2563EB),
                      null,
                      buttonFontSize,
                    ),
                    _buildSecondaryButton(
                      '⚙️ Settings',
                      const Color(0xFF7C3AED),
                      null,
                      buttonFontSize,
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton(String text, Color color, double? width, double fontSize) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.8),
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * 1.2,
            vertical: fontSize * 0.75,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: GoogleFonts.vt323(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

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