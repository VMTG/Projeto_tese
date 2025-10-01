// ******************************************************************************
// * IMPORTS SECTION
// ******************************************************************************
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart'; // For resetting the app
import 'package:Sensor/theme/app_theme.dart';

import 'package:Sensor/services/supabase_service.dart';

import 'views/start_page.dart';

// ******************************************************************************
// * MAIN APPLICATION ENTRY POINT
// ******************************************************************************
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar o serviço Supabase
  final supabaseService = SupabaseService();
  await supabaseService.initialize(
    'https://iytncyrlqrpqovvtqznx.supabase.co', // Substitua pela URL real
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5dG5jeXJscXJwcW92dnRxem54Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyNzQ0MjEsImV4cCI6MjA3Mzg1MDQyMX0.PcQUJm6xqNwnmGx1yPfSBoACGsO8K0KcRBwNa-jBfzw', // Substitua pela chave real
  );

  // Teste da conexão
  await supabaseService.testConnection();

  runApp(
    Phoenix(
      child: const SensorApp(),
    ),
  );
}

// ******************************************************************************
// * ROOT APPLICATION WIDGET
// * Sets up the MaterialApp and theme
// ******************************************************************************
class SensorApp extends StatelessWidget {
  const SensorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Data',
      //theme: ThemeData(primarySwatch: Colors.blue),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Acompanha o tema do sistema
      home: const StartPage(), // Use the home page as home
    );
  }
}

// ******************************************************************************
// * OPERATION MODE ENUM
// * Defines the operating modes available in the application
// ******************************************************************************
enum OperationMode {
  continuous,
  impact,
  neutral, // Adicionando o modo neutro
}

// ******************************************************************************
// * DATA MODEL
// * Simple class to store time-series sensor data
// ******************************************************************************
class SensorData {
  final DateTime time;
  final double value;

  SensorData(this.time, this.value);
}
