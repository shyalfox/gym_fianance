import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/database_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final data = await dbHelper.fetchWorkouts(widget.muscleGroup);
    setState(() {
      workouts.clear();
      workouts.addAll(
        data.map(
          (workout) => {
            'id': workout['id'],
            'nameController': TextEditingController(text: workout['name']),
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
                'weightController': TextEditingController(text: set['weight']),
                'repsController': TextEditingController(text: set['reps']),
              };
            }).toList();
      });
    }
  }

  Future<void> _saveWorkout(int workoutIndex) async {
    final workout = workouts[workoutIndex];
    final name = workout['nameController'].text;

    if (workout['id'] == null) {
      // Insert new workout
      final workoutId = await dbHelper.insertWorkout(name, widget.muscleGroup);
      workout['id'] = workoutId;

      // Save sets
      for (var set in workout['sets']) {
        await dbHelper.insertSet(
          workoutId,
          set['weightController'].text,
          set['repsController'].text,
          '',
        ); // Empty string for sets
      }
    } else {
      // Update existing workout
      await dbHelper.updateWorkout(workout['id'], name);

      // Save sets
      for (var set in workout['sets']) {
        await dbHelper.insertSet(
          workout['id'],
          set['weightController'].text,
          set['repsController'].text,
          '',
        ); // Empty string for sets
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

  void _addWorkout() {
    setState(() {
      workouts.add({
        'id': null,
        'nameController': TextEditingController(),
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
        'weightController': TextEditingController(),
        'repsController': TextEditingController(),
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
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Handle deletions
    for (var workoutId in deletedWorkoutIds) {
      final workoutRef = firestore
          .collection('workouts')
          .doc(workoutId.toString());
      final setsSnapshot = await workoutRef.collection('sets').get();
      for (var setDoc in setsSnapshot.docs) {
        batch.delete(setDoc.reference);
      }
      batch.delete(workoutRef);
    }
    deletedWorkoutIds.clear();

    // Handle additions/updates
    for (var workout in workouts) {
      final workoutRef = firestore
          .collection('workouts')
          .doc(
            workout['id']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString(),
          );
      batch.set(workoutRef, {
        'name': workout['nameController'].text,
        'muscleGroup': widget.muscleGroup,
      });

      final setsSnapshot = await workoutRef.collection('sets').get();
      for (var setDoc in setsSnapshot.docs) {
        batch.delete(setDoc.reference); // Clear existing sets
      }

      for (var set in workout['sets']) {
        final setRef = workoutRef.collection('sets').doc();
        batch.set(setRef, {
          'weight': set['weightController'].text,
          'reps': set['repsController'].text,
        });
      }
    }

    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data synced to Firestore successfully!')),
    );
  }

  Future<void> _fetchFromFirestore() async {
    final firestore = FirebaseFirestore.instance;
    final querySnapshot =
        await firestore
            .collection('workouts')
            .where('muscleGroup', isEqualTo: widget.muscleGroup)
            .get();

    final fetchedWorkouts =
        querySnapshot.docs.map((doc) async {
          final setsSnapshot = await doc.reference.collection('sets').get();
          return {
            'id': int.tryParse(doc.id),
            'nameController': TextEditingController(text: doc['name']),
            'sets':
                setsSnapshot.docs.map((setDoc) {
                  return {
                    'weightController': TextEditingController(
                      text: setDoc['weight'],
                    ),
                    'repsController': TextEditingController(
                      text: setDoc['reps'],
                    ),
                  };
                }).toList(),
          };
        }).toList();

    final resolvedWorkouts = await Future.wait(fetchedWorkouts);

    setState(() {
      workouts.clear();
      workouts.addAll(resolvedWorkouts);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data fetched from Firestore successfully!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.muscleGroup} Workouts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: _syncToFirestore,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download),
            onPressed: _fetchFromFirestore,
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
                                onPressed: () => _deleteWorkout(workoutIndex),
                              ),
                            ],
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
