
import 'tensorbuffer.dart';

/// Represents data buffer with float(double) values.
class TensorBufferFloat extends TensorBuffer {
  /// Creates a [TensorBufferFloat] with specified [shape].
  ///
  /// Throws [ArgumentError.notNull] if [shape] is null.
  /// Throws [ArgumentError] if [shape] has non-positive elements.
  TensorBufferFloat(List<int> shape) : super(shape);

  @override
  int getTypeSize() {
    // returns size in bytes
    return 4;
  }

  @override
  int getIntValue(int absIndex) {
    return byteData.getFloat32(absIndex * 4, endian).floor();
  }

  @override
  List<double> getDoubleList() {
    List<double> arr = List.filled(flatSize, 0);
    for (int i = 0; i < flatSize; i++) {
      arr[i] = byteData.getFloat32(i * 4, endian);
    }
    return arr;
  }

  @override
  double getDoubleValue(int absIndex) {
    return byteData.getFloat32(absIndex * 4, endian);
  }
}
