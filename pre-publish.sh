#!/bin/bash

dart analyze lib/*
dart format .
dart pub publish --dry-run

