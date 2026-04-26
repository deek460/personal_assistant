import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'app.dart';
import 'core/utils/service_locator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/services/wake_word_service.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize service locator
  await setupServiceLocator();

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FlutterGemma.initialize(); // add this line

  //await WakeWordService().initialize();

  runApp(const MyApp());
}
