// ignore_for_file: prefer_const_constructors

import 'dart:math';

import 'start_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.greenAccent,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: ColorScheme.fromSeed(seedColor: Colors.greenAccent)
            .onPrimaryContainer
            .withOpacity(0.3),
        appBar: AppBar(
          title: Text('Career Rec!'),
          backgroundColor: Colors.black,
        ),
        body: Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            width: min(720, screenSize.width),
            child: StartScreen(),
          ),
        ),
      ),
    );
  }
}
