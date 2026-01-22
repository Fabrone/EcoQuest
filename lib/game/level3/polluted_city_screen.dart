import 'package:flutter/material.dart';

class PollutedCityScreen extends StatelessWidget {
  const PollutedCityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay for UI elements
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top section: Title and Level
                Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Text(
                        'Polluted City: Waste Crisis',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 4.0,
                              color: Colors.black54,
                              offset: Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Text(
                      'Level: 3',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 4.0,
                            color: Colors.black54,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Middle section: Tasks list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Each task is a row with a green checkmark icon and text.
                      // Download a green checkmark icon (e.g., from icons8 or similar) and save as 'assets/checkmark.png'.
                      // Alternatively, use Icons.check_circle with color: Colors.green.
                      // For exact match, use asset image.
                      _buildTaskRow('Collect Waste'),
                      _buildTaskRow('Repair Sewers'),
                      _buildTaskRow('Sort Recyclables'),
                      _buildTaskRow('Craft Upcycled Items'),
                    ],
                  ),
                ),
                // Bottom section: Buttons and icons
                Column(
                  children: [
                    // Resource icons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Eco-Points: Download a green eco/leaf icon and box background if needed, save as 'assets/eco_points.png'.
                        // For simplicity, using Container with text and icon.
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: .8),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: const Row(
                            children: [
                              // Replace with AssetImage('assets/eco_icon.png') if using custom icon.
                              Icon(Icons.eco, color: Colors.white, size: 20),
                              SizedBox(width: 4),
                              Text(
                                'Eco-Points',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Blueprints: Download a blueprint icon and blue box, save as 'assets/blueprints.png'.
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: .8),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: const Row(
                            children: [
                              // Replace with AssetImage('assets/blueprint_icon.png') if custom.
                              Icon(Icons.map, color: Colors.white, size: 20), // Placeholder; use Icons.map or custom blueprint icon.
                              SizedBox(width: 4),
                              Text(
                                'Blueprints',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Water drop: Download a blue water drop icon, save as 'assets/water_drop.png'.
                        const Icon(
                          Icons.water_drop,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Start Level button
                    ElevatedButton(
                      onPressed: () {
                        // Add your start level logic here, e.g., Navigator.push to next screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text(
                        'Start Level',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Bottom controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Controls logic, e.g., show dialog with controls
                          },
                          child: const Text(
                            'Controls',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () {
                            // Skip intro logic
                          },
                          child: const Text(
                            'Skip Intro',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
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

  Widget _buildTaskRow(String task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Green checkmark: Use Icons.check for simplicity, or AssetImage for custom.
          const Icon(
            Icons.check,
            color: Colors.green,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            task,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 4.0,
                  color: Colors.black54,
                  offset: Offset(2.0, 2.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}