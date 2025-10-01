import 'package:flutter/material.dart';
import 'package:Sensor/main.dart';

import 'device_screen.dart';

// ******************************************************************************
// * NEW HOME PAGE WITH MODE BUTTONS
// ******************************************************************************
class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ou ícone
            const Icon(
              Icons.sensors,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),

            // Application title
            const Text(
              'Sensor Data Visualizer',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Application description
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'View real-time sensor data through interactive graphs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 50),

            // Operation modes section
            const Text(
              'Select operating mode:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Continuous mode button
            ElevatedButton(
              onPressed: () {
                // Navigate to the sensors screen in continuous mode
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => DeviceScreen(
                      mode: OperationMode.continuous,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                minimumSize: const Size(240, 50),
              ),
              child: const Text(
                'Continuous Mode',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Impact mode button
            ElevatedButton(
              onPressed: () {
                // Navigate to the sensors screen in impact mode
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => DeviceScreen(
                      mode: OperationMode.impact,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                minimumSize: const Size(240, 50),
                backgroundColor: Colors.orange,
              ),
              child: const Text(
                'Impact Mode',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),

            // Application version
            const SizedBox(height: 40),
            const Text(
              'Versão 1.0.0',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
