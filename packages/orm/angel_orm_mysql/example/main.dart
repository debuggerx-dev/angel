import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_model/angel3_model.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:logging/logging.dart';
import 'package:galileo_sqljocky5/sqljocky.dart';
import 'package:optional/optional.dart';
part 'main.g.dart';

void main() async {
  hierarchicalLoggingEnabled = true;
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(print);

  var settings = ConnectionSettings(
      db: 'angel_orm_test', user: 'angel_orm_test', password: 'angel_orm_test');
  var connection = await MySqlConnection.connect(settings);
  var logger = Logger('angel_orm_mysql');
  var executor = MySqlExecutor(connection, logger: logger);

  var query = TodoQuery();
  query.values
    ..text = 'Clean your room!'
    ..isComplete = false;

  var todo = await query.insert(executor);
  print(todo.value.toJson());

  var query2 = TodoQuery()..where!.id.equals(todo.value.idAsInt);
  var todo2 = await query2.getOne(executor);
  print(todo2.value.toJson());
  print(todo == todo2);
}

@serializable
@orm
abstract class _Todo extends Model {
  String? get text;

  @DefaultsTo(false)
  bool? isComplete;
}
