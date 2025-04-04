import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workouts.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 2, // Incremented version
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add the `part` column to the `workouts` table
          await db.execute(
            'ALTER TABLE workouts ADD COLUMN part TEXT NOT NULL DEFAULT "Part 1"',
          );
        }
      },
      onOpen: (db) async {
        // Check if the transactions table exists
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='transactions';",
        );
        if (tables.isEmpty) {
          // If the table doesn't exist, create it
          await _createDB(db, 1);
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        muscleGroup TEXT NOT NULL,
        part TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutId INTEGER NOT NULL,
        weight TEXT NOT NULL,
        reps TEXT NOT NULL,
        sets TEXT NOT NULL,
        FOREIGN KEY (workoutId) REFERENCES workouts (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        isIncome INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertWorkout(
    String name,
    String muscleGroup,
    String part,
  ) async {
    final db = await instance.database;
    return await db.insert('workouts', {
      'name': name,
      'muscleGroup': muscleGroup,
      'part': part,
    });
  }

  Future<int> insertSet(
    int workoutId,
    String weight,
    String reps,
    String sets,
  ) async {
    final db = await instance.database;
    return await db.insert('sets', {
      'workoutId': workoutId,
      'weight': weight,
      'reps': reps,
      'sets': sets,
    });
  }

  Future<int> insertTransaction(
    String title,
    double amount,
    bool isIncome,
  ) async {
    final db = await instance.database;
    return await db.insert('transactions', {
      'title': title,
      'amount': amount,
      'isIncome': isIncome ? 1 : 0,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchWorkouts(String muscleGroup) async {
    final db = await instance.database;
    return await db.query(
      'workouts',
      where: 'muscleGroup = ?',
      whereArgs: [muscleGroup],
    );
  }

  Future<List<Map<String, dynamic>>> fetchWorkoutsByPart(
    String muscleGroup,
    String part,
  ) async {
    final db = await instance.database;
    return await db.query(
      'workouts',
      where: 'muscleGroup = ? AND part = ?',
      whereArgs: [muscleGroup, part],
    );
  }

  Future<List<Map<String, dynamic>>> fetchSets(int workoutId) async {
    final db = await instance.database;
    return await db.query(
      'sets',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
    );
  }

  Future<List<Map<String, dynamic>>> fetchTransactions(bool isIncome) async {
    final db = await instance.database;
    return await db.query(
      'transactions',
      where: 'isIncome = ?',
      whereArgs: [isIncome ? 1 : 0],
      orderBy: 'date DESC',
    );
  }

  Future<int> updateWorkout(int id, String name) async {
    final db = await instance.database;
    return await db.update(
      'workouts',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateTransaction(int id, String title, double amount) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {
        'title': title,
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteWorkout(int id) async {
    final db = await instance.database;
    await db.delete('sets', where: 'workoutId = ?', whereArgs: [id]);
    return await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSet(int id) async {
    final db = await instance.database;
    return await db.delete('sets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteWorkoutByPart(String muscleGroup, String part) async {
    final db = await instance.database;

    // Fetch all workouts for the given muscle group and part
    final workouts = await db.query(
      'workouts',
      where: 'muscleGroup = ? AND part = ?',
      whereArgs: [muscleGroup, part],
    );

    // Delete associated sets for each workout
    for (var workout in workouts) {
      await db.delete(
        'sets',
        where: 'workoutId = ?',
        whereArgs: [workout['id']],
      );
    }

    // Delete workouts for the given muscle group and part
    await db.delete(
      'workouts',
      where: 'muscleGroup = ? AND part = ?',
      whereArgs: [muscleGroup, part],
    );
  }
}
