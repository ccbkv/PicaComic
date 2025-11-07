import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import '../foundation/app.dart';

class HttpProxyRequest {
  String host;
  int port;

  var sni = <String>[];

  final void Function() stop;

  HttpProxyRequest(this.host, this.port, this.stop);
}

class _HttpProxyHandler {
  var content = "";
  late Socket client;
  Socket? serverSocket;

  void handle(
      Socket c, void Function(HttpProxyRequest request) onRequest) async {
    try {
      client = c;
      await for (var d in client) {
        if (serverSocket == null) {
          content += const Utf8Decoder().convert(d);
          if (content.contains("\n")) {
            if (content.split(" ").first != "CONNECT") {
              client
                  .write("HTTP/1.1 400 Bad Request\nContent-Type: text/plain\n"
                  "Content-Length: 29\n\nBad Request: Invalid Request");
              client.flush();
              client.close();
              return;
            }
            var uri = content
                .split('\n')
                .first
                .split(" ")
                .firstWhere((element) => element.contains(":"));
            bool stop = false;
            var request = HttpProxyRequest(
                uri.split(":").first, int.parse(uri.split(":").last), () {
              stop = true;
            });
            onRequest(request);
            if (stop) {
              client.close();
              return;
            }
            forward(request.host, request.port);
          }
        }
        if (serverSocket != null) {
          serverSocket!.add(d);
        }
      }
      close();
    } catch (e) {
      close();
    }
  }

  void close() {
    try {
      client.close();
      serverSocket?.close();
    } catch (e) {
      //
    }
  }

  void forward(String host, int port) async {
    try {
      serverSocket = await Socket.connect(host, port);
      serverSocket?.listen((event) {
        client.add(event);
      }, onDone: () {
        client.close();
        serverSocket = null;
      }, onError: (e) {
        client.close();
        serverSocket = null;
      }, cancelOnError: true);
      client.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      client.flush();
    } catch (e) {
      close();
    }
  }
}

typedef RequestHandler = void Function(HttpProxyRequest request);

class HttpProxyServer {
  HttpProxyServer(this.handler, this.port);

  final RequestHandler handler;

  final int port;

  ServerSocket? socket;

  void run() {
    runZonedGuarded(() async{
      socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      socket?.listen((event) => _HttpProxyHandler().handle(event, handler));
    }, (error, stack) async{
      print(error);
      print(stack);
    });
  }

  void close(){
    socket?.close();
  }

  static Isolate? _server;

  static void startServer() async{
    _server?.kill();
    _server = await Isolate.spawn<String>((message) {
      final file = File("$message/rule.json");
      var json = const JsonDecoder().convert(file.readAsStringSync());
      var server = HttpProxyServer((request) {
        final file = File("$message/rule.json");
        final json = const JsonDecoder().convert(file.readAsStringSync());
        if (json["rule"][request.host] != null) {
          request.host = json["rule"][request.host];
        }
      }, json["port"]);
      server.run();
    }, App.dataPath);
  }

  static void reload(){
    startServer();
  }

  static void createConfigFile(){
    var file = File("${App.dataPath}/rule.json");
    if(!file.existsSync()){
      var rule = {
    "port": 7891,
    "rule": {
        "picaapi.picacomic.com": "104.20.42.9",
        "img.picacomic.com": "104.20.42.9",
        "storage1.picacomic.com": "104.20.42.9",
        "storage-b.picacomic.com": "104.20.42.9",
        "e-hentai.org": "172.67.2.238",
        "exhentai.org": "178.175.129.251",
        "s.exhentai.org": "89.39.106.43",
        "api.e-hentai.org": "5.79.104.110",
        "forums.e-hentai.org": "94.100.18.243",
        "ehgt.org": "89.39.106.43",
        "www.wnacg.com": "104.26.12.109",
        "nhentai.net": "104.26.4.188",
        "i1.nhentai.net": "77.247.178.1",
        "i2.nhentai.net": "77.247.178.1",
        "i3.nhentai.net": "77.247.178.1",
        "i4.nhentai.net": "77.247.178.1",
        "i9.nhentai.net": "77.247.178.1",
        "t1.nhentai.net": "77.247.178.1",
        "t2.nhentai.net": "77.247.178.1",
        "t3.nhentai.net": "77.247.178.1",
        "t4.nhentai.net": "77.247.178.1",
        "t9.nhentai.net": "77.247.178.1",
        "t4.qy0.ru": "104.20.44.182",
        "hitomi.la": "198.251.80.166",
        "ltn.gold-usergeneratedcontent.net": "216.230.225.130",
        "atn.gold-usergeneratedcontent.net": "216.230.225.130",
        "btn.gold-usergeneratedcontent.net": "66.187.78.242",
        "tn.gold-usergeneratedcontent.net":  "66.187.18.242",
        "w1.gold-usergeneratedcontent.net": "a1.gold-usergeneratedcontent.net",
        "w2.gold-usergeneratedcontent.net": "a2.gold-usergeneratedcontent.net"
    },
    "sni": [
        "e-hentai.org",
        "exhentai.org",
        "s.exhentai.org",
        "api.e-hentai.org",
        "forums.e-hentai.org",
        "ehgt.org"
    ]
      };
      var spaces = ' ' * 4;
      var encoder = JsonEncoder.withIndent(spaces);
      file.writeAsStringSync(encoder.convert(rule));
    }
  }
}