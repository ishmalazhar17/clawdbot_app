// =====================================================================
// db_helper.dart — sets up and manages the app's LOCAL database.
//
// UPDATED Aug 27: added a "category" column to the reminders table
// (e.g. Health, Work, Family), wiring up the categories feature built
// in Settings on Aug 24 (which, until now, wasn't actually used
// anywhere else in the app).
//
// IMPORTANT - DATABASE MIGRATIONS: since you already have a real
// database file on your test device from earlier testing, we can't
// just add a new column to onCreate() - that only runs on a brand
// new install. Instead, we bump the "version" number and add an
// "onUpgrade" function, which Android runs automatically to update
// an EXISTING database to match the new schema, without losing any
// data already in it.
// =====================================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _database;

  DBHelper._privateConstructor();

  static final DBHelper instance = DBHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'clawdbot.db');

    return await openDatabase(
      path,
      // BUMPED from 1 to 2 - this tells Android "the schema changed,
      // please run onUpgrade to bring existing databases up to date."
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Runs ONLY the very first time the app is installed - defines the
  // full, up-to-date schema from scratch (includes the category
  // column directly, since a brand new install has no old data to
  // migrate).
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'green',
        completed INTEGER NOT NULL DEFAULT 0,
        category TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE object_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        object_name TEXT NOT NULL,
        location_name TEXT,
        latitude REAL,
        longitude REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE context_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // Runs automatically for anyone who already has version 1 of the
  // database installed (i.e. everyone testing before today). Adds
  // the new column to the EXISTING table without deleting any data.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE reminders ADD COLUMN category TEXT');
    }
  }

  // ===================================================================
  // REMINDER functions
  // ===================================================================

  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder);
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await database;
    return await db.query('reminders', orderBy: 'id DESC');
  }

  Future<int> updateReminderStatus(int id, int completed) async {
    final db = await database;
    return await db.update(
      'reminders',
      {'completed': completed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // ---- NEW (Aug 28): updates an EXISTING reminder's fields ----
  // Different from updateReminderStatus (which only ever touches the
  // 'completed' flag) - this lets any combination of fields (task,
  // date, time, priority, category) be changed, for real editing.
  Future<int> updateReminder(int id, Map<String, dynamic> updatedFields) async {
    final db = await database;
    return await db.update(
      'reminders',
      updatedFields,
      where: 'id = ?',
      whereArgs: [id],
    );
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

  Future<int> deleteObjectLocation(int id) async {
    final db = await database;
    return await db.delete('object_locations', where: 'id = ?', whereArgs: [id]);
  }

  // ===================================================================
  // CONTEXT LOG functions
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
}
