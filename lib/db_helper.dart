// =====================================================================
// db_helper.dart — sets up and manages the app's LOCAL database.
//
// UPDATED Aug 27: added a "category" column to the reminders table.
//
// UPDATED Sep 30 (sync): added a "last_modified" column to reminders,
// notes, and object_locations, used for conflict resolution during
// cloud sync.
//
// UPDATED Sep 30 (offline retry queue): added a "synced" column to
// reminders, notes, and object_locations (1 = server has this row,
// 0 = this row has local changes the server doesn't know about yet).
// Also added a "pending_deletes" table, which remembers rows that
// were deleted locally while offline but still need to be deleted on
// the server once we're back online.
//
// Any new reminder/note/location created locally is given a NEGATIVE
// placeholder id (instead of letting SQLite auto-assign a normal
// positive one) until the server confirms it and hands back its own
// real (positive) id. This way, a negative id always means "the
// server doesn't know about this yet" and a positive id always means
// "this exists on the server."
//
// IMPORTANT - DATABASE MIGRATIONS: since real devices already have a
// database file from earlier testing, we bump the "version" number
// and add to "onUpgrade" so existing installs get the new columns
// without losing any data.
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
      // BUMPED from 3 to 4 - adds the "synced" columns and the
      // "pending_deletes" table for the offline retry queue.
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Runs ONLY the very first time the app is installed - defines the
  // full, up-to-date schema from scratch.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY,
        task TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'green',
        completed INTEGER NOT NULL DEFAULT 0,
        category TEXT,
        last_modified TEXT,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT,
        created_at TEXT NOT NULL,
        last_modified TEXT,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE object_locations (
        id INTEGER PRIMARY KEY,
        object_name TEXT NOT NULL,
        location_name TEXT,
        latitude REAL,
        longitude REAL,
        last_modified TEXT,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE context_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_deletes (
        table_name TEXT NOT NULL,
        row_id INTEGER NOT NULL,
        PRIMARY KEY (table_name, row_id)
      )
    ''');
  }

  // Runs automatically for anyone who already has an older version of
  // the database installed. Adds new columns/tables without deleting
  // any existing data.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE reminders ADD COLUMN category TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE reminders ADD COLUMN last_modified TEXT');
      await db.execute('ALTER TABLE notes ADD COLUMN last_modified TEXT');
      await db.execute('ALTER TABLE object_locations ADD COLUMN last_modified TEXT');
    }
    if (oldVersion < 4) {
      // Existing rows are assumed already synced (synced = 1), since
      // they either came from the server already or were created
      // before this feature existed and have positive ids.
      await db.execute("ALTER TABLE reminders ADD COLUMN synced INTEGER NOT NULL DEFAULT 1");
      await db.execute("ALTER TABLE notes ADD COLUMN synced INTEGER NOT NULL DEFAULT 1");
      await db.execute("ALTER TABLE object_locations ADD COLUMN synced INTEGER NOT NULL DEFAULT 1");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_deletes (
          table_name TEXT NOT NULL,
          row_id INTEGER NOT NULL,
          PRIMARY KEY (table_name, row_id)
        )
      ''');
    }
  }

  // ===================================================================
  // Helper: generates a temporary negative id for a brand-new local
  // row that hasn't been confirmed by the server yet. Based on the
  // current timestamp in milliseconds, so it's always unique and
  // always negative (never collides with a real server id, which is
  // always positive).
  // ===================================================================
  int generateTempId() {
    return -DateTime.now().millisecondsSinceEpoch;
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

  Future<List<Map<String, dynamic>>> getUnsyncedReminders() async {
    final db = await database;
    return await db.query('reminders', where: 'synced = 0');
  }

  Future<void> markReminderSynced(int id) async {
    final db = await database;
    await db.update('reminders', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // Used after a locally-created reminder (negative temp id) is
  // successfully pushed to the server and the server hands back its
  // own real (positive) id. Swaps the row over to that real id.
  Future<void> replaceReminderId(int oldId, Map<String, dynamic> newData) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('reminders', where: 'id = ?', whereArgs: [oldId]);
      await txn.insert('reminders', newData);
    });
  }

  Future<int> updateReminderStatus(int id, int completed) async {
    final db = await database;
    return await db.update(
      'reminders',
      {
        'completed': completed,
        'last_modified': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Deletes a reminder LOCALLY only. Whether it also needs to be
  // queued for server-side deletion (pending_deletes) is decided by
  // the calling screen, based on whether the id is positive (already
  // known to the server) or negative (never made it to the server).
  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

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

  Future<List<Map<String, dynamic>>> getUnsyncedNotes() async {
    final db = await database;
    return await db.query('notes', where: 'synced = 0');
  }

  Future<void> markNoteSynced(int id) async {
    final db = await database;
    await db.update('notes', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceNoteId(int oldId, Map<String, dynamic> newData) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('notes', where: 'id = ?', whereArgs: [oldId]);
      await txn.insert('notes', newData);
    });
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

  Future<List<Map<String, dynamic>>> getUnsyncedObjectLocations() async {
    final db = await database;
    return await db.query('object_locations', where: 'synced = 0');
  }

  Future<void> markObjectLocationSynced(int id) async {
    final db = await database;
    await db.update('object_locations', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceObjectLocationId(int oldId, Map<String, dynamic> newData) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('object_locations', where: 'id = ?', whereArgs: [oldId]);
      await txn.insert('object_locations', newData);
    });
  }

  Future<int> deleteObjectLocation(int id) async {
    final db = await database;
    return await db.delete('object_locations', where: 'id = ?', whereArgs: [id]);
  }

  // ===================================================================
  // PENDING DELETES (offline retry queue for deletions)
  // ===================================================================

  Future<void> addPendingDelete(String tableName, int id) async {
    final db = await database;
    await db.insert(
      'pending_deletes',
      {'table_name': tableName, 'row_id': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<int>> getPendingDeletes(String tableName) async {
    final db = await database;
    final rows = await db.query(
      'pending_deletes',
      where: 'table_name = ?',
      whereArgs: [tableName],
    );
    return rows.map((r) => r['row_id'] as int).toList();
  }

  Future<void> removePendingDelete(String tableName, int id) async {
    final db = await database;
    await db.delete(
      'pending_deletes',
      where: 'table_name = ? AND row_id = ?',
      whereArgs: [tableName, id],
    );
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

  // ===================================================================
  // SYNC-DOWN functions
  //
  // These wipe the LOCAL table and rebuild it entirely from the
  // server's data, keeping the server's own "id" values. Used by
  // "Sync Now" AFTER any pending local changes have already been
  // pushed up (see cloud_sync_service.dart's syncNow()).
  // ===================================================================

  Future<void> replaceAllReminders(List<Map<String, dynamic>> serverReminders) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('reminders');
      for (final r in serverReminders) {
        await txn.insert('reminders', {
          'id': r['id'],
          'task': r['task'],
          'date': r['date'],
          'time': r['time'],
          'priority': r['priority'],
          'completed': r['completed'],
          'category': r['category'],
          'last_modified': r['last_modified'],
          'synced': 1,
        });
      }
    });
  }

  Future<void> replaceAllNotes(List<Map<String, dynamic>> serverNotes) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('notes');
      for (final n in serverNotes) {
        await txn.insert('notes', {
          'id': n['id'],
          'title': n['title'],
          'content': n['content'],
          'created_at': n['created_at'],
          'last_modified': n['last_modified'],
          'synced': 1,
        });
      }
    });
  }

  Future<void> replaceAllObjectLocations(List<Map<String, dynamic>> serverLocations) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('object_locations');
      for (final l in serverLocations) {
        await txn.insert('object_locations', {
          'id': l['id'],
          'object_name': l['object_name'],
          'location_name': l['location_name'],
          'latitude': l['latitude'],
          'longitude': l['longitude'],
          'last_modified': l['last_modified'],
          'synced': 1,
        });
      }
    });
  }

  // ===================================================================
  // CLEAR ALL LOCAL DATA
  //
  // The local database holds only ONE account's data at a time - there
  // is no per-user separation locally (reminders/notes/locations have
  // no user_id column). Without this, logging out and into a DIFFERENT
  // account would leave the previous account's cached data sitting in
  // these tables: it would flash on screen before the next sync, AND
  // (worse) any of the previous account's still-unsynced local edits
  // would get pushed to the NEW account's cloud data the next time
  // Sync Now runs.
  //
  // Called on logout (so nothing lingers after signing out) and right
  // before a fresh login's first sync-down (belt-and-braces, in case
  // the app was killed before a previous logout finished cleaning up).
  // ===================================================================
  Future<void> clearAllLocalData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('reminders');
      await txn.delete('notes');
      await txn.delete('object_locations');
      await txn.delete('pending_deletes');
      await txn.delete('context_logs');
    });
  }
}