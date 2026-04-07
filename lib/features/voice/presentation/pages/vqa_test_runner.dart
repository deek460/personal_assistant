import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
// Switched import to the concrete implementation using the correct relative path
import '../../../../features/gemma_integration/data/repositories/gemma_repository_impl.dart';

class VqaTestRunner {
  // Changed from GemmaRepository to GemmaRepositoryImpl
  final GemmaRepositoryImpl repository;

  VqaTestRunner(this.repository);

  Future<String> runAutomatedTests(String jsonAssetPath) async {
    print("🚀 Starting Automated VQA Tests...");

    // 1. Load the dataset
    final String jsonString = await rootBundle.loadString(jsonAssetPath);
    final List<dynamic> dataset = json.decode(jsonString);

    // 2. Prepare CSV Output
    List<String> csvRows = [
      "ID,Question,Expected Answer,Actual Response,Latency (ms),Status"
    ];

    int passed = 0;
    int failed = 0;

    // Get temp directory for extracting assets
    final tempDir = await getTemporaryDirectory();

    // 3. Loop through dataset sequentially
    for (var item in dataset) {
      final String id = item['id'];
      final String imageAssetPath = item['image_path'];
      final String question = item['question'];
      final String expected = item['expected'];

      print("🧪 Running Test $id: $question");

      try {
        // Load image bytes directly from assets
        final byteData = await rootBundle.load(imageAssetPath);

        // ML Kit and File() operations require an actual physical file path, not an asset path.
        // We write the asset out to a temporary file for the duration of this specific test.
        final tempFile = File('${tempDir.path}/$id.jpg');
        await tempFile.writeAsBytes(
            byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
        );

        // Start timer
        final stopwatch = Stopwatch()..start();

        // Generate Response Stream
        String actualResponse = "";

        // FIX: Pass `imagePath` with the physical temporary file path,
        // aligning with your updated GemmaRepositoryImpl signature.
        await for (final token in repository.generateResponseStream(
          question,
          imagePath: tempFile.path,
        )) {
          actualResponse += token;
        }

        stopwatch.stop();

        // Clean up response for CSV (remove newlines/commas that break CSV format)
        actualResponse = actualResponse.trim().replaceAll('\n', ' ').replaceAll('"', '""');

        // Simple heuristic validation: if the expected answer is in the response text
        bool isPass = actualResponse.toLowerCase().contains(expected.toLowerCase());
        if (isPass) passed++; else failed++;

        // Log to CSV
        csvRows.add(
            "$id,\"$question\",\"$expected\",\"$actualResponse\",${stopwatch.elapsedMilliseconds},${isPass ? 'PASS' : 'FAIL'}"
        );

        // Delete the temporary file to keep storage clean
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        // Crucial: Give the native GC time to clean up MediaPipe buffers between heavy vision queries
        await Future.delayed(const Duration(milliseconds: 500));

      } catch (e) {
        print("❌ Test $id Failed with error: $e");
        csvRows.add("$id,\"$question\",\"$expected\",\"ERROR: $e\",0,ERROR");
        failed++;
      }
    }

    // 4. Save CSV Proof to device documents folder
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/vqa_test_results_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvRows.join('\n'));

    print("✅ Automated Testing Complete!");
    print("📊 Passed: $passed | Failed: $failed");
    print("📄 Proof saved to: ${file.path}");

    return file.path; // Return the path so we can show it in the UI
  }
}