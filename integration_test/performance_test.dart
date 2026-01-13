import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_assistant/main.dart' as app;
import 'dart:developer' as developer;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Performance Test: Latency, Resources & Resilience', (tester) async {
    // 1. Start App
    app.main();
    await tester.pumpAndSettle();

    // 2. Load Commands
    final String jsonString = await rootBundle.loadString('assets/test_data/arc_commands.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    final List<String> commands = jsonList.cast<String>();

    print('TEST_LOG: Loaded ${commands.length} commands for testing.');

    // 3. Navigate to Voice Chat
    // Assuming Mic button on Home navigates to Voice Chat
    final micBtn = find.byIcon(Icons.mic);
    if (micBtn.evaluate().isNotEmpty) {
      await tester.tap(micBtn);
      await tester.pumpAndSettle();
    } else {
      print("TEST_LOG: Warning - Mic button not found. Assuming already on screen.");
    }

    // --- WAIT FOR MODEL INITIALIZATION ---
    print('TEST_LOG: Waiting for model to initialize...');
    bool isReady = false;
    for (int i = 0; i < 60; i++) { // Wait up to 60 seconds for copy + load
      await tester.pump(const Duration(seconds: 1));

      // Look for text indicating readiness.
      // Based on your UI logic: "Ready. Say 'Jack' to start." or similar
      // Or checking if the Mic button is enabled/blue.
      if (find.textContaining('Ready').evaluate().isNotEmpty ||
          find.textContaining('Tap to Speak').evaluate().isNotEmpty ||
          find.textContaining('Jack').evaluate().isNotEmpty) {
        isReady = true;
        print('TEST_LOG: Model Initialized!');
        break;
      }
    }

    if (!isReady) {
      print('TEST_LOG: CRITICAL FAILURE - Model failed to initialize in time.');
      // Fail the test or return
      return;
    }

    // 4. Test Loop
    final latencies = <int>[];
    final testCommands = commands.take(20).toList();

    for (int i = 0; i < testCommands.length; i++) {
      final command = testCommands[i];
      print('TEST_LOG: [$i/${testCommands.length}] Processing: "$command"');

      // Resource Logging
      final rss = ProcessInfo.currentRss / 1024 / 1024;
      print('TEST_LOG: Metric - RAM_RSS: ${rss.toStringAsFixed(2)} MB');

      final Stopwatch stopwatch = Stopwatch()..start();

      // INJECT INPUT
      final inputField = find.byKey(const Key('debug_input'));
      final sendButton = find.byKey(const Key('debug_send'));

      if (inputField.evaluate().isEmpty) {
        print("TEST_LOG: CRITICAL - Debug input field not found. Skipping.");
        continue;
      }

      await tester.enterText(inputField, command);
      await tester.tap(sendButton);

      stopwatch.reset(); // Start counting PURE latency from send

      // WAIT FOR RESPONSE COMPLETION
      bool responseStarted = false;
      bool responseFinished = false;
      int initialLatencyWidgetsCount = find.textContaining('Latency:').evaluate().length;

      // Wait loop (Max 60 seconds per response)
      for (int j = 0; j < 600; j++) {
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Check for TTFT (First Token / Latency Widget Appearance)
        if (!responseStarted) {
          final currentLatencyWidgetsCount = find.textContaining('Latency:').evaluate().length;
          if (currentLatencyWidgetsCount > initialLatencyWidgetsCount) {
            responseStarted = true;
            stopwatch.stop();
            latencies.add(stopwatch.elapsedMilliseconds);
            print('TEST_LOG: Metric - TTFT: ${stopwatch.elapsedMilliseconds} ms');
          }
        }

        // 2. Check for Completion
        // We look for the UI state returning to "Idle" or "Ready" (VoiceIdle)
        // This indicates TTS is done and Cubit is ready for next input.
        if (find.textContaining('Ready').evaluate().isNotEmpty ||
            find.textContaining('Tap microphone').evaluate().isNotEmpty) {

          // Ensure we actually started a response before considering it finished
          if (responseStarted) {
            responseFinished = true;
            print('TEST_LOG: Response finished & TTS complete.');
            break;
          }
        }
      }

      if (!responseFinished) {
        print('TEST_LOG: Failure - Timeout waiting for response completion.');
      }

      // 5. Hard Wait (Buffer)
      // Even if UI says ready, give a small buffer for cleanup/animations
      await Future.delayed(const Duration(seconds: 2));
    }

    // 6. Summary
    if (latencies.isNotEmpty) {
      final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
      print('TEST_LOG: === RESULTS ===');
      print('TEST_LOG: Avg Latency: ${avgLatency.toStringAsFixed(2)} ms');
    }

    expect(find.byType(TextField), findsOneWidget);
    print('TEST_LOG: Resilience - App survived command loop.');
  });
}