#!/bin/bash

rm pubspec.lock
flutter upgrade
flutter pub upgrade --major-versions

