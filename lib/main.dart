import 'package:flutter/material.dart';
import 'screens/dungeon_home.dart';

void main() => runApp(const DungeonApp());

const gold = Color(0xFFFFC857);

class DungeonApp extends StatelessWidget {
  const DungeonApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ashen Depths',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF10131C),
          colorScheme: ColorScheme.fromSeed(
            seedColor: gold,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const DungeonHome(),
      );
}
