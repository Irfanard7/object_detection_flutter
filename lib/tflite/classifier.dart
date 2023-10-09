import 'dart:math';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:object_detection/tflite/recognition.dart';
import 'package:object_detection/utils/file_util.dart';
import 'package:object_detection/utils/image_utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'stats.dart';

/// Classifier
class Classifier {
  /// Instance of Interpreter
  Interpreter? _interpreter;

  /// Labels file loaded as list
  late List<String> _labels;

  static const String MODEL_FILE_NAME = "assets/model.tflite";
  static const String LABEL_FILE_NAME = "classes.txt";

  /// Result score threshold
  static const double THRESHOLD = 0.5;

  /// Number of results to show
  static const int NUM_RESULTS = 10;

  Classifier({
    Interpreter? interpreter,
    List<String>? labels,
  }) {
    loadModel(interpreter: interpreter);
    loadLabels(labels: labels);
  }

  /// Loads interpreter from asset
  void loadModel({Interpreter? interpreter}) async {
    try {
      _interpreter = interpreter ??
          await Interpreter.fromAsset(
            MODEL_FILE_NAME,
            options: InterpreterOptions()
              ..threads = 4,
          );
    } catch (e) {
      print("Error while creating interpreter: $e");
    }
  }

  /// Loads labels from assets
  void loadLabels({List<String>? labels}) async {
    try {
      _labels =
          labels ?? await FileUtil.loadLabels("assets/$LABEL_FILE_NAME");
    } catch (e) {
      print("Error while loading labels: $e");
    }
  }

  /// Runs object detection on the input image
  (Recognition, Stats)? predict(img.Image imageInput) {
    var predictStartTime = DateTime
        .now()
        .millisecondsSinceEpoch;

    if (_interpreter == null) {
      print("Interpreter not initialized");
      return null;
    }

    /**
     * PRE PROCESSING
     */

    var preProcessStart = DateTime
        .now()
        .millisecondsSinceEpoch;

    // Pre-process TensorImage
    // crop image into square
    final padSize = min(imageInput.height, imageInput.width);
    imageInput = ImageUtils.resizeWithCropOrPad(imageInput, padSize, padSize);
    imageInput = ImageUtils.scaleImageBilinear(imageInput, 224, 224);

    final inputData =
    ImageUtils.toByteListFloat32(imageInput, 224).reshape([1, 224, 224, 3]);

    var preProcessElapsedTime =
        DateTime
            .now()
            .millisecondsSinceEpoch - preProcessStart;

    /**
     * PREDICTING
     */

    // run inference
    var output = List.filled(8, 0).reshape([1, 8]);
    _interpreter!.run(inputData, output);

    var labeledOutput = <(String, double)>[];
    for (var i = 0; i < labels!.length; i++) {
      labeledOutput.add((labels![i], output[0][i]));
    }

    labeledOutput.sort((v1, v2) {
      var (_, b1) = v1;
      var (_, b2) = v2;
      return b1 < b2 ? 1 : -1;
    });

    // print(labeledOutput);

    final result = labeledOutput[0].$1;

    var predictElapsedTime =
        DateTime
            .now()
            .millisecondsSinceEpoch - predictStartTime;

    return (Recognition(result: result), Stats(
        totalPredictTime: predictElapsedTime,
        inferenceTime: 0,
        preProcessingTime: preProcessElapsedTime)
    );
  }

  /// Gets the interpreter instance
  Interpreter? get interpreter => _interpreter;

  /// Gets the loaded labels
  List<String>? get labels => _labels;
}
