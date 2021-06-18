import 'dart:async';
import 'package:angel_migration/angel_migration.dart';
import 'package:postgres/postgres.dart';
import 'package:angel_migration_runner/src/postgres/table.dart';

class PostgresSchema extends Schema {
  final int _indent;
  final StringBuffer _buf;

  PostgresSchema._(this._buf, this._indent);

  factory PostgresSchema() => PostgresSchema._(StringBuffer(), 0);

  Future run(PostgreSQLConnection connection) => connection.execute(compile());

  String compile() => _buf.toString();

  void _writeln(String str) {
    for (var i = 0; i < _indent; i++) {
      _buf.write('  ');
    }

    _buf.writeln(str);
  }

  @override
  void drop(String tableName, {bool cascade = false}) {
    var c = cascade == true ? ' CASCADE' : '';
    _writeln('DROP TABLE "$tableName"$c;');
  }

  @override
  void alter(String tableName, void Function(MutableTable table) callback) {
    var tbl = PostgresAlterTable(tableName);
    callback(tbl);
    _writeln('ALTER TABLE "$tableName"');
    tbl.compile(_buf, _indent + 1);
    _buf.write(';');
  }

  void _create(
      String tableName, void Function(Table table) callback, bool ifNotExists) {
    var op = ifNotExists ? ' IF NOT EXISTS' : '';
    var tbl = PostgresTable();
    callback(tbl);
    _writeln('CREATE TABLE$op "$tableName" (');
    tbl.compile(_buf, _indent + 1);
    _buf.writeln();
    _writeln(');');
  }

  @override
  void create(String tableName, void Function(Table table) callback) =>
      _create(tableName, callback, false);

  @override
  void createIfNotExists(
          String tableName, void Function(Table table) callback) =>
      _create(tableName, callback, true);
}
