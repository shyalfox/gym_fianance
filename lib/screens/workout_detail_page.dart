import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/database_helper.dart';
import '../services/auth_service.dart';

class WorkoutDetailPage extends StatefulWidget {
  final String muscleGroup;

  const WorkoutDetailPage({super.key, required this.muscleGroup});

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  final List<Map<String, dynamic>> workouts = [];
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  int? editingWorkoutIndex;
  final List<int> deletedWorkoutIds = [];
  String selectedPart = 'Part 1';
  final List<String> parts = ['Part 1', 'Part 2'];

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final data = await dbHelper.fetchWorkoutsByPart(
      widget.muscleGroup,
      selectedPart,
    );
    setState(() {
      workouts.clear();
      workouts.addAll(
        data.map(
          (workout) => {
            'id': workout['id'],
            'nameController': TextEditingController(
              text: workout['name'], // Proper initialization
            ),
            'part': workout['part'],
            'sets': [],
          },
        ),
      );
    });

    for (var workout in workouts) {
      final sets = await dbHelper.fetchSets(workout['id']);
      setState(() {
        workout['sets'] =
            sets.map((set) {
              return {
                'id': set['id'], // Ensure set ID is included
                'weightController': TextEditingController(
                  text: set['weight'], // Proper initialization
                ),
                'repsController': TextEditingController(
                  text: set['reps'], // Proper initialization
                ),
              };
            }).toList();
      });
    }
  }

  Future<void> _saveWorkout(int workoutIndex) async {
    final workout = workouts[workoutIndex];
    final name = workout['nameController'].text;
    final part = workout['part'];

    if (workout['id'] == null) {
      // Insert new workout
      final workoutId = await dbHelper.insertWorkout(
        name,
        widget.muscleGroup,
        part,
      );
      setState(() {
        workout['id'] = workoutId; // Update the local state with the new ID
      });

      // Save sets
      for (var set in workout['sets']) {
        await dbHelper.insertSet(
          workoutId,
          set['weightController'].text,
          set['repsController'].text,
          '',
        );
      }
    } else {
      // Update existing workout
      await dbHelper.updateWorkout(workout['id'], name);

      // Save sets
      await dbHelper.deleteWorkout(workout['id']); // Clear existing sets
      for (var set in workout['sets']) {
        await dbHelper.insertSet(
          workout['id'],
          set['weightController'].text,
          set['repsController'].text,
          '',
        );
      }
    }

    setState(() {
      editingWorkoutIndex = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout saved successfully!')),
    );
  }

  Future<void> _deleteWorkout(int workoutIndex) async {
    final workout = workouts[workoutIndex];
    if (workout['id'] != null) {
      deletedWorkoutIds.add(workout['id']);
      await dbHelper.deleteWorkout(workout['id']);
    }
    setState(() {
      workouts.removeAt(workoutIndex);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout deleted successfully!')),
    );
  }

  Future<void> _confirmAndDeleteWorkout(int workoutIndex) async {
    await _showConfirmationDialog(
      context: context,
      title: 'Delete Workout',
      content: 'Are you sure you want to delete this workout?',
      onConfirm: () => _deleteWorkout(workoutIndex),
    );
  }

  void _addWorkout() {
    setState(() {
      workouts.add({
        'id': null,
        'nameController': TextEditingController(), // Proper initialization
        'part': selectedPart, // Automatically assign selectedPart
        'sets': [],
      });
      editingWorkoutIndex = workouts.length - 1;
    });
  }

  void _editWorkout(int workoutIndex) {
    setState(() {
      editingWorkoutIndex = workoutIndex;
    });
  }

  void _addSet(int workoutIndex) {
    setState(() {
      workouts[workoutIndex]['sets'].add({
        'weightController': TextEditingController(), // Proper initialization
        'repsController': TextEditingController(), // Proper initialization
      });
    });
  }

  void _removeSet(int workoutIndex, int setIndex) {
    setState(() {
      workouts[workoutIndex]['sets'][setIndex]['weightController'].dispose();
      workouts[workoutIndex]['sets'][setIndex]['repsController'].dispose();
      workouts[workoutIndex]['sets'].removeAt(setIndex);
    });
  }

  Future<void> _syncToFirestore() async {
    final userId = AuthService().getCurrentUserId();
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in.')));
      return;
    }

    final muscleGroupRef = FirebaseFirestore.instance
        .collection('users/$userId/workouts')
        .doc(widget.muscleGroup);

    // Fetch existing parts from Firebase
    final partSnapshot = await muscleGroupRef.get();
    final existingParts =
        partSnapshot.exists
            ? (partSnapshot.data() as Map<String, dynamic>)
            : <String, dynamic>{};

    // Prepare data for the selected part
    final partData =
        workouts.map((workout) {
          return {
            'id':
                workout['id']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            'name': workout['nameController'].text,
            'sets':
                workout['sets'].map((set) {
                  return {
                    'weight': set['weightController'].text,
                    'reps': set['repsController'].text,
                  };
                }).toList(),
          };
        }).toList();

    // Update the selected part in Firebase
    existingParts[selectedPart] = partData;

    // Sync local data to Firebase
    await muscleGroupRef.set(existingParts);

    // Delete exercises in Firebase that are not present locally
    if (existingParts[selectedPart] != null) {
      final cloudExercises =
          (existingParts[selectedPart] as List).map((e) => e['id']).toSet();
      final localExercises =
          workouts.map((workout) => workout['id']?.toString()).toSet();
      final exercisesToDelete = cloudExercises.difference(localExercises);

      existingParts[selectedPart] =
          (existingParts[selectedPart] as List)
              .where((e) => !exercisesToDelete.contains(e['id']))
              .toList();

      await muscleGroupRef.set(existingParts);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data synced to Firestore successfully!')),
    );
  }

  Future<void> _fetchFromFirestore() async {
    final userId = AuthService().getCurrentUserId();
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in.')));
      return;
    }

    final muscleGroupRef = FirebaseFirestore.instance
        .collection('users/$userId/workouts')
        .doc(widget.muscleGroup);

    // Fetch data for the selected part
    final partSnapshot = await muscleGroupRef.get();
    if (!partSnapshot.exists ||
        !(partSnapshot.data() as Map<String, dynamic>).containsKey(
          selectedPart,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data found for the selected part!')),
      );
      return;
    }

    final partData =
        (partSnapshot.data() as Map<String, dynamic>)[selectedPart] as List;

    // Replace local data for the selected part with fetched data
    setState(() {
      workouts.clear();
      workouts.addAll(
        partData.map((workout) {
          return {
            'id':
                null, // Temporarily set to null until synced with the database
            'nameController': TextEditingController(
              text: workout['name'] ?? '',
            ),
            'part': selectedPart,
            'sets':
                (workout['sets'] as List).map((set) {
                  return {
                    'weightController': TextEditingController(
                      text: set['weight'] ?? '',
                    ),
                    'repsController': TextEditingController(
                      text: set['reps'] ?? '',
                    ),
                  };
                }).toList(),
          };
        }).toList(),
      );
    });

    // Save fetched data locally and update the `id` field
    await dbHelper.deleteWorkoutByPart(widget.muscleGroup, selectedPart);
    for (var workout in workouts) {
      final workoutId = await dbHelper.insertWorkout(
        workout['nameController'].text,
        widget.muscleGroup,
        workout['part'],
      );
      workout['id'] = workoutId;

      for (var set in workout['sets']) {
        await dbHelper.insertSet(
          workoutId,
          set['weightController'].text,
          set['repsController'].text,
          '',
        );
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data fetched and stored locally successfully!'),
      ),
    );
  }

  Future<void> _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
    );

    if (result == true) {
      onConfirm();
    }
  }

  Future<void> _confirmAndFetchFromFirestore() async {
    await _showConfirmationDialog(
      context: context,
      title: 'Fetch Data',
      content:
          'Fetching data will delete all local data for the selected part and overwrite it with cloud data. Do you want to proceed?',
      onConfirm: _fetchFromFirestore,
    );
  }

  Future<void> _confirmAndSyncToFirestore() async {
    await _showConfirmationDialog(
      context: context,
      title: 'Sync Data',
      content:
          'Syncing data will overwrite all cloud data for the selected part with your local data. Do you want to proceed?',
      onConfirm: _syncToFirestore,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.muscleGroup} Workouts'),
        centerTitle: true,
        actions: [
          DropdownButton<String>(
            value: selectedPart,
            items:
                parts
                    .map(
                      (part) =>
                          DropdownMenuItem(value: part, child: Text(part)),
                    )
                    .toList(),
            onChanged: (value) {
              setState(() {
                selectedPart = value!;
                _loadWorkouts(); // Reload workouts based on selected part
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: _confirmAndSyncToFirestore,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download),
            onPressed: _confirmAndFetchFromFirestore,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: workouts.length,
          itemBuilder: (context, workoutIndex) {
            final workout = workouts[workoutIndex];
            final isEditing = editingWorkoutIndex == workoutIndex;

            return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEditing)
                      Column(
                        children: [
                          TextField(
                            controller: workout['nameController'],
                            decoration: const InputDecoration(
                              labelText: 'Workout Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: workout['sets'].length,
                            itemBuilder: (context, setIndex) {
                              final set = workout['sets'][setIndex];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: set['weightController'],
                                        decoration: const InputDecoration(
                                          labelText: 'Weight(kg)',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: set['repsController'],
                                        decoration: const InputDecoration(
                                          labelText: 'Reps',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          () => _removeSet(
                                            workoutIndex,
                                            setIndex,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _addSet(workoutIndex),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Set'),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workout['nameController'].text,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Sets: ${workout['sets'].length}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _editWorkout(workoutIndex),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed:
                                        () => _confirmAndDeleteWorkout(
                                          workoutIndex,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                workout['sets'].map<Widget>((set) {
                                  return Text(
                                    'Weight: ${set['weightController'].text}, Reps: ${set['repsController'].text}',
                                    style: const TextStyle(fontSize: 14),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    if (isEditing)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: () => _saveWorkout(workoutIndex),
                            child: const Text('Save'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                editingWorkoutIndex = null;
                              });
                            },
                            child: const Text('Cancel'),
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
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _addWorkout,
      ),
    );
  }
}
