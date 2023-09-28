import 'package:so/so.dart';

Future<void> main() async {
  Client client = Client("emqim12.engravsystems.com", "emqimtest");
  String status = await client.login("username", "password");
  if(status == "") {
    print("Logged in successfully");
  } else {
    print("Not logged in. Error: $status");
  }
}
