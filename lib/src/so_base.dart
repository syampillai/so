import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:synchronized/synchronized.dart';

/// SO Platform Client.
class Client {
  /// Application name
  final String application;

  /// Device width
  final int deviceWidth;

  /// Device height
  final int deviceHeight;

  final WebSocketChannel _connection;
  final Lock _lock = Lock();
  String _username = "", _password = "", _session = "";
  final List<dynamic> _received = [];

  /// Constructor that takes the host name, [application] name, [deviceWidth] and [deviceHeight].
  /// The [secured] parameter determines whether the connection should use TLS encryption or not.
  Client(host, this.application,
      [this.deviceWidth = 1024, this.deviceHeight = 768, secured = true])
      : _connection = WebSocketChannel.connect(Uri.parse(
            "ws${secured ? 's' : ''}://$host/$application/CONNECTORWS")) {
    _connection.stream.listen((message) => _received.add(message));
  }

  /// Login. Requires username and password.
  ///
  /// Return value contains the error message. If logged in successfully, the return value will be an empty string.
  Future<String> login(String username, String password) async {
    if (_username != "") {
      return "Already logged in";
    }
    if (username == "") {
      return "Username can't be empty";
    }
    Map<String, dynamic> map = {
      "command": "login",
      "user": username,
      "password": password,
      "version": 1,
      "deviceWidth": deviceWidth,
      "deviceHeight": deviceHeight
    };
    _session = "";
    var r = await _post(map, false);
    if (r["status"] != "OK") {
      return r["message"] as String;
    }
    _session = r["session"] as String;
    _username = username;
    _password = password;
    return "";
  }

  /// Logout.
  ///
  /// The [Client] will not work any more once it is logged out.
  Future<void> logout() async {
    try {
      await command("logout", {});
      _connection.sink.close(status.goingAway);
    } finally {
      _session = _password = _username = "";
    }
  }

  /// Change the password to [newPassword].
  ///
  /// The return value contains the error message if any. An empty return value means that the password is changed successfully.
  Future<String> changePassword(String newPassword) async {
    var r = await command("changePassword",
        {"oldPassword": _password, "newPassword": newPassword});
    if (r["status"] == "OK") {
      return "";
    }
    return r["message"];
  }

  /// Send a command and get the response.
  ///
  /// The [attributes] should contain a map of the parameters. Please refer to the
  /// [SO Connector](https://github.com/syampillai/SOTraining/wiki/8900.-SO-Connector-API) documentation
  /// for parameter details. Please note that [command] is passed as the first parameter and thus, it need
  /// not be specified in the [attributes]. Also, "session" is not required because [Client] will
  /// automatically add that. If the optional [preserveServerState] value is true,
  /// the "continue" attribute will be set to preserve the server state
  /// (See [documentation](https://github.com/syampillai/SOTraining/wiki/8900.-SO-Connector-API#persisting-state-in-connector-logic)).
  ///
  /// The map that is returned will contain the result of the execution of the command.
  Future<Map<String, dynamic>> command(
      String command, Map<String, dynamic> attributes,
      [bool preserveServerState = false]) async {
    if (_username == "" || _session == "") {
      attributes["status"] = "ERROR";
      attributes["message"] = "Not logged in";
      return attributes;
    }
    attributes["command"] = command;
    if (preserveServerState) {
      attributes["continue"] = true;
    }
    var r = await _post(attributes);
    if (r["status"] == "LOGIN") {
      var u = _username;
      _username = "";
      var status = await login(u, _password);
      if (status != "") {
        attributes["status"] = "ERROR";
        attributes["message"] = "Can't re-login. Reason: $status";
        return attributes;
      }
    }
    r.remove("session");
    return r;
  }

  /// Retrieve stream of data for the [name].
  ///
  /// You should have got the [name] from a previous request.
  ///
  /// The return value is a record with 3 optional elements. If the
  /// data is retrieved successfully, the first will be the data,
  /// the second element will be the content-type and the third element will be
  /// null. Otherwise, the first 2 elements will be null and the third element
  /// will be the error description.
  Future<(Uint8List?, String?, String?)> stream(String name) async {
    return await _stream("stream", name);
  }

  /// Retrieve stream of data from a file with [name] (This could be the name
  /// of the file or Id of the file).
  ///
  /// The return value is a record with 3 optional elements. If the
  /// data is retrieved successfully, the first will be the data,
  /// the second element will be the content-type and the third element will be
  /// null. Otherwise, the first 2 elements will be null and the third element
  /// will be the error description.
  Future<(Uint8List?, String?, String?)> file(String name) async {
    return await _stream("file", name);
  }

  Future<(Uint8List?, String?, String?)> _stream(
      String command, String name) async {
    if (_username == "" || _session == "") {
      return (null, null, "Not logged in");
    }
    var r = await this.command(command, {"command": command, command: name});
    if (r['status'] == 'ERROR') {
      return (null, null, r['message'] as String);
    }
    return await _lock.synchronized(() async {
      return (await _receive() as Uint8List, r['type'] as String, null);
    });
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> map,
      [bool command = true]) async {
    if (command) {
      map["session"] = _session;
    }
    return await _lock.synchronized(() async {
      _connection.sink.add(jsonEncode(map));
      return jsonDecode(await _receive() as String) as Map<String, dynamic>;
    });
  }

  Future<dynamic> _receive() async {
    while (_received.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _received.removeAt(0);
  }
}
