class CropRegion {
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;

  CropRegion({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  CropRegion copyWith({
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return CropRegion(
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  String toString() {
    return 'CropRegion(name: $name, x: $x, y: $y, width: $width, height: $height)';
  }
}
