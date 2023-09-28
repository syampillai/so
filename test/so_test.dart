import 'package:so/so.dart';
import 'package:test/test.dart';

void main() {
  group("Tests", () {
    final Client client = Client("emqim12.engravsystems.com", "emqimtest");
    final String username = "mylogin";
    final String password = "mysecret";

    setUp(() {});

    test("Login", () async {
      expect(await client.login(username, password), "");
    });
  });
}
