import 'package:so/so.dart';

Future<void> main() async {
  Client client = Client("emqim12.engravsystems.com", "emqimtest");
  String status = await client.login("username", "password");
  if(status == "") {
    print("Logged in successfully");
    Data d = await client.file("ENGRAV Air - Operation Manual");
    if(d.error == '') {
      print("Mime type of the file retrieved is: ${d.contentType}");
    } else {
      print("Error retrieving file: ${d.error}");
    }
  } else {
    print("Not logged in. Error: $status");
  }
  await client.logout();
}
