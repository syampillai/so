<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages). 
-->

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
