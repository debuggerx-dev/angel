import 'dart:async';
import 'dart:collection';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';
import '../runner.dart';
import '../util.dart';
import 'schema.dart';

class MysqlMigrationRunner implements MigrationRunner {
  final _log = Logger('PostgresMigrationRunner');

  final Map<String, Migration> migrations = {};
  final ConnectionSettings settings;
  final Queue<Migration> _migrationQueue = Queue();
  late MySqlConnection connection;
  bool _connected = false;

  MysqlMigrationRunner(this.settings,
      {Iterable<Migration> migrations = const [], bool connected = false}) {
    if (migrations.isNotEmpty == true) migrations.forEach(addMigration);
    _connected = connected == true;
  }

  @override
  void addMigration(Migration migration) {
    _migrationQueue.addLast(migration);
  }

  Future _init() async {
    while (_migrationQueue.isNotEmpty) {
      var migration = _migrationQueue.removeFirst();
      var path = await absoluteSourcePath(migration.runtimeType);
      migrations.putIfAbsent(path.replaceAll('\\', '\\\\'), () => migration);
    }

    if (!_connected) {
      connection = await MySqlConnection.connect(settings);
      _connected = true;
    }

    await connection.query('''
    CREATE TABLE IF NOT EXISTS "migrations" (
      id serial,
      batch integer,
      path varchar,
      PRIMARY KEY(id)
    );
    ''').then((result) {
      _log.info('Check and create "migrations" table');
    }).catchError((e) {
      _log.severe('Failed to create "migrations" table.');
    });
  }

  @override
  Future up() async {
    await _init();
    var r = await connection.query('SELECT path from migrations;');
    var existing = r.expand((x) => x).cast<String>();
    var toRun = <String>[];

    migrations.forEach((k, v) {
      if (!existing.contains(k)) toRun.add(k);
    });

    if (toRun.isNotEmpty) {
      var r = await connection.query('SELECT MAX(batch) from migrations;');
      var rTmp = r.toList();
      var curBatch = (rTmp[0][0] ?? 0) as int;
      var batch = curBatch + 1;

      for (var k in toRun) {
        var migration = migrations[k]!;
        var schema = MysqlSchema();
        migration.up(schema);
        _log.info('Added "$k" into "migrations" table.');
        await schema.run(connection).then((_) {
          return connection.transaction((ctx) async {
            var result = await ctx.query(
                "INSERT INTO MIGRATIONS (batch, path) VALUES ($batch, '$k')");

            return result.affectedRowCount;
          });
          //return connection.execute(
          //    'INSERT INTO MIGRATIONS (batch, path) VALUES ($batch, \'$k\');');
        }).catchError((e) {
          _log.severe('Failed to insert into "migrations" table.');
        });
      }
    } else {
      _log.warning('Nothing to add into "migrations" table.');
    }
  }

  @override
  Future rollback() async {
    await _init();

    var r = await connection.query('SELECT MAX(batch) from migrations;');
    var rTmp = r.toList();
    var curBatch = (rTmp[0][0] ?? 0) as int;

    r = await connection
        .query('SELECT path from migrations WHERE batch = $curBatch;');
    var existing = r.expand((x) => x).cast<String>();
    var toRun = <String>[];

    migrations.forEach((k, v) {
      if (existing.contains(k)) toRun.add(k);
    });

    if (toRun.isNotEmpty) {
      for (var k in toRun.reversed) {
        var migration = migrations[k]!;
        var schema = MysqlSchema();
        migration.down(schema);
        _log.info('Removed "$k" from "migrations" table.');
        await schema.run(connection).then((_) {
          return connection
              .query('DELETE FROM migrations WHERE path = \'$k\';');
        });
      }
    } else {
      _log.warning('Nothing to remove from "migrations" table.');
    }
  }

  @override
  Future reset() async {
    await _init();
    var r = await connection
        .query('SELECT path from migrations ORDER BY batch DESC;');
    var existing = r.expand((x) => x).cast<String>();
    var toRun = existing.where(migrations.containsKey).toList();

    if (toRun.isNotEmpty) {
      for (var k in toRun.reversed) {
        var migration = migrations[k]!;
        var schema = MysqlSchema();
        migration.down(schema);
        _log.info('Removed "$k" from "migrations" table.');
        await schema.run(connection).then((_) {
          return connection
              .query('DELETE FROM migrations WHERE path = \'$k\';');
        });
      }
    } else {
      _log.warning('Nothing to remove from "migrations" table.');
    }
  }

  @override
  Future close() {
    return connection.close();
  }
}
