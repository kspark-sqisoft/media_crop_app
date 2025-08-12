import 'package:flutter/material.dart';

class CropRegion {
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final double? originalWidth; // 크롭 영역이 생성된 시점의 표시 너비
  final double? originalHeight; // 크롭 영역이 생성된 시점의 표시 높이
  final Color color; // 크롭 영역의 고유 색상

  CropRegion({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.originalWidth,
    this.originalHeight,
    required this.color,
  });

  CropRegion copyWith({
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    double? originalWidth,
    double? originalHeight,
    Color? color,
  }) {
    return CropRegion(
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      originalWidth: originalWidth ?? this.originalWidth,
      originalHeight: originalHeight ?? this.originalHeight,
      color: color ?? this.color,
    );
  }

  @override
  String toString() {
    return 'CropRegion(name: $name, x: $x, y: $y, width: $width, height: $height, originalWidth: $originalWidth, originalHeight: $originalHeight, color: $color)';
  }
}
