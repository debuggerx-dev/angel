import 'dart:isolate';
import 'package:http/http.dart' as http;

Future<void> fortunes(var message) async {
  var stopwatch = Stopwatch()..start();

  var url = Uri.http('localhost:3000', '/fortunes');
  var response = await http.get(url);
  print('Execution($message) Time: ${stopwatch.elapsed.inMilliseconds}ms');
  stopwatch.stop();

  if (response.statusCode == 200) {
    print('Execution($message): success');
  } else {
    print('Execution($message): error');
  }
}

Future<void> plaintext(var message) async {
  var stopwatch = Stopwatch()..start();

  var url = Uri.http('localhost:3000', '/plaintext');
  var response = await http.get(url);
  if (response.statusCode == 200) {
    print('Execution($message): success');
  } else {
    print('Execution($message): error');
  }

  print('Execution($message) Time: ${stopwatch.elapsed.inMilliseconds}ms');
  stopwatch.stop();
}

Future<void> json(var message) async {
  var stopwatch = Stopwatch()..start();

  var url = Uri.http('localhost:3000', '/json');
  var response = await http.get(url);
  print('Execution($message) Time: ${stopwatch.elapsed.inMilliseconds}ms');
  stopwatch.stop();

  if (response.statusCode == 200) {
    print('Execution($message): success');
  } else {
    print('Execution($message): error');
  }
}

Future<void> dbUpdate(var message) async {
  var stopwatch = Stopwatch()..start();

  var url = Uri.http('localhost:3000', '/updates', {'queries': "5"});
  var response = await http.get(url);
  print('Execution($message) Time: ${stopwatch.elapsed.inMilliseconds}ms');
  stopwatch.stop();

  if (response.statusCode == 200) {
    print('Execution($message): success');
  } else {
    print('Execution($message): error');
  }
}

Future<void> dbSingleQuery(var message) async {
  var stopwatch = Stopwatch()..start();

  var url = Uri.http('localhost:3000', '/db');
  var response = await http.get(url);
  print('Execution($message) Time: ${stopwatch.elapsed.inMilliseconds}ms');
  stopwatch.stop();

  if (response.statusCode == 200) {
    print('Execution($message): success');
  } else {
    print('Execution($message): error');
  }
}

Future<void> dbMultipleQuery(var message) async {
  var stopwatch = Stopwatch()..start();

  var url = Uri.http('localhost:3000', '/query', {'queries': "5"});
  var response = await http.get(url);
  print('Execution($message) Time: ${stopwatch.elapsed.inMilliseconds}ms');
  stopwatch.stop();

  if (response.statusCode == 200) {
    print('Execution($message): success');
  } else {
    print('Execution($message): error');
  }
}

void main() async {
  var concurrency = 100;

  for (var i = 0; i < concurrency; i++) {
    Isolate.spawn(dbUpdate, 'Instance_$i');
  }

  await Future.delayed(const Duration(seconds: 10));

  //print("Exit");
}
