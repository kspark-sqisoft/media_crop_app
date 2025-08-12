import 'package:flutter/material.dart';

class CropRegion {
  final String name;
  final double x; // 원본 미디어 크기 대비 상대 X 좌표 (0.0 ~ 1.0)
  final double y; // 원본 미디어 크기 대비 상대 Y 좌표 (0.0 ~ 1.0)
  final double width; // 원본 미디어 크기 대비 상대 너비 (0.0 ~ 1.0)
  final double height; // 원본 미디어 크기 대비 상대 높이 (0.0 ~ 1.0)
  final Color color; // 크롭 영역의 고유 색상

  CropRegion({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
  });

  CropRegion copyWith({
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    Color? color,
  }) {
    return CropRegion(
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      color: color ?? this.color,
    );
  }

  @override
  String toString() {
    return 'CropRegion(name: $name, x: $x, y: $y, width: $width, height: $height, color: $color)';
  }
}
