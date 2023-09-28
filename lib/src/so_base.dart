import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// SO Platform Client.
class Client {

  /// Application name
  final String application;

  /// Device width
  final int deviceWidth;

  /// Device height
  final int deviceHeight;

  final Uri _uri;
  final Map<String, String> _headers = {
    "Content-Type": "application/json",
    "charset": "utf-8",
  };
  final RetryClient _connection = RetryClient(http.Client());
  String _username = "",
      _password = "",
      _session = "",
      _cookie = "";

  /// Constructor that takes the host name, [application] name, [deviceWidth] and [deviceHeight].
  Client(host, this.application, [this.deviceWidth = 1024, this.deviceHeight = 768])
      : _uri = Uri.https(host, "$application/CONNECTOR");

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
    } finally {
      _session = _password = _username = _cookie = "";
      _headers.remove("cookie");
    }
  }

  /// Change the password to [newPassword].
  ///
  /// The return value contains the error message if any. An empty return value means that the password is changed successfully.
  Future<String> changePassword(String newPassword) async {
    var r = await command("changePassword",
        { "oldPassword": _password, "newPassword": newPassword});
    if (r["status"] == "OK") {
      return "";
    }
    return r["message"];
  }

  /// Send a command and get the response.
  ///
  /// The [attributes] should contain a map of the parameters. Please refer to the
  /// [SO Connector]https://github.com/syampillai/SOTraining/wiki/8900.-SO-Connector-API documentation
  /// for parameter details. Please note that [command] is passed as the first parameter and thus, it need
  /// not be specified in the [attributes]. Also, "session" is not required because [Client] will
  /// automatically add that. If the optional [preserveServerState] value is true,
  /// the "continue" attribute will be set to preserve the server state
  /// (See [documentation](https://github.com/syampillai/SOTraining/wiki/8900.-SO-Connector-API#persisting-state-in-connector-logic)).
  ///
  /// The map that is returned will contain the result of the execution of the command.
  Future<Map<String, dynamic>> command(String command, Map<String, dynamic> attributes, [bool preserveServerState = false]) async {
    if (_username == "" || _session == "") {
      attributes["status"] = "ERROR";
      attributes["message"] = "Not logged in";
      return attributes;
    }
    attributes["command"] = command;
    if(preserveServerState) {
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
  Future<Data> stream(String name) async {
    return await _stream("stream", name);
  }

  /// Retrieve stream of data from a file with [name] (This could be the name
  /// of the file or Id of the file).
  Future<Data> file(String name) async {
    return await _stream("file", name);
  }

  Future<Data> _stream(String command, String name) async {
    if (_username == "" || _session == "") {
      return Data.empty("Not logged in");
    }
    var r = await _postR({ "command": command, command: name }, true);
    String ct = r.headers["content-type"] as String;
    int i = ct.indexOf(";");
    if(i >= 0) {
      ct = ct.substring(0, i);
    }
    if(ct == "application/json") {
      Map<String, dynamic> map = jsonDecode(utf8.decode(r.bodyBytes));
      switch(map['status']) {
        case 'ERROR': return Data.empty(map['message']);
        case 'LOGIN': return Data.empty('Not logged in');
      }
    }
    return Data(ct, r.bodyBytes);
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> map, [bool command = true]) async {
    var response = await _postR(map, command);
    if(_cookie == "") {
      var c = response.headers["set-cookie"];
      if(c != Null) {
        _cookie = c as String;
      }
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<http.Response> _postR(Map<String, dynamic> map, bool command) async {
    if (command) {
      map["session"] = _session;
    }
    if(_cookie != "") {
      _headers["cookie"] = _cookie;
    }
    return await _connection.post(_uri,
      headers: _headers,
      body: jsonEncode(map),
    );
  }
}

/// Representation of some sort of content.
class Data {

  /// Mime type of the content.
  final String contentType;

  /// Data.
  final Uint8List data;

  // Error (for valid data, it will be empty).
  final String error;

  /// Constructor.
  Data(this.contentType, this.data) : error = '';

  /// Constructor for creating empty data.
  Data.empty(this.error) : contentType = "", data = Uint8List(0);
}
