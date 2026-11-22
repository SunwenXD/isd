import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isd/features/seating_map/seating_map_page.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SeatingMapPage(),
    ),
  );
}
