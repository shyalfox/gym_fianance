import 'package:flutter/material.dart';
import 'workout_detail_page.dart'; // Ensure this import is correct

class GymHomePage extends StatelessWidget {
  const GymHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> muscleGroups = [
      {'title': 'Chest', 'icon': Icons.accessibility_new}, // Updated icon
      {'title': 'Triceps', 'icon': Icons.pan_tool_alt}, // Updated icon
      {'title': 'Back', 'icon': Icons.accessibility}, // Updated icon
      {'title': 'Biceps', 'icon': Icons.fitness_center}, // Updated icon
      {'title': 'Shoulder', 'icon': Icons.swap_vert_circle}, // Updated icon
      {'title': 'Leg', 'icon': Icons.directions_walk}, // Updated icon
      {'title': 'Abs/Core', 'icon': Icons.sports_gymnastics}, // Updated icon
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Gym Workouts'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: muscleGroups.length,
          itemBuilder: (context, index) {
            final group = muscleGroups[index];
            return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16.0),
                leading: Icon(
                  group['icon'],
                  size: 40,
                  color:
                      Theme.of(context).colorScheme.secondary, // Adaptive color
                ),
                title: Text(
                  group['title'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => WorkoutDetailPage(
                            muscleGroup: group['title'],
                          ), // Ensure this class exists
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
