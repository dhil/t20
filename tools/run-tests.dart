// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:ansicolor/ansicolor.dart' show AnsiPen;

import 'package:args/args.dart' show ArgParser, ArgResults;

import 'package:path/path.dart' as path;

ArgParser argParser = new ArgParser()..addFlag("measure", defaultsTo: false);

const String tick = "✔";

const String cross = "✘";

const String minus = "÷";

final AnsiPen boldPen = new AnsiPen()..black(bold: true);

final AnsiPen redPen = new AnsiPen()..red(bold: true);

final AnsiPen yellowPen = new AnsiPen()..yellow(bold: true);

final AnsiPen greenPen = new AnsiPen()..green(bold: true);

String readFirstLine(String filename) {
  File f = File(filename);
  if (!f.existsSync()) return null;
  return f.readAsLinesSync().first;
}

class Tester {
  final String t20 = "./t20";

  final String testsDir;

  final String flagsFilename;

  final bool measure;

  int successes = 0;

  int failures = 0;

  int skipped = 0;

  Duration accumulator = Duration.zero;

  Tester(this.testsDir, this.flagsFilename, this.measure);

  void runtests(String dir, String subdir, int expectation) {
    String flags = readFirstLine(path.join(dir, subdir, flagsFilename));

    stdout.writeln(boldPen("== Running tests in $dir/$subdir =="));

    Directory testcasesDir = new Directory(path.join(dir, subdir));
    if (!testcasesDir.existsSync()) return;
    for (FileSystemEntity entity in testcasesDir.listSync()) {
      if (entity is File && entity.path.endsWith(".t20")) {
        String entityRelativePath =
            path.join(dir, subdir, path.basename(entity.path));
        if (entity.readAsStringSync().contains(";; SKIP")) {
          stdout.writeln("${yellowPen(minus)} ${entityRelativePath}");
          ++skipped;
        } else {
          runtest(flags, entityRelativePath, expectation);
        }
      }
    }
  }

  void runtest(String flags, String relativePath, int expectation) {
    DateTime startTime;
    DateTime endTime;
    String elapsed_str = "";

    String cmd = "$t20 $flags $relativePath";
    if (measure) {
      startTime = new DateTime.now();
    }

    ProcessResult processResult =
        Process.runSync(t20, flags.split(" ")..add(relativePath));

    if (measure) {
      endTime = new DateTime.now();
      Duration elapsed = endTime.difference(startTime);
      String elapsed_fmt = "${elapsed.inMilliseconds / 1000}";
      elapsed_str = "[${elapsed_fmt}s]";
      accumulator += elapsed;
    }

    if (processResult.exitCode == expectation) {
      stdout.writeln("${greenPen(tick)} ${elapsed_str}$relativePath");
      ++successes;
    } else {
      ++failures;
      stdout.writeln("${redPen(cross)} ${elapsed_str}$relativePath");
      stdout.writeln("command: $cmd");
      stdout.writeln("exit code: ${processResult.exitCode}");
      stdout.write("stdout:");
      if (processResult.stdout.isEmpty) {
        stdout.writeln(" (empty)");
      } else {
        stdout.writeln();
        for (String line in processResult.stdout.split("\n")) {
          stdout.writeln("    $line");
        }
      }
      stdout.write("stderr:");
      if (processResult.stderr.isEmpty) {
        stdout.writeln(" (empty)");
      } else {
        stdout.writeln();
        for (String line in processResult.stdout.split("\n")) {
          stdout.writeln("    $line");
        }
      }
    }
  }
}

main(List<String> args) {
  ArgResults argResults = argParser.parse(args);
  bool measure = argResults["measure"];

  DateTime startTime;
  String testName = "";
  String flagsFile = ".flags";
  String testsDir = "tests";
  Tester tester = new Tester(testsDir, flagsFile, measure);

  if (measure) {
    startTime = new DateTime.now();
  }

  if (argResults.rest.isNotEmpty) {
    String candidateTestName = argResults.rest[0];
    if (FileSystemEntity.typeSync(candidateTestName) !=
        FileSystemEntityType.notFound) {
      testName = candidateTestName;
    }
  }

  if (FileSystemEntity.typeSync(testName) == FileSystemEntityType.directory) {
    if (FileSystemEntity.typeSync(path.join(testName, "pass")) ==
        FileSystemEntityType.directory) {
      tester.runtests(testName, "pass", 0);
    } else if (path.basename(testName) == "pass") {
      tester.runtests(testName, "", 0);
    }
  } else if (FileSystemEntity.typeSync(testName) == FileSystemEntityType.file) {
    String directory = path.dirname(testName);
    String expectation = path.basename(directory);
    if (expectation == "pass") {
      String flagsFilename = path.join(path.dirname(testName), flagsFile);
      if (FileSystemEntity.typeSync(flagsFilename) ==
          FileSystemEntityType.file) {
        String flags = readFirstLine(flagsFilename);
        tester.runtest(flags, testName, 0);
      } else {
        tester.runtest("", testName, 0);
      }
    } else if (expectation == "fail") {
      String flagsFilename = path.join(path.dirname(testName), flagsFile);
      if (FileSystemEntity.typeSync(flagsFilename) ==
          FileSystemEntityType.file) {
        String flags = readFirstLine(flagsFilename);
        tester.runtest(flags, testName, 10);
      } else {
        tester.runtest("", testName, 10);
      }
    } else {
      stdout.writeln("Cannot run test script without an expectation.");
    }
  } else {
    if (FileSystemEntity.typeSync(testsDir) == FileSystemEntityType.directory) {
      Directory testsDirectory = new Directory(testsDir);
      for (FileSystemEntity entity in testsDirectory.listSync()) {
        if (entity is Directory) {
          if (FileSystemEntity.typeSync(path.join(entity.path, "pass")) ==
              FileSystemEntityType.directory) {
            tester.runtests(entity.path, "pass", 0);
          }
          if (FileSystemEntity.typeSync(path.join(entity.path, "fail")) ==
              FileSystemEntityType.directory) {
            tester.runtests(entity.path, "fail", 10);
          }
        }
      }
    }
  }

  stdout.writeln(boldPen("== Summary =="));
  stdout.writeln("# ${greenPen(tick)} successes: ${tester.successes}");
  stdout.writeln("# ${redPen(cross)}  failures: ${tester.failures}");
  stdout.writeln("# ${yellowPen(minus)}   skipped: ${tester.skipped}");

  if (measure) {
    DateTime endTime = new DateTime.now();
    Duration elapsed = endTime.difference(startTime);
    String elapsed_fmt = "${elapsed.inMilliseconds / 1000}";
    String accumulated_fmt = "${tester.accumulator.inMilliseconds / 1000}";
    String overhead = "${(elapsed - tester.accumulator).inMilliseconds / 1000}";
    stdout.writeln(boldPen("== Running time statistics =="));
    stdout.writeln("# Total running time: ${elapsed_fmt}s");
    stdout.writeln("# Accumulated test running time: ${accumulated_fmt}s");
    stdout.writeln("# Test script overhead: ${overhead}s");
  }

  if (tester.failures > 0) {
    exit(1);
  } else {
    exit(0);
  }
}
