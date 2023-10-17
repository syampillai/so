import 'package:so/so.dart';

Future<void> main() async {
  Client client = Client("emqim12.engravsystems.com", "emqimtest");
  String status = await client.login("syam", "Kayamkulam1@");
  if (status == "") {
    print("Logged in successfully");
    var (_, contentType, error) =
        await client.file("Weight Schedule - Approval Letter");
    if (error == null) {
      print("Mime type of the file retrieved is: $contentType");
    } else {
      print("Error retrieving file: $error");
    }
    Map<String, dynamic> attributes;
    print("List of persons whose first name starts with the letter N");
    attributes = {
      "className": "core.Person",
      "attributes": ["TitleValue AS Title", "FirstName", "DateOfBirth"],
      "where": "FirstName LIKE 'N%'",
    };
    printResult(await client.command("list", attributes));
    print("List of usernames whose first name starts with the letter N");
    attributes = {
      "className": "core.SystemUser",
      "attributes": [
        "Id",
        "Login",
        "Person.Name AS FN",
        "Person.DateOfBirth AS DoB",
        "Person.MaritalStatusValue AS MaritalStatus"
      ],
      "where": "Person.FirstName LIKE 'N%'",
      "order": "Person.FirstName"
    };
    printResult(await client.command("list", attributes));
    print(
        "A person whose name starts with N (Note: The fist person found is returned)");
    attributes = {
      "className": "core.Person",
      "where": "FirstName LIKE 'N%'",
    };
    printResult(await client.command("get", attributes));
  } else {
    print("Not logged in. Error: $status");
  }
  await client.logout();
}

void printResult(Map<String, dynamic> result) {
  switch (result) {
    case {'status': 'OK'}:
      print(result['data']);
    default:
      print("Error: ${result['message]']}");
  }
}
