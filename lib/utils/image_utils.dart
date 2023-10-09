import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;
import 'package:path_provider/path_provider.dart';

/// ImageUtils
class ImageUtils {
  /// Converts a [CameraImage] in YUV420 format to [image_lib.Image] in RGB format
  static image_lib.Image? convertCameraImage(CameraImage cameraImage) {
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      return convertYUV420ToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return convertBGRA8888ToImage(cameraImage);
    } else {
      return null;
    }
  }

  /// Converts a [CameraImage] in BGRA888 format to [image_lib.Image] in RGB format
  static image_lib.Image? convertBGRA8888ToImage(CameraImage cameraImage) {
    final plane = cameraImage.planes[0];

    if (plane.width != null && plane.height != null) {
      image_lib.Image img = image_lib.Image.fromBytes(
          width: plane.width!,
          height: plane.height!,
          bytes: plane.bytes.buffer,
          format: image_lib.Format.uint8,
          order: image_lib.ChannelOrder.bgra);
      return img;
    } else {
      return null;
    }
  }

  /// Converts a [CameraImage] in YUV420 format to [image_lib.Image] in RGB format
  static image_lib.Image? convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int? uvPixelStride = cameraImage.planes[1].bytesPerPixel;

    // return null if pixels null
    if (uvPixelStride == null) {
      return null;
    }

    final image = image_lib.Image(width: width, height: height);

    for (int w = 0; w < width; w++) {
      for (int h = 0; h < height; h++) {
        final int uvIndex =
            uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final int index = h * width + w;

        final y = cameraImage.planes[0].bytes[index];
        final u = cameraImage.planes[1].bytes[uvIndex];
        final v = cameraImage.planes[2].bytes[uvIndex];

        final (r, g, b) = yuv2rgb(y, u, v);

        if (image.isBoundsSafe(height - h, w)) {
          image.setPixelRgb(height - h, w, r, g, b);
        }
      }
    }
    return image;
  }

  /// Convert a single YUV pixel to RGB
  static (int, int, int) yuv2rgb(int y, int u, int v) {
    // Convert yuv pixel to rgb
    int r = (y + v * 1436 / 1024 - 179).round();
    int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
    int b = (y + u * 1814 / 1024 - 227).round();

    // Clipping RGB values to be inside boundaries [ 0 , 255 ]
    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);

    return (r, g, b);
  }

  static void saveImage(image_lib.Image image, [int i = 0]) async {
    List<int> jpeg = image_lib.encodeJpg(image);
    final appDir = await getTemporaryDirectory();
    final appPath = appDir.path;
    final fileOnDevice = File('$appPath/out$i.jpg');
    await fileOnDevice.writeAsBytes(jpeg, flush: true);
    print('Saved $appPath/out$i.jpg');
  }

  static image_lib.Image resizeWithCropOrPad(
      image_lib.Image input, int targetWidth, int targetHeight) {
    int srcL;
    int srcR;
    int srcT;
    int srcB;
    int dstL;
    int dstR;
    int dstT;
    int dstB;
    int w = input.width;
    int h = input.height;

    if (targetWidth > w) {
      // padding
      srcL = 0;
      srcR = w;
      dstL = (targetWidth - w) ~/ 2;
      dstR = dstL + w;
    } else {
      // cropping
      dstL = 0;
      dstR = targetWidth;
      // custom crop position. First item of the tuple represent the desired position for left position
      // and the second item the right position
      final (posL, posR) = ImageUtils._computeCropPosition(targetWidth, w);
      srcL = posL;
      srcR = posR;
    }
    if (targetHeight > h) {
      // padding
      srcT = 0;
      srcB = h;
      dstT = (targetHeight - h) ~/ 2;
      dstB = dstT + h;
    } else {
      // cropping
      dstT = 0;
      dstB = targetHeight;
      // custom crop position. First item of the tuple represent the desired position for top position
      // and the second item the bottom position
      final (posT, posB) = _computeCropPosition(targetHeight, h);
      srcT = posT;
      srcB = posB;
    }

    final output = image_lib.Image(width: targetWidth, height: targetHeight);
    image_lib.Image resized = ImageUtils._drawResizeWithCropOrPad(output, input,
        dstX: dstL,
        dstY: dstT,
        dstH: dstB - dstT,
        dstW: dstR - dstL,
        srcX: srcL,
        srcY: srcT,
        srcH: srcB - srcT,
        srcW: srcR - srcL);

    return resized;
  }

  static (int, int) _computeCropPosition(int targetSize, int imageSize) {
    int srcLT;
    int srcRB;

    srcLT = (imageSize - targetSize) ~/ 2; // centered crop
    srcRB = srcLT + targetSize;

    return (srcLT, srcRB);
  }

  static image_lib.Image _drawResizeWithCropOrPad(
      image_lib.Image dst, image_lib.Image src,
      {int? dstX,
      int? dstY,
      int? dstW,
      int? dstH,
      int? srcX,
      int? srcY,
      int? srcW,
      int? srcH,
      bool blend = false}) {
    dstX ??= 0;
    dstY ??= 0;
    srcX ??= 0;
    srcY ??= 0;
    srcW ??= src.width;
    srcH ??= src.height;
    dstW ??= (dst.width < src.width) ? dstW = dst.width : src.width;
    dstH ??= (dst.height < src.height) ? dst.height : src.height;

    for (var y = 0; y < dstH; ++y) {
      for (var x = 0; x < dstW; ++x) {
        var stepX = (x * (srcW / dstW)).toInt();
        var stepY = (y * (srcH / dstH)).toInt();

        final srcPixel = src.getPixel(srcX + stepX, srcY + stepY);
        if (blend) {
          image_lib.drawPixel(dst, dstX + x, dstY + y, srcPixel);
        } else {
          dst.setPixel(dstX + x, dstY + y, srcPixel);
        }
      }
    }

    return dst;
  }

  static image_lib.Image scaleImageBilinear(
      image_lib.Image image, int targetWidth, int targetHeight) {
    return image_lib.copyResize(image,
        width: targetWidth,
        height: targetHeight,
        interpolation: image_lib.Interpolation.linear);
  }

  static Rect inverseTransformRect(
      Rect rect, int inputImageHeight, int inputImageWidth) {
    // when rotation is involved, corner order may change - top left changes to bottom right, .etc
    image_lib.Point p1 = image_lib.Point(rect.left, rect.top);
    image_lib.Point p2 = image_lib.Point(rect.right, rect.bottom);
    return Rect.fromLTRB(min(p1.x, p2.x) as double, min(p1.y, p2.y) as double,
        max(p1.x, p2.x) as double, max(p1.y, p2.y) as double);
  }

  static Float32List toByteListFloat32(image_lib.Image image, int inputSize) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r / 127.5) - 1;
        buffer[pixelIndex++] = (pixel.g / 127.5) - 1;
        buffer[pixelIndex++] = (pixel.b / 127.5) - 1;
      }
    }
    return convertedBytes;
  }
}
