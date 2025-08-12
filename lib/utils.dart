import 'dart:math';
import 'package:flutter/material.dart';

/// 유틸리티 함수들을 모아놓은 클래스
class Utils {
  /// 파일 확장자를 기반으로 비디오 파일인지 확인
  static bool isVideoFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    return [
      'mp4',
      'avi',
      'mov',
      'wmv',
      'flv',
      'webm',
      'mkv',
    ].contains(extension);
  }

  /// 랜덤 색상 생성 (알파값 20% 포함)
  static Color generateRandomColor() {
    final random = Random();
    return Color.fromARGB(
      255,
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );
  }

  /// 파일 크기를 읽기 쉬운 형태로 변환
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 파일 경로에서 파일명만 추출
  static String getFileName(String path) {
    return path.split('/').last;
  }

  /// 파일 경로에서 디렉토리 경로만 추출
  static String getDirectoryPath(String path) {
    final parts = path.split('/');
    parts.removeLast();
    return parts.join('/');
  }
}
