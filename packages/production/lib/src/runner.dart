import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_framework/http2.dart';
import 'package:args/args.dart';
import 'package:io/ansi.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart';
import 'package:belatuk_pub_sub/isolate.dart' as pub_sub;
import 'package:belatuk_pub_sub/belatuk_pub_sub.dart' as pub_sub;
import 'instance_info.dart';
import 'options.dart';

/// A command-line utility for easier running of multiple instances of an Angel application.
///
/// Makes it easy to do things like configure SSL, log messages, and send messages between
/// all running instances.
class Runner {
  final String name;
  final AngelConfigurer configureServer;
  final Reflector reflector;

  Runner(this.name, this.configureServer,
      {this.reflector = const EmptyReflector()});

  static const String asciiArt2 = '''

    ___    _   ________________   _____
   /   |  / | / / ____/ ____/ /  |__  /
  / /| | /  |/ / / __/ __/ / /    /_ < 
 / ___ |/ /|  / /_/ / /___/ /______/ / 
/_/  |_/_/ |_/\\____/_____/_____/____/ 
                                                                                                                       
''';

  static const String asciiArt = '''

     _    _   _  ____ _____ _     _____ 
    / \\  | \\ | |/ ___| ____| |   |___ / 
   / _ \\ |  \\| | |  _|  _| | |     |_ \\ 
  / ___ \\| |\\  | |_| | |___| |___ ___) |
 /_/   \\_\\_| \\_|\\____|_____|_____|____/                                                                                 
''';

  static const String asciiArtOld = '''
____________   ________________________ 
___    |__  | / /_  ____/__  ____/__  / 
__  /| |_   |/ /_  / __ __  __/  __  /  
_  ___ |  /|  / / /_/ / _  /___  _  /___
/_/  |_/_/ |_/  ____/  /_____/  /_____/
                                        
''';

  /// LogRecord handler
  static void handleLogRecord(LogRecord? record, RunnerOptions options) {
    if (options.quiet || record == null) return;
    var code = chooseLogColor(record.level);

    if (record.error == null) print(code.wrap(record.toString()));

    if (record.error != null) {
      var err = record.error;
      if (err is AngelHttpException && err.statusCode != 500) return;
      print(code.wrap(record.toString() + '\n'));
      print(code.wrap(err.toString()));

      if (record.stackTrace != null) {
        print(code.wrap(record.stackTrace.toString()));
      }
    }
  }

  /// Chooses a color based on the logger [level].
  static AnsiCode chooseLogColor(Level level) {
    if (level == Level.SHOUT) {
      return backgroundRed;
    } else if (level == Level.SEVERE) {
      return red;
    } else if (level == Level.WARNING) {
      return yellow;
    } else if (level == Level.INFO) {
      return cyan;
    } else if (level == Level.FINER || level == Level.FINEST) {
      return lightGray;
    }
    return resetAll;
  }

  /// Spawns a new instance of the application in a separate isolate.
  ///
  /// If the command-line arguments permit, then the instance will be respawned on crashes.
  ///
  /// The returned [Future] completes when the application instance exits.
  ///
  /// If respawning is enabled, the [Future] will *never* complete.
  Future spawnIsolate(int id, RunnerOptions options, SendPort pubSubSendPort) {
    return _spawnIsolate(id, Completer(), options, pubSubSendPort);
  }

  Future _spawnIsolate(
      int id, Completer c, RunnerOptions options, SendPort pubSubSendPort) {
    var onLogRecord = ReceivePort();
    var onExit = ReceivePort();
    var onError = ReceivePort();
    var runnerArgs = _RunnerArgs(name, configureServer, options, reflector,
        onLogRecord.sendPort, pubSubSendPort);
    var argsWithId = _RunnerArgsWithId(id, runnerArgs);

    Isolate.spawn(isolateMain, argsWithId,
            onExit: onExit.sendPort,
            onError: onError.sendPort,
            errorsAreFatal: true && false)
        .then((isolate) {})
        //.catchError(c.completeError);
        .catchError((e) {
      c.completeError(e as Object);
      return null;
    });

    onLogRecord.listen((msg) => handleLogRecord(msg as LogRecord?, options));

    onError.listen((msg) {
      if (msg is List) {
        dynamic e = msg[0];
        var st = StackTrace.fromString(msg[1].toString());
        handleLogRecord(
            LogRecord(
                Level.SEVERE, 'Fatal error', runnerArgs.loggerName, e, st),
            options);
      } else {
        handleLogRecord(
            LogRecord(Level.SEVERE, 'Fatal error', runnerArgs.loggerName, msg),
            options);
      }
    });

    onExit.listen((_) {
      if (options.respawn) {
        handleLogRecord(
            LogRecord(
                Level.WARNING,
                'Instance #$id at ${DateTime.now()} crashed. Respawning immediately...',
                runnerArgs.loggerName),
            options);
        _spawnIsolate(id, c, options, pubSubSendPort);
      } else {
        c.complete();
      }
    });

    return c.future
        .whenComplete(onExit.close)
        .whenComplete(onError.close)
        .whenComplete(onLogRecord.close);
  }

  /// Starts a number of isolates, running identical instances of an Angel application.
  Future run(List<String> args) async {
    pub_sub.Server? server;

    try {
      var argResults = RunnerOptions.argParser.parse(args);
      var options = RunnerOptions.fromArgResults(argResults);

      if (options.ssl || options.http2) {
        if (options.certificateFile == null) {
          throw ArgParserException('Missing --certificate-file option.');
        } else if (options.keyFile == null) {
          throw ArgParserException('Missing --key-file option.');
        }
      }

      print(darkGray.wrap(asciiArt +
          '\n\n' +
          'A batteries-included, full-featured, full-stack framework in Dart.' +
          '\n\n' +
          'https://angel3-framework.web.app\n'));

      if (argResults['help'] == true) {
        stdout
          ..writeln('Options:')
          ..writeln(RunnerOptions.argParser.usage);
        return;
      }

      print('Starting `$name` application...');

      var adapter = pub_sub.IsolateAdapter();
      server = pub_sub.Server([adapter]);

      // Register clients
      for (var i = 0; i < Platform.numberOfProcessors; i++) {
        server.registerClient(pub_sub.ClientInfo('client$i'));
      }

      server.start();

      await Future.wait(List.generate(options.concurrency,
          (id) => spawnIsolate(id, options, adapter.receivePort.sendPort)));
    } on ArgParserException catch (e) {
      stderr
        ..writeln(red.wrap(e.message))
        ..writeln()
        ..writeln(red.wrap('Options:'))
        ..writeln(red.wrap(RunnerOptions.argParser.usage));
      exitCode = ExitCode.usage.code;
    } catch (e, st) {
      stderr
        ..writeln(red.wrap('fatal error: $e'))
        ..writeln(red.wrap(st.toString()));
      exitCode = 1;
    } finally {
      await server?.close();
    }
  }

  /// Run with main isolate
  static void isolateMain(_RunnerArgsWithId argsWithId) {
    var args = argsWithId.args;
    hierarchicalLoggingEnabled = true;

    var zone = Zone.current.fork(specification: ZoneSpecification(
      print: (self, parent, zone, msg) {
        args.loggingSendPort.send(LogRecord(Level.INFO, msg, args.loggerName));
      },
    ));

    zone.run(() async {
      var client =
          pub_sub.IsolateClient('client${argsWithId.id}', args.pubSubSendPort);

      var app = Angel(reflector: args.reflector)
        ..container!.registerSingleton<pub_sub.Client>(client)
        ..container!.registerSingleton(InstanceInfo(id: argsWithId.id));

      app.shutdownHooks.add((_) => client.close());

      await app.configure(args.configureServer);

      app.logger ??= Logger(args.loggerName)
        ..onRecord.listen((rec) => Runner.handleLogRecord(rec, args.options));

      AngelHttp http;
      late SecurityContext securityContext;
      Uri serverUrl;

      if (args.options.ssl || args.options.http2) {
        securityContext = SecurityContext();
        if (args.options.certificateFile != null) {
          securityContext.useCertificateChain(args.options.certificateFile!,
              password: args.options.certificatePassword);
        }

        if (args.options.keyFile != null) {
          securityContext.usePrivateKey(args.options.keyFile!,
              password: args.options.keyPassword);
        }
      }

      if (args.options.ssl) {
        http = AngelHttp.custom(app, startSharedSecure(securityContext),
            useZone: args.options.useZone);
      } else {
        http =
            AngelHttp.custom(app, startShared, useZone: args.options.useZone);
      }

      Driver driver;

      if (args.options.http2) {
        securityContext.setAlpnProtocols(['h2'], true);
        var http2 = AngelHttp2.custom(app, securityContext, startSharedHttp2,
            useZone: args.options.useZone);
        http2.onHttp1.listen(http.handleRequest);
        driver = http2;
      } else {
        driver = http;
      }

      await driver.startServer(args.options.hostname, args.options.port);
      serverUrl = driver.uri;
      if (args.options.ssl || args.options.http2) {
        serverUrl = serverUrl.replace(scheme: 'https');
      }
      print('Instance #${argsWithId.id} listening at $serverUrl');
    });
  }
}

class _RunnerArgsWithId {
  final int id;
  final _RunnerArgs args;

  _RunnerArgsWithId(this.id, this.args);
}

class _RunnerArgs {
  final String name;

  final AngelConfigurer configureServer;

  final RunnerOptions options;

  final Reflector reflector;

  final SendPort loggingSendPort, pubSubSendPort;

  _RunnerArgs(this.name, this.configureServer, this.options, this.reflector,
      this.loggingSendPort, this.pubSubSendPort);

  String get loggerName => name;
}
