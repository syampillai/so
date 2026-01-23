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

  /// API key
  final String apiKey;

  /// API version
  final int apiVersion = 1;

  final WebSocketChannel _connection;
  StreamSubscription<dynamic>? _subscription;
  final Lock _lock = Lock(), _lockBinary = Lock();
  String _username = "", _password = "", _session = "", _otpEmail = "";
  final List<String> _received = [];
  final List<Uint8List> _receivedBinary = [];

  /// Constructor that takes the host name, [application] name, [deviceWidth] and [deviceHeight].
  /// The [secured] parameter determines whether the connection should use TLS encryption or not.
  Client(
    String host,
    this.application, [
    this.deviceWidth = 1024,
    this.deviceHeight = 768,
    secured = true,
    this.apiKey = "",
  ]) : _connection = WebSocketChannel.connect(
         Uri.parse("ws${secured ? 's' : ''}://$host/$application/CONNECTORWS"),
         protocols: apiKey.isEmpty ? null : ['Bearer $apiKey'],
       ) {
    _subscription = _connection.stream.listen(
      (message) => message is String
          ? _received.add(message)
          : _receivedBinary.add(message),
    );
  }

  /// Get the current username.
  ///
  /// Returns current username.
  String get username => _username;

  /// Check if the [password] passed is the current password or not.
  ///
  /// Returns true if the current password matches with the [password] passed.
  bool checkPassword(String password) {
    return password == _password;
  }

  /// Login. Requires username, password is optional.
  ///
  /// Returns value contains the error message. If logged in successfully, the return value will be an empty string.
  Future<String> login(String username, [String password = '']) async {
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
      "version": apiVersion,
      "deviceWidth": deviceWidth,
      "deviceHeight": deviceHeight,
    };
    _session = "";
    var r = await _post(map);
    if (r["status"] != "OK") {
      return r["message"] as String;
    }
    _session = r["session"] as String;
    _username = username;
    _password = password;
    return "";
  }

  /// OTP-based login. OTPs must have been generated using [otp] before calling this method.
  ///
  /// Returns value contains the error message. If logged in successfully, the return value will be an empty string.
  Future<String> otpLogin(int emailOTP, [int mobileOTP = 0]) async {
    if (_username != "") {
      return "Already logged in";
    }
    if (_otpEmail == "" || _session == "") {
      return "OTP was not generated";
    }
    Map<String, dynamic> map = {
      "command": "otp",
      "action": "login",
      "continue": true,
      "session": _session,
      "emailOTP": emailOTP,
      "mobileOTP": mobileOTP,
      "version": apiVersion,
      "deviceWidth": deviceWidth,
      "deviceHeight": deviceHeight,
    };
    var r = await _post(map);
    if (r["status"] != "OK") {
      return r["message"] as String;
    }
    _session = r["session"] as String;
    _username = _otpEmail;
    _password = r["secret"];
    return "";
  }

  /// Command to initiate an OTP-based login. Server will generate OTPs and send
  /// them to the email address and/or mobile.
  ///
  /// The response should be checked for prefix values of the OTPs.
  Future<Map<String, dynamic>> otp(String email, [String mobile = '']) async {
    _otpEmail = email;
    Map<String, dynamic> map = {
      "action": "init",
      "email": email,
      "mobile": mobile,
    };
    return command("otp", map);
  }

  /// Logout.
  ///
  /// The [Client] will not work any more once it is logged out.
  Future<void> logout() async {
    try {
      await command("logout", {});
      _subscription?.cancel();
      _connection.sink.close(status.goingAway);
    } finally {
      _session = _password = _username = "";
    }
  }

  /// Change the [currentPassword] to [newPassword].
  ///
  /// The return value contains the error message if any. An empty return value means that the password is changed successfully.
  Future<String> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (!checkPassword(currentPassword)) {
      return "Current password is incorrect";
    }
    var r = await command("changePassword", {
      "oldPassword": _password,
      "newPassword": newPassword,
    });
    if (r["status"] == "OK") {
      _password = newPassword;
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
    String command,
    Map<String, dynamic> attributes, [
    bool preserveServerState = false,
  ]) async {
    return _command(command, attributes, true, preserveServerState);
  }

  Map<String, dynamic> _error(String error) {
    return {"status": "ERROR", "message": error};
  }

  Future<Map<String, dynamic>> _command(
    String command,
    Map<String, dynamic> attributes,
    bool checkCommand, [
    bool preserveServerState = false,
  ]) async {
    bool sessionRequired = true;
    if (command == "register" || command == "otp") {
      dynamic action = attributes["action"];
      if (action != null && (action is String)) {
        sessionRequired = action != "init";
        if (sessionRequired && (command == "register") && (action == "otp")) {
          sessionRequired = false;
        }
      }
    }
    if (sessionRequired && (_username == "" || _session == "")) {
      return _error("Not logged in");
    }
    if (checkCommand) {
      switch (command) {
        case "file":
        case "stream":
          return _error("Invalid command");
      }
    }
    if (sessionRequired) {
      attributes["session"] = _session;
    }
    attributes["command"] = command;
    if (preserveServerState) {
      attributes["continue"] = true;
    }
    var r = await _post(attributes);
    if (r["status"] == "LOGIN") {
      _session = r["session"];
      var u = _username;
      _username = "";
      var status = await login(u, _password);
      if (status != "") {
        return _error("Can't re-login. Reason: $status");
      }
      return await this.command(command, attributes, false);
    } else if (!sessionRequired) {
      _session = r["session"];
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

  /// Retrieve stream of data from a file with [name] (This could be the name
  /// of the file or Id of the file).
  ///
  /// The return value is a record with 3 optional elements. If the
  /// data is retrieved successfully, the first will be the data,
  /// the second element will be the content-type and the third element will be
  /// null. Otherwise, the first 2 elements will be null and the third element
  /// will be the error description.
  Future<(Uint8List?, String?, String?)> report(
    String logic, [
    Map<String, dynamic>? parameters,
  ]) async {
    Map<String, dynamic>? m;
    if (parameters != null) {
      dynamic p = parameters["parameters"];
      if (p != null && p is Map<String, dynamic>) {
        m = parameters;
      } else {
        m = {"parameters": parameters};
      }
    }
    return await _stream("report", logic, m);
  }

  Future<(Uint8List?, String?, String?)> _stream(
    String command,
    String name, [
    Map<String, dynamic>? parameters,
  ]) async {
    parameters ??= {};
    parameters[command] = name;
    var r = await _command(command, parameters, false, false);
    if (r['status'] == 'ERROR') {
      return (null, null, r['message'] as String);
    }
    return await _lockBinary.synchronized(
      () async => (await _receiveBinary(), r['type'] as String, null),
    );
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> map) async {
    return await _lock.synchronized(() async {
      _connection.sink.add(jsonEncode(map));
      return jsonDecode(await _receive()) as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> _postBinary(Uint8List data) async {
    return await _lock.synchronized(() async {
      _connection.sink.add(data);
      return jsonDecode(await _receive()) as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> _postBinaryStream(Stream<Uint8List> data) async {
    return await _lock.synchronized(() async {
      _connection.sink.addStream(data);
      return jsonDecode(await _receive()) as Map<String, dynamic>;
    });
  }

  Future<String> _receive() async {
    while (_received.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _received.removeAt(0);
  }

  Future<Uint8List> _receiveBinary() async {
    while (_receivedBinary.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _receivedBinary.removeAt(0);
  }

  /// Upload some binary [data] to the server. [mimeType] of the content should be correctly specified
  /// and it will not be verified at the server.
  ///
  /// If the return value contains key ("status": "OK"), look for the value for the key "id". That will
  /// contain the ID of the server content. The [streamNameOrID] may be used to specify that
  /// you want to overwrite some existing content. It could be specified as a name or as an Id value.
  Future<Map<String, dynamic>> upload(
    String mimeType,
    Uint8List data, [
    String streamNameOrID = '',
  ]) async {
    Map<String, dynamic>? map = await _upload(mimeType, streamNameOrID);
    map ??= await _postBinary(data);
    map.remove('session');
    return map;
  }

  /// Upload a stream of binary [data] to the server. [mimeType] of the content should be correctly specified
  /// and it will not be verified at the server.
  ///
  /// If the return value contains key ("status": "OK"), look for the value for the key "id". That will
  /// contain the ID of the server content. The [streamNameOrID] may be used to specify that
  /// you want to overwrite some existing content. It could be specified as a name or as an Id value.
  Future<Map<String, dynamic>> uploadStream(
    String mimeType,
    Stream<Uint8List> data, [
    String streamNameOrID = '',
  ]) async {
    Map<String, dynamic>? map = await _upload(mimeType, streamNameOrID);
    map ??= await _postBinaryStream(data);
    map.remove('session');
    return map;
  }

  Future<Map<String, dynamic>?> _upload(
    String mimeType, [
    String streamNameOrID = '',
  ]) async {
    Map<String, dynamic> map = {
      'type': mimeType,
      if (streamNameOrID != '') 'stream': streamNameOrID,
    };
    map = await command('upload', map);
    return map['status'] == 'OK' ? null : map;
  }
}
