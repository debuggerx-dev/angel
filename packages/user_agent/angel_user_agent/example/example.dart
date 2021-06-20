import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';
//import 'package:angel_user_agent/angel_user_agent.dart';
//import 'package:user_agent/user_agent.dart';

void main() async {
  var app = Angel();
  var http = AngelHttp(app);

  // TODO: Commented out due to unknow class
  /*
  app.get(
    '/',
    waterfall([
      parseUserAgent,
      (req, res) {
        var ua = req.container.make<UserAgent>();
        return ua.isChrome
            ? 'Woohoo! You are running Chrome.'
            : 'Sorry, we only support Google Chrome.';
      },
    ]),
  );
  */

  var server = await http.startServer(InternetAddress.anyIPv4, 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
