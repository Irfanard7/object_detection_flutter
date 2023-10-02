import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Represents the data buffer for either a model's input or its output.
abstract class TensorBuffer {
  /// Where the data is stored
  @protected
  late ByteData byteData;

  /// Shape of the tensor
  @protected
  late List<int> shape;

  /// Gets the current shape. (returning a copy here to avoid unexpected modification.)
  List<int> getShape() => shape;

  /// Number of elements in the buffer. It will be changed to a proper value in the constructor.
  @protected
  late int flatSize = -1;

  /// Returns the data buffer.
  ByteBuffer get buffer => byteData.buffer;

  final Endian endian = Endian.little;

  /// Returns a List<double> of the values stored in this buffer. If the buffer is of different types
  /// than double, the values will be converted into double. For example, values in
  /// [TensorBufferUint8] will be converted from uint8 to double.
  List<double> getDoubleList();

  /// Returns a double value at [absIndex]. If the buffer is of different types than double, the
  /// value will be converted into double. For example, when reading a value from
  /// [TensorBufferUint8], the value will be first read out as uint8, and then will be converted from
  /// uint8 to double.
  ///
  /// ```
  /// For example, a TensorBuffer with shape {2, 3} that represents the following list,
  /// {{0.0, 1.0, 2.0}, {3.0, 4.0, 5.0}}.
  ///
  /// The fourth element (whose value is 3.0) in the TensorBuffer can be retrieved by:
  /// double v = tensorBuffer.getDoubleValue(3);
  /// ```
  double getDoubleValue(int absIndex);

  /// Returns an int value at [absIndex].
  ///
  /// Similar to [TensorBuffer.getDoubleValue]
  int getIntValue(int absIndex);

  /// Returns the number of bytes of a single element in the list. For example, a float buffer will
  /// return 4, and a byte buffer will return 1.
  int getTypeSize();

  /// Constructs a fixed size [TensorBuffer] with specified [shape].
  @protected
  TensorBuffer(List<int> shape) {
    _allocateMemory(shape);
  }

  void _allocateMemory(List<int> shape) {
    int newFlatSize = computeFlatSize(shape);
    this.shape = List<int>.from(shape);
    if (flatSize == newFlatSize) {
      return;
    }

    // Update to the new shape.
    flatSize = newFlatSize;
    byteData = ByteData(flatSize * getTypeSize());
  }

  /// Calculates number of elements in the buffer.
  static int computeFlatSize(List<int> shape) {
    int prod = 1;
    for (int s in shape) {
      prod = prod * s;
    }
    return prod;
  }
}