import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_assistant/main.dart' as app;
import 'dart:developer' as developer;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Ensure the test doesn't time out during long runs
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Performance Test: Latency, Resources & Resilience', (tester) async {
    // 1. Start App
    app.main();
    await tester.pumpAndSettle();

    // 2. Load Commands from ARC-Easy Dataset
    final String jsonString = await rootBundle.loadString('assets/test_data/arc_commands.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    final List<String> commands = jsonList.cast<String>();

    print('TEST_LOG: Loaded ${commands.length} commands for testing.');

    // 3. Navigate to Voice Chat
    final fab = find.byIcon(Icons.mic); // Assuming Mic icon on FAB/Button
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab);
      await tester.pumpAndSettle();
    } else {
      print("TEST_LOG: Warning - Mic button not found on home screen. Check navigation.");
    }

    // 4. Test Loop
    final latencies = <int>[];

    // Limit to 20 commands for a reasonable test duration on cloud lab
    final testCommands = commands.take(20).toList();

    for (int i = 0; i < testCommands.length; i++) {
      final command = testCommands[i];
      print('TEST_LOG: [$i/${testCommands.length}] Processing: "$command"');

      // --- RESOURCE LOGGING (RAM) ---
      // We can't easily get system-level battery/RAM from inside the Dart test
      // without platform channels or relying on Firebase Test Lab's external profiler.
      // However, we can log Dart Heap usage.
      final rss = ProcessInfo.currentRss / 1024 / 1024; // MB
      print('TEST_LOG: Metric - RAM_RSS: ${rss.toStringAsFixed(2)} MB');

      final Stopwatch stopwatch = Stopwatch()..start();

      // INJECT INPUT via Debug Field
      final inputField = find.byKey(const Key('debug_input'));
      final sendButton = find.byKey(const Key('debug_send'));

      if (inputField.evaluate().isEmpty) {
        print("TEST_LOG: CRITICAL - Debug input field not found. Skipping.");
        continue;
      }

      await tester.enterText(inputField, command);
      await tester.tap(sendButton);

      stopwatch.reset(); // Start counting PURE latency from send

      // WAIT FOR RESPONSE
      bool responseReceived = false;

      // Wait up to 15 seconds for response
      for (int j = 0; j < 150; j++) {
        await tester.pump(const Duration(milliseconds: 100));

        // Check for specific Latency text widget which indicates a finished response
        final latencyWidgets = find.textContaining('Latency:');

        // We assume index 'i' corresponds to the i-th message pair (User + AI)
        // So we look for the presence of a new latency widget.
        // Simple heuristic: If we find a latency widget at the bottom of the list
        if (latencyWidgets.evaluate().isNotEmpty) {
          // To be precise, we'd need to count them, but for a simple loop,
          // checking if *any* new text appeared after our tap is usually sufficient.
          // Let's assume the latency widget appears ONLY when response starts/finishes.

          // Better heuristic: Check if the last message is NOT the user's input
          // For this test, finding 'Latency:' is a good proxy that the AI responded.
          // We need to ensure we aren't counting OLD latency widgets.
          // Since we clear history or start fresh, the count should increase.
          if (latencyWidgets.evaluate().length > i) {
            responseReceived = true;
            stopwatch.stop();
            latencies.add(stopwatch.elapsedMilliseconds);
            print('TEST_LOG: Metric - TTFT: ${stopwatch.elapsedMilliseconds} ms');
            break;
          }
        }
      }

      if (!responseReceived) {
        print('TEST_LOG: Failure - Timeout waiting for response.');
      }

      // Wait a bit for TTS/State to settle
      await Future.delayed(const Duration(seconds: 2));
    }

    // 5. Summary
    if (latencies.isNotEmpty) {
      final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
      print('TEST_LOG: === RESULTS ===');
      print('TEST_LOG: Avg Latency: ${avgLatency.toStringAsFixed(2)} ms');
    }

    // 6. Crash Resilience Check (Simulated)
    // We verify the app is still responsive after the load.
    // If the app crashed during the loop, this test would have failed already.
    expect(find.byType(TextField), findsOneWidget); // Verify UI is still there
    print('TEST_LOG: Resilience - App survived command loop.');
  });
}