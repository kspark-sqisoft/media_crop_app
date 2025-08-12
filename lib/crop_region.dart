class CropRegion {
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final double? originalWidth; // 크롭 영역이 생성된 시점의 표시 너비
  final double? originalHeight; // 크롭 영역이 생성된 시점의 표시 높이

  CropRegion({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.originalWidth,
    this.originalHeight,
  });

  CropRegion copyWith({
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    double? originalWidth,
    double? originalHeight,
  }) {
    return CropRegion(
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      originalWidth: originalWidth ?? this.originalWidth,
      originalHeight: originalHeight ?? this.originalHeight,
    );
  }

  @override
  String toString() {
    return 'CropRegion(name: $name, x: $x, y: $y, width: $width, height: $height, originalWidth: $originalWidth, originalHeight: $originalHeight)';
  }
}
