import 'package:so/so.dart';

Future<void> main() async {
  Client client;
  client = Client("emqim12.engravsystems.com", "emqimtest");
  String status;
  status = await client.login("username", "password");
  if (status == "") {
    print("Logged in successfully");
    var (_, contentType, error) =
        await client.report("com.storedobject.report.ObjectList", {
      "className": "core.Person",
      "attributes": ["FirstName", "LastName", "DateOfBirth", "Age"],
    });
    if (error == null) {
      print("Mime type of the report content is: $contentType");
    } else {
      print(error);
    }
    (_, contentType, error) =
        await client.file("Weight Schedule - Approval Letter");
    if (error == null) {
      print("Mime type of the file retrieved is: $contentType");
    } else {
      print("Error retrieving file: $error");
    }
    (_, contentType, error) = await client
        .report("com.engravsystems.emqim.operations.logic.TestReport");
    if (error == null) {
      print("Mime type of the report is: $contentType");
    } else {
      print("Error running report: $error");
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
        "A person whose name starts with H (Note: The first person found is returned)");
    attributes = {
      "className": "core.Person",
      "where": "FirstName LIKE 'H%'",
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
      var data = result['data'];
      print(data ?? result);
    default:
      print("Error: ${result['message']}");
  }
}
