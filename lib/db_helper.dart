// =====================================================================
// db_helper.dart — sets up and manages the app's LOCAL database.
//
// This uses a package called "sqflite" which lets a Flutter app store
// data directly on the phone, in a real database (SQLite) — similar
// to how a spreadsheet stores rows and columns, but built for apps.
//
// This file is a SINGLETON — meaning the whole app shares ONE single
// connection to the database, instead of opening a new one every time
// we need to read/write something. The "instance" pattern below is
// what makes that work.
// =====================================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  // This holds the one-and-only instance of this class, shared by the
  // whole app. Starts as "null" (nothing yet) until first used.
  static Database? _database;

  // A private constructor — this stops other files from accidentally
  // creating a second DBHelper by writing "DBHelper()" themselves.
  DBHelper._privateConstructor();

  // The single shared instance everyone in the app will use.
  static final DBHelper instance = DBHelper._privateConstructor();

  // This function returns the database connection, creating it the
  // first time it's called, and just reusing it every time after.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // Sets up the actual database file on the phone's storage.
  Future<Database> _initDB() async {
    // getDatabasesPath() finds the correct folder on the phone/emulator
    // where app databases are supposed to live.
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'clawdbot.db');

    // openDatabase either opens the existing file, or (the first time
    // the app ever runs) creates it fresh using onCreate below.
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Runs ONLY the very first time the app is installed/run — this is
  // where we define the SHAPE of our data (the tables and columns).
  Future<void> _onCreate(Database db, int version) async {
    // ---- REMINDERS table ----
    // Matches the shape Person A's backend sends back from /chat and
    // /parse_reminder, so saving a reminder from the chatbot is a
    // direct one-to-one mapping, no extra conversion needed.
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'green',
        completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ---- NOTES table ----
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // ---- OBJECT_LOCATIONS table ----
    // latitude/longitude are nullable for now since the location
    // feature is a later task (Aug 23/24) — this table just needs to
    // exist and be ready for it.
    await db.execute('''
      CREATE TABLE object_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        object_name TEXT NOT NULL,
        location_name TEXT,
        latitude REAL,
        longitude REAL
      )
    ''');

    // ---- CONTEXT_LOGS table ----
    // Records what the user does and when, so the (future) suggestion
    // engine can look for patterns — e.g. "reminder created" logged
    // with a timestamp every time one is added.
    await db.execute('''
      CREATE TABLE context_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // ===================================================================
  // REMINDER functions — Create, Read, Update, Delete (CRUD)
  // ===================================================================

  // Adds a new reminder. Returns the new reminder's auto-generated id.
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder);
  }

  // Returns ALL reminders as a list, most recently added first.
  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await database;
    return await db.query('reminders', orderBy: 'id DESC');
  }

  // Marks a reminder as completed (1) or not completed (0).
  Future<int> updateReminderStatus(int id, int completed) async {
    final db = await database;
    return await db.update(
      'reminders',
      {'completed': completed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Deletes a reminder by its id.
  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // ===================================================================
  // NOTE functions
  // ===================================================================

  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await database;
    return await db.insert('notes', note);
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    final db = await database;
    return await db.query('notes', orderBy: 'id DESC');
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ===================================================================
  // OBJECT LOCATION functions
  // ===================================================================

  Future<int> insertObjectLocation(Map<String, dynamic> location) async {
    final db = await database;
    return await db.insert('object_locations', location);
  }

  Future<List<Map<String, dynamic>>> getObjectLocations() async {
    final db = await database;
    return await db.query('object_locations', orderBy: 'id DESC');
  }

  // ===================================================================
  // CONTEXT LOG functions (for the future suggestion engine)
  // ===================================================================

  Future<int> logContext(String actionType) async {
    final db = await database;
    return await db.insert('context_logs', {
      'action_type': actionType,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getContextLogs() async {
    final db = await database;
    return await db.query('context_logs', orderBy: 'id DESC');
  }
  Future<int> deleteObjectLocation(int id) async {
    final db = await database;
    return await db.delete('object_locations', where: 'id = ?', whereArgs: [id]);
  }
}