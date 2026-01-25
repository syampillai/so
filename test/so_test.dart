import 'package:so/so.dart';
import 'package:test/test.dart';
import 'dart:io';

void main() {
  group("Tests", () {
    final String server = "sodev.saasvaap.com";
    final String application = "aerotrade";

    setUp(() {});

    test("Login", () async {
      final Client client = Client(server, application);
      final String username = "xxx";
      final String password = "secret";
      expect(await client.login(username, password), "");
      client.logout();
    });

    test("OTP Register", () async {
      final Client client = Client(server, application);
      final String email = "new_user@xxx.com";
      Map<String, dynamic> a = {};
      a["action"] = "otp";
      a["email"] = email;
      var r = await client.command("register", a);
      print("Message: ${r['message']}");
      expect(r["status"], "OK");
      stdout.write('Register with OTP ${r["prefixEmail"]} ');
      String? input = stdin.readLineSync();
      if (input != null) {
        a["action"] = "logic";
        a["emailOTP"] = int.parse(input);
        r = await client.command("register", a, true);
        print("Message: ${r['message']}");
        expect(r["status"], "OK");
      }
      client.logout();
    });

    test("OTP Login", () async {
      final Client client = Client(server, application);
      final String email = "xxx@yyy.com";
      var r = await client.otp(email);
      print("Message: ${r['message']}");
      expect(r["status"], "OK");
      stdout.write('Login with OTP ${r["prefixEmail"]} ');
      String? input = stdin.readLineSync();
      if (input != null) {
        int otp = int.parse(input);
        expect(await client.otpLogin(otp), "");
      }
      client.logout();
    });
  });
}
