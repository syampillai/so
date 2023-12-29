## Dart client for SO Platform.  
  
SO platform is an object-oriented framework for developing enterprise Java applications with a PostgreSQL database
back-end. Developers typically write "data classes" (classes that represent tables in the database) and
"logic classes" (classes implementing web UI, reporting and processing logic). All such developer-defined classes are
stored in the database itself like any other business data. Logic classes can be attached to "menu options" of the
application and the logic executes when the menu option is selected by the end-user.  

## Features

This library can be used to connect to SO platform from dart (and flutter) applications. Typically,
it is used by mobile application developers to create customized mobile front-ends for the SO platform.
## Getting started

You may import this library to your dart application with the following command (in your project folder):

```shell
dart pub add so
dart pub get
```

If you want to use it with flutter:
```shell
flutter pub add so
flutter pub get
```

## Usage

```dart
import 'package:so/so.dart';

Future<void> main() async {
  Client client = Client("host", "application");
  String status = await client.login("username", "password");
  if(status == "") {
    print("Logged in successfully");
  } else {
    print("Not logged in. Error: $status");
  }
}
```
## Additional information

SO platform wiki pages are available at [SO Platform Wiki](https://github.com/syampillai/SOTraining/wiki).
You may read the [SO Connector API](https://github.com/syampillai/SOTraining/wiki/8900.-SO-Connector-API)
documentation to understand how you can communicate and exchange data with SO platform from your programs.

If you are looking for a Java client library, please [see here](https://github.com/syampillai/SOClient).