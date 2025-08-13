// Flutter 기본 위젯 및 Material Design 관련 import
import 'package:flutter/material.dart';

// 데스크톱에서 파일 드래그 앤 드롭 기능을 위한 패키지
import 'package:desktop_drop/desktop_drop.dart';

// 미디어 재생을 위한 패키지 (비디오/오디오 파일 처리)
import 'package:media_kit/media_kit.dart';

// MediaKit의 비디오 위젯 및 컨트롤러
import 'package:media_kit_video/media_kit_video.dart';

// 이미지 파일의 메타데이터(크기, 형식 등)를 읽기 위한 패키지
import 'package:image/image.dart' as img;

// 크롭 영역을 드래그하여 조정할 수 있는 위젯 패키지
import 'package:flutter_box_transform/flutter_box_transform.dart';

// MediaKit 비디오 컨트롤 (재생, 일시정지 등) 관련 패키지
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart'
    as media_kit_video_controls;

// 파일 시스템 접근을 위한 Dart IO 라이브러리
import 'dart:io';

// 크롭 영역 정보를 관리하는 클래스
import 'crop_region.dart';

// 유틸리티 함수들 (파일 형식 판별, 색상 생성 등)
import 'utils.dart';

/// 미디어 크롭 페이지의 메인 위젯
/// 이미지나 비디오 파일을 드래그 앤 드롭으로 불러와서 크롭 영역을 설정할 수 있는 페이지
class MediaCropPage extends StatefulWidget {
  const MediaCropPage({super.key});

  @override
  State<MediaCropPage> createState() => _MediaCropPageState();
}

/// MediaCropPage의 상태를 관리하는 클래스
/// 파일 드래그 앤 드롭, 미디어 재생, 크롭 영역 관리 등의 기능을 담당
class _MediaCropPageState extends State<MediaCropPage> {
  // ==================== UI 관련 상수 ====================
  /// 화면 가장자리에서의 패딩 값 (픽셀 단위)
  /// 이 값은 언제든 변경 가능하며, 전체 UI 레이아웃에 영향을 줍니다
  static const double _paddingValue = 16.0;

  // ==================== 드래그 앤 드롭 상태 ====================
  /// 현재 파일이 드래그되고 있는지 여부를 나타내는 플래그
  /// true일 때 드롭존에 시각적 피드백을 제공합니다
  bool _isDragging = false;

  // ==================== 미디어 파일 정보 ====================
  /// 현재 로드된 미디어 파일의 경로
  /// null일 경우 파일이 로드되지 않은 상태
  String? _mediaPath;

  /// 현재 로드된 파일이 비디오인지 이미지인지 여부
  /// true: 비디오 파일, false: 이미지 파일
  bool _isVideo = false;

  // ==================== UI 상태 ====================
  /// 설정 패널의 열림/닫힘 상태
  /// true: 설정 패널이 열려있음, false: 설정 패널이 닫혀있음
  bool _isSettingsPanelOpen = true;

  // ==================== 미디어 재생 관련 ====================
  /// MediaKit의 미디어 플레이어 인스턴스
  /// 비디오 파일 재생을 담당합니다
  late final Player _player;

  /// 비디오 컨트롤러
  /// 비디오 위젯과 플레이어를 연결하는 역할을 합니다
  late final VideoController _controller;

  // ==================== 미디어 크기 정보 ====================
  /// 원본 미디어 파일의 너비 (픽셀 단위)
  /// 이미지의 경우 실제 픽셀 크기, 비디오의 경우 해상도
  int? _mediaWidth;

  /// 원본 미디어 파일의 높이 (픽셀 단위)
  /// 이미지의 경우 실제 픽셀 크기, 비디오의 경우 해상도
  int? _mediaHeight;

  /// 현재 화면에 표시되는 미디어의 너비 (픽셀 단위)
  /// BoxFit.contain에 따라 계산된 실제 표시 크기
  double? _currentDisplayWidth;

  /// 현재 화면에 표시되는 미디어의 높이 (픽셀 단위)
  /// BoxFit.contain에 따라 계산된 실제 표시 크기
  double? _currentDisplayHeight;

  // ==================== 크롭 영역 관리 ====================
  /// 사용자가 설정한 모든 크롭 영역들의 리스트
  /// 각 CropRegion은 위치, 크기, 색상 등의 정보를 포함합니다
  final List<CropRegion> _cropRegions = [];

  /// 다음에 생성될 크롭 영역의 고유 ID
  /// 각 크롭 영역은 고유한 ID를 가지며, 이 값은 계속 증가합니다
  int _nextRegionId = 1;

  // ==================== 창 크기 변화 추적 ====================
  /// 현재 창 크기가 변화하고 있는지 여부를 나타내는 플래그
  /// true일 때는 크롭 영역의 자동 조정을 방지하여 사용자 경험을 개선합니다
  bool _isResizing = false;

  /// 위젯이 처음 생성될 때 호출되는 메서드
  /// 미디어 플레이어와 컨트롤러를 초기화하고, 초기 창 크기를 설정합니다
  @override
  void initState() {
    super.initState();

    // MediaKit 플레이어 인스턴스 생성
    // 이 플레이어는 비디오 파일 재생을 담당합니다
    _player = Player();

    // 비디오 컨트롤러 생성 및 플레이어와 연결
    // 이 컨트롤러는 비디오 위젯과 플레이어 사이의 중재자 역할을 합니다
    _controller = VideoController(_player);

    // 위젯이 화면에 렌더링된 후 실행되는 콜백
    // 이 시점에서 MediaQuery를 통해 실제 화면 크기를 안전하게 가져올 수 있습니다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 위젯이 여전히 마운트되어 있는지 확인 (메모리 누수 방지)
      if (mounted) {
        // 현재 화면의 전체 크기 가져오기
        final size = MediaQuery.of(context).size;

        // 패딩을 제외한 실제 사용 가능한 공간 계산
        // 좌우 패딩을 제외한 너비
        _currentDisplayWidth = size.width - (_paddingValue * 2);
        // 상하 패딩을 제외한 높이
        _currentDisplayHeight = size.height - (_paddingValue * 2);
      }
    });
  }

  /// 위젯이 제거될 때 호출되는 메서드
  /// 리소스 정리 및 메모리 누수 방지를 위해 플레이어를 해제합니다
  @override
  void dispose() {
    // MediaKit 플레이어의 리소스 해제
    // 이는 메모리 누수를 방지하고 시스템 리소스를 정리합니다
    _player.dispose();

    // 부모 클래스의 dispose 메서드 호출
    super.dispose();
  }

  /// 현재 로드된 미디어와 관련된 모든 상태를 초기화하는 메서드
  /// 새로운 파일을 로드하기 전에 호출되거나, 사용자가 초기화를 원할 때 사용됩니다
  void _resetMedia() {
    setState(() {
      // 미디어 파일 경로 초기화
      _mediaPath = null;

      // 미디어 타입 초기화 (이미지/비디오 구분)
      _isVideo = false;

      // 원본 미디어 크기 정보 초기화
      _mediaWidth = null;
      _mediaHeight = null;

      // 현재 화면에 표시되는 크기 정보 초기화
      _currentDisplayWidth = null;
      _currentDisplayHeight = null;

      // 사용자가 설정한 모든 크롭 영역들을 제거
      // 새로운 미디어를 로드할 때 이전 크롭 영역은 의미가 없기 때문입니다
      _cropRegions.clear();

      // 크롭 영역 ID 카운터를 1로 리셋
      // 새로운 미디어에 대해 크롭 영역을 다시 생성할 수 있도록 합니다
      _nextRegionId = 1;
    });

    // MediaKit 플레이어를 정지
    // 비디오가 재생 중이었다면 중단시킵니다
    _player.stop();
  }

  /// 설정 패널의 열림/닫힘 상태를 토글하는 메서드
  /// 사용자가 설정 버튼을 클릭할 때 호출되어 패널을 열거나 닫습니다
  void _toggleSettingsPanel() {
    setState(() {
      // 현재 상태의 반대값으로 설정
      // true면 false로, false면 true로 변경
      _isSettingsPanelOpen = !_isSettingsPanelOpen;
    });
  }

  /// 현재 화면 크기에 맞춰 미디어의 표시 크기를 계산하는 메서드
  /// BoxFit.contain을 사용하여 미디어의 비율을 유지하면서 화면에 맞춥니다
  ///
  /// [constraints] LayoutBuilder에서 제공하는 제약 조건 (선택적)
  ///               null인 경우 MediaQuery를 사용하여 화면 크기를 가져옵니다
  void _calculateCurrentDisplaySize([BoxConstraints? constraints]) {
    // 화면 크기 변수 선언
    double screenWidth, screenHeight;

    if (constraints != null) {
      // LayoutBuilder의 constraints를 사용하는 경우
      // 이 경우 constraints는 이미 패딩이 적용된 공간을 나타냅니다
      screenWidth = constraints.maxWidth;
      screenHeight = constraints.maxHeight;
    } else {
      // MediaQuery를 사용하는 경우
      // 전체 화면 크기에서 패딩을 제외한 실제 사용 가능한 공간을 계산합니다
      screenWidth =
          MediaQuery.of(context).size.width - (_paddingValue * 2); // 좌우 패딩 제외
      screenHeight =
          MediaQuery.of(context).size.height - (_paddingValue * 2); // 상하 패딩 제외
    }

    // 미디어 크기 정보가 있는 경우에만 계산 진행
    if (_mediaWidth != null && _mediaHeight != null) {
      // 원본 미디어의 가로세로 비율 계산
      final aspectRatio = _mediaWidth! / _mediaHeight!;

      // BoxFit.contain에 따라 계산된 표시 크기 변수
      double displayWidth, displayHeight;

      // 화면과 미디어의 비율을 비교하여 적절한 표시 크기 결정
      if (screenWidth / screenHeight > aspectRatio) {
        // 사용 가능한 공간이 미디어보다 더 넓은 경우
        // 높이에 맞춰서 표시하고, 너비는 비율에 따라 자동 계산
        displayHeight = screenHeight;
        displayWidth = screenHeight * aspectRatio;
      } else {
        // 사용 가능한 공간이 미디어보다 더 좁은 경우
        // 너비에 맞춰서 표시하고, 높이는 비율에 따라 자동 계산
        displayWidth = screenWidth;
        displayHeight = screenWidth / aspectRatio;
      }

      // 계산된 크기가 이전과 다른 경우에만 상태 업데이트
      // 불필요한 setState 호출을 방지하여 성능을 개선합니다
      if (_currentDisplayWidth != displayWidth ||
          _currentDisplayHeight != displayHeight) {
        setState(() {
          // 새로운 표시 크기로 업데이트
          _currentDisplayWidth = displayWidth;
          _currentDisplayHeight = displayHeight;

          // 창 크기 변화 중임을 표시하는 플래그 설정
          // 이 플래그는 크롭 영역의 자동 조정을 방지합니다
          _isResizing = true;
        });

        // 100ms 후에 리사이징 플래그를 해제
        // 이는 창 크기 변화가 완료되었음을 의미합니다
        Future.delayed(const Duration(milliseconds: 100), () {
          // 위젯이 여전히 마운트되어 있는지 확인 (메모리 누수 방지)
          if (mounted) {
            setState(() {
              _isResizing = false;
            });
          }
        });
      }
    }
  }

  /// 미디어 파일의 원본 크기(해상도) 정보를 가져오는 메서드
  /// 이미지와 비디오 파일에 대해 각각 다른 방식으로 크기 정보를 추출합니다
  ///
  /// [path] 미디어 파일의 경로
  ///
  /// 이미지 파일: image 패키지를 사용하여 파일 헤더에서 직접 크기 정보 추출
  /// 비디오 파일: MediaKit을 사용하여 비디오 스트림의 메타데이터에서 크기 정보 추출
  void _getMediaDimensions(String path) async {
    if (_isVideo) {
      // ==================== 비디오 파일 크기 정보 추출 ====================
      // 비디오의 경우 MediaKit을 사용하여 실제 메타데이터에서 크기 정보를 가져옵니다
      try {
        // MediaKit의 Media 객체 생성
        // 이 객체는 비디오 파일의 메타데이터와 스트림 정보를 포함합니다
        final media = Media(path);

        // 플레이어에 미디어 파일 열기
        // 이 과정에서 비디오 스트림 정보가 로드됩니다
        await _player.open(media);

        // 플레이리스트 모드를 단일 파일 재생으로 설정
        // 이는 한 번에 하나의 비디오만 재생되도록 보장합니다
        await _player.setPlaylistMode(PlaylistMode.single);

        // 비디오 메타데이터가 완전히 로드될 때까지 대기
        // MediaKit이 스트림 정보를 파싱하는데 시간이 필요합니다
        await Future.delayed(const Duration(milliseconds: 1000));

        // 비디오 스트림 정보에서 크기 가져오기
        final tracks = _player.state.tracks;

        if (tracks.video.isNotEmpty) {
          final videoTrack = tracks.video.first;

          // 플레이어 상태에서 크기 정보 확인
          final playerState = _player.state;

          // 비디오 크기 정보를 찾기 위해 다양한 방법 시도
          bool sizeFound = false;

          // 1. VideoTrack에서 직접 크기 정보 찾기
          try {
            // VideoTrack의 모든 public 속성 확인
            final trackString = videoTrack.toString();

            // 문자열에서 크기 정보 패턴 찾기 (w: 1920, h: 1080 형태)
            final sizePattern = RegExp(
              r'w:\s*(\d+),\s*h:\s*(\d+)',
              caseSensitive: false,
            );
            final match = sizePattern.firstMatch(trackString);
            if (match != null) {
              final width = int.tryParse(match.group(1) ?? '');
              final height = int.tryParse(match.group(2) ?? '');
              if (width != null && height != null) {
                setState(() {
                  _mediaWidth = width;
                  _mediaHeight = height;
                });
                sizeFound = true;
              }
            }
          } catch (e) {
            // 크기 정보 추출 실패 시 무시
          }

          // 2. 여전히 크기 정보가 없으면 플레이어 상태에서 찾기
          if (!sizeFound) {
            try {
              final stateString = playerState.toString();

              // VideoParams에서 크기 정보 찾기 (w: 1920, h: 1080 형태)
              final videoParamsPattern = RegExp(
                r'w:\s*(\d+),\s*h:\s*(\d+)',
                caseSensitive: false,
              );
              final videoMatch = videoParamsPattern.firstMatch(stateString);
              if (videoMatch != null) {
                final width = int.tryParse(videoMatch.group(1) ?? '');
                final height = int.tryParse(videoMatch.group(2) ?? '');
                if (width != null && height != null) {
                  setState(() {
                    _mediaWidth = width;
                    _mediaHeight = height;
                  });
                  sizeFound = true;
                }
              }

              // 여전히 없으면 width, height 필드에서 찾기
              if (!sizeFound) {
                final widthHeightPattern = RegExp(
                  r'width:\s*(\d+),\s*height:\s*(\d+)',
                  caseSensitive: false,
                );
                final whMatch = widthHeightPattern.firstMatch(stateString);
                if (whMatch != null) {
                  final width = int.tryParse(whMatch.group(1) ?? '');
                  final height = int.tryParse(whMatch.group(2) ?? '');
                  if (width != null && height != null) {
                    setState(() {
                      _mediaWidth = width;
                      _mediaHeight = height;
                    });
                    sizeFound = true;
                  }
                }
              }
            } catch (e) {
              // 크기 정보 추출 실패 시 무시
            }
          }

          // 3. 여전히 크기 정보가 없으면 직접 접근 시도
          if (!sizeFound) {
            try {
              // playerState에서 직접 width, height 접근
              if (playerState.width != null && playerState.height != null) {
                setState(() {
                  _mediaWidth = playerState.width;
                  _mediaHeight = playerState.height;
                });
                sizeFound = true;
              }
            } catch (e) {
              // 직접 접근 실패 시 무시
            }
          }

          // 4. 여전히 크기 정보가 없으면 기본값 설정
          if (!sizeFound) {
            setState(() {
              _mediaWidth = 1920; // 기본값
              _mediaHeight = 1080; // 기본값
            });
          }
        }

        // 비디오 크기 설정 후 현재 표시 크기 계산
        if (_mediaWidth != null && _mediaHeight != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          _calculateCurrentDisplaySize();
        }
      } catch (e) {
        setState(() {
          _mediaWidth = 1920; // 기본값
          _mediaHeight = 1080; // 기본값
        });
      }
    } else {
      // 이미지의 경우 image 패키지를 사용하여 정확한 크기 가져오기
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final image = img.decodeImage(bytes);

          if (image != null) {
            setState(() {
              _mediaWidth = image.width;
              _mediaHeight = image.height;
            });

            // 이미지 크기 설정 후 현재 표시 크기 계산
            await Future.delayed(const Duration(milliseconds: 100));
            _calculateCurrentDisplaySize();
          } else {
            // image 패키지로 파싱 실패 시 수동 파싱 시도
            _parseImageSizeManually(bytes);

            // 수동 파싱 후 현재 표시 크기 계산
            if (_mediaWidth != null && _mediaHeight != null) {
              await Future.delayed(const Duration(milliseconds: 100));
              _calculateCurrentDisplaySize();
            }
          }
        }
      } catch (e) {
        // 오류 발생 시 수동 파싱 시도
        try {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            _parseImageSizeManually(bytes);

            // 수동 파싱 후 현재 표시 크기 계산
            if (_mediaWidth != null && _mediaHeight != null) {
              await Future.delayed(const Duration(milliseconds: 100));
              _calculateCurrentDisplaySize();
            }
          }
        } catch (e2) {
          setState(() {
            _mediaWidth = 1920; // 기본값
            _mediaHeight = 1080; // 기본값
          });
        }
      }
    }
  }

  /// 이미지 파일의 바이트 데이터에서 직접 크기 정보를 파싱하는 메서드
  /// image 패키지로 파싱에 실패했을 때의 fallback 방법입니다
  ///
  /// [bytes] 이미지 파일의 바이트 데이터
  ///
  /// 지원하는 형식:
  /// - JPEG: SOF0 마커에서 크기 정보 추출
  /// - PNG: IHDR 청크에서 크기 정보 추출
  /// - GIF: 헤더에서 크기 정보 추출
  void _parseImageSizeManually(List<int> bytes) {
    // 최소한의 바이트 수가 필요합니다 (JPEG의 경우 24바이트 이상)
    if (bytes.length < 24) return;

    try {
      // ==================== JPEG 파일 크기 파싱 ====================
      // JPEG 파일은 0xFF 0xD8으로 시작합니다 (SOI 마커)
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        // SOI 마커 다음부터 검색 시작
        int i = 2;

        // 파일 끝까지 SOF0 마커를 찾습니다
        // SOF0 마커는 Start of Frame 0으로, 이미지 크기 정보를 포함합니다
        while (i < bytes.length - 9) {
          // SOF0 마커: 0xFF 0xC0
          if (bytes[i] == 0xFF && bytes[i + 1] == 0xC0) {
            // SOF0 마커 다음 9바이트에 크기 정보가 있습니다
            if (i + 9 < bytes.length) {
              setState(() {
                // 높이: 5,6번째 바이트 (Big Endian)
                _mediaHeight = (bytes[i + 5] << 8) | bytes[i + 6];
                // 너비: 7,8번째 바이트 (Big Endian)
                _mediaWidth = (bytes[i + 7] << 8) | bytes[i + 8];
              });
            }
            break; // SOF0 마커를 찾았으므로 검색 중단
          }
          i++; // 다음 바이트로 이동
        }
      }
      // ==================== PNG 파일 크기 파싱 ====================
      // PNG 파일은 0x89 0x50 0x4E 0x47로 시작합니다 (PNG 시그니처)
      else if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        // PNG 헤더는 최소 32바이트가 필요합니다
        if (bytes.length > 32) {
          setState(() {
            // 너비: 16-19번째 바이트 (Big Endian, 4바이트)
            _mediaWidth =
                (bytes[16] << 24) |
                (bytes[17] << 16) |
                (bytes[18] << 8) |
                bytes[19];
            // 높이: 20-23번째 바이트 (Big Endian, 4바이트)
            _mediaHeight =
                (bytes[20] << 24) |
                (bytes[21] << 16) |
                (bytes[22] << 8) |
                bytes[23];
          });
        }
      }
      // ==================== GIF 파일 크기 파싱 ====================
      // GIF 파일은 0x47 0x49 0x46로 시작합니다 (GIF 시그니처)
      else if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        // GIF 헤더는 최소 10바이트가 필요합니다
        if (bytes.length > 10) {
          setState(() {
            // 너비: 6,7번째 바이트 (Little Endian)
            _mediaWidth = bytes[6] | (bytes[7] << 8);
            // 높이: 8,9번째 바이트 (Little Endian)
            _mediaHeight = bytes[8] | (bytes[9] << 8);
          });
        }
      }
    } catch (e) {
      // 수동 파싱 중 오류가 발생한 경우 무시합니다
      // 이는 파일이 손상되었거나 예상과 다른 형식일 수 있습니다
    }
  }

  /// 새로운 크롭 영역을 추가하는 메서드
  /// 미디어가 로드되어 있고 크기 정보가 있는 경우에만 실행됩니다
  ///
  /// 크롭 영역은 다음과 같은 특징을 가집니다:
  /// - 기본 크기: 200x200 픽셀 (원본 미디어 크기 대비 상대값)
  /// - 위치: 미디어 영역의 정중앙
  /// - 색상: 랜덤하게 생성된 고유 색상
  /// - 이름: "영역 1", "영역 2" 등의 순차적 이름
  void _addCropRegion() {
    // 미디어 크기 정보가 모두 있는 경우에만 크롭 영역 추가 가능
    if (_mediaWidth != null &&
        _mediaHeight != null &&
        _currentDisplayWidth != null &&
        _currentDisplayHeight != null) {
      // ==================== 크롭 영역 크기 계산 ====================
      // 기본 크기를 200x200 픽셀로 설정
      // 이 값은 원본 미디어 크기 대비 상대값(0.0 ~ 1.0)으로 변환됩니다
      final cropWidth = 200.0 / _mediaWidth!; // 너비의 상대값
      final cropHeight = 200.0 / _mediaHeight!; // 높이의 상대값

      // ==================== 크롭 영역 위치 계산 ====================
      // 미디어 영역의 정중앙에 크롭 영역을 배치합니다
      // 상대 좌표는 0.0(왼쪽/위쪽) ~ 1.0(오른쪽/아래쪽) 범위입니다
      final cropLeft = 0.5 - (cropWidth / 2); // 중앙에서 왼쪽으로 cropWidth/2만큼
      final cropTop = 0.5 - (cropHeight / 2); // 중앙에서 위쪽으로 cropHeight/2만큼

      // ==================== 새로운 크롭 영역 생성 ====================
      final newRegion = CropRegion(
        name: '영역 $_nextRegionId', // 순차적 이름 (영역 1, 영역 2, ...)
        x: cropLeft, // 상대 X 좌표 (0.0 ~ 1.0)
        y: cropTop, // 상대 Y 좌표 (0.0 ~ 1.0)
        width: cropWidth, // 상대 너비 (0.0 ~ 1.0)
        height: cropHeight, // 상대 높이 (0.0 ~ 1.0)
        color: Utils.generateRandomColor(), // 랜덤 색상 (고유성 보장)
      );

      // ==================== 상태 업데이트 ====================
      setState(() {
        // 크롭 영역 리스트에 새 영역 추가
        _cropRegions.add(newRegion);

        // 다음 크롭 영역의 ID를 증가시킴
        // 이는 각 크롭 영역이 고유한 ID를 가지도록 보장합니다
        _nextRegionId++;
      });
    }
  }

  /// 특정 인덱스의 크롭 영역을 새로운 값으로 업데이트하는 메서드
  ///
  /// [index] 업데이트할 크롭 영역의 인덱스
  /// [newRegion] 새로운 크롭 영역 데이터
  void _updateCropRegion(int index, CropRegion newRegion) {
    setState(() {
      // 지정된 인덱스의 크롭 영역을 새로운 값으로 교체
      _cropRegions[index] = newRegion;
    });
  }

  /// 설정 패널의 입력 필드에서 크롭 영역 값을 업데이트하는 메서드
  /// 사용자가 입력한 픽셀 값을 상대 좌표(0.0 ~ 1.0)로 변환하여 적용합니다
  ///
  /// [index] 업데이트할 크롭 영역의 인덱스
  /// [value] 사용자가 입력한 문자열 값 (픽셀 단위)
  /// [field] 업데이트할 필드 ('x', 'y', 'width', 'height' 중 하나)
  void _updateCropRegionFromList(int index, String value, String field) {
    // 업데이트할 크롭 영역 가져오기
    final region = _cropRegions[index];

    // 문자열을 double로 변환
    double? newValue;

    // ==================== X 좌표 업데이트 ====================
    if (field == 'x') {
      newValue = double.tryParse(value);
      if (newValue != null) {
        // 입력된 픽셀 값을 상대 좌표로 변환
        // 상대 좌표 = 픽셀 값 / 원본 미디어 너비
        _updateCropRegion(index, region.copyWith(x: newValue / _mediaWidth!));
      }
    }
    // ==================== Y 좌표 업데이트 ====================
    else if (field == 'y') {
      newValue = double.tryParse(value);
      if (newValue != null) {
        // 입력된 픽셀 값을 상대 좌표로 변환
        // 상대 좌표 = 픽셀 값 / 원본 미디어 높이
        _updateCropRegion(index, region.copyWith(y: newValue / _mediaHeight!));
      }
    }
    // ==================== 너비 업데이트 ====================
    else if (field == 'width') {
      newValue = double.tryParse(value);
      if (newValue != null && newValue > 0) {
        // 입력된 픽셀 값을 상대 좌표로 변환
        // 상대 너비 = 픽셀 너비 / 원본 미디어 너비
        _updateCropRegion(
          index,
          region.copyWith(width: newValue / _mediaWidth!),
        );
      }
    }
    // ==================== 높이 업데이트 ====================
    else if (field == 'height') {
      newValue = double.tryParse(value);
      if (newValue != null && newValue > 0) {
        // 입력된 픽셀 값을 상대 좌표로 변환
        // 상대 높이 = 픽셀 높이 / 원본 미디어 높이
        _updateCropRegion(
          index,
          region.copyWith(height: newValue / _mediaHeight!),
        );
      }
    }
  }

  /// 모든 크롭 영역에 대해 크롭 작업을 수행하는 메서드
  /// 현재는 콘솔에 크롭 정보를 출력하는 기능만 구현되어 있습니다
  ///
  /// 실제 이미지 크롭 기능을 구현하려면:
  /// 1. 각 크롭 영역의 픽셀 좌표 계산
  /// 2. 이미지 처리 라이브러리를 사용한 실제 크롭 작업
  /// 3. 크롭된 이미지 저장
  void _cropAllRegions() {
    // 크롭 영역이 없는 경우 사용자에게 알림
    if (_cropRegions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('크롭할 영역이 없습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // ==================== 크롭 작업 수행 ====================
    // 현재는 콘솔에 크롭 정보만 출력하는 데모 기능입니다
    print('=== 모든 크롭 영역 크롭 시작 ===');

    // 모든 크롭 영역에 대해 정보 출력
    for (int i = 0; i < _cropRegions.length; i++) {
      final region = _cropRegions[i];

      // 상대 좌표를 실제 픽셀 좌표로 변환
      final pixelX = (region.x * _mediaWidth!).toInt(); // X 좌표 (픽셀)
      final pixelY = (region.y * _mediaHeight!).toInt(); // Y 좌표 (픽셀)
      final pixelWidth = (region.width * _mediaWidth!).toInt(); // 너비 (픽셀)
      final pixelHeight = (region.height * _mediaHeight!).toInt(); // 높이 (픽셀)

      // 크롭 영역 정보를 콘솔에 출력
      print('영역 ${i + 1}: ${region.name}');
      print('  위치: ($pixelX, $pixelY)');
      print('  크기: ${pixelWidth}x$pixelHeight');
      print('  색상: ${region.color}');
    }

    // ==================== 성공 메시지 표시 ====================
    // 사용자에게 크롭 작업이 완료되었음을 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_cropRegions.length}개 영역 크롭 완료!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 개별 크롭 영역에 대한 크롭 작업을 수행하는 메서드
  /// 현재는 데모용으로 콘솔에 메시지만 출력합니다
  ///
  /// 향후 구현 예정:
  /// - 특정 크롭 영역만 선택하여 크롭
  /// - 크롭된 이미지 미리보기
  /// - 크롭 설정 저장/불러오기
  void _cropRegion() {
    print('=== 크롭 영역 크롭 시작 ===');
  }

  /// 위젯의 UI를 구성하는 메서드
  /// 전체 화면을 차지하는 드롭존과 오른쪽 상단의 설정 패널로 구성됩니다
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        // 전체 화면에 패딩 적용
        padding: EdgeInsets.all(_paddingValue),
        child: Stack(
          children: [
            // ==================== 미디어 영역 (전체 화면) ====================
            // 파일을 드래그 앤 드롭할 수 있는 영역
            DropTarget(
              // 파일이 드롭되었을 때 호출되는 콜백
              onDragDone: (detail) {
                if (detail.files.isNotEmpty) {
                  final file = detail.files.first;
                  final path = file.path;

                  // 미디어 파일 정보 설정
                  setState(() {
                    _mediaPath = path; // 파일 경로 저장
                    _isVideo = Utils.isVideoFile(path); // 비디오 여부 판별
                  });

                  // 비디오 파일인 경우 MediaKit 플레이어로 열기
                  if (_isVideo) {
                    _player.open(Media(path));
                  }

                  // 미디어 파일의 크기 정보 가져오기
                  _getMediaDimensions(path);
                }
              },
              // 파일이 드롭존에 진입했을 때 호출되는 콜백
              onDragEntered: (detail) {
                setState(() {
                  _isDragging = true; // 드래그 상태 활성화
                });
              },
              // 파일이 드롭존을 벗어났을 때 호출되는 콜백
              onDragExited: (detail) {
                setState(() {
                  _isDragging = false; // 드래그 상태 비활성화
                });
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // ==================== 창 크기 변화 감지 및 대응 ====================
                  // constraints 변경을 감지하여 크기 재계산 (크롭 영역 값은 변경하지 않음)
                  if (_mediaWidth != null && _mediaHeight != null) {
                    // 이전 constraints와 비교하여 실제로 변경된 경우에만 호출
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // 현재 constraints가 이전과 다른 경우에만 크기 재계산
                      if (_currentDisplayWidth == null ||
                          _currentDisplayHeight == null ||
                          constraints.maxWidth != _currentDisplayWidth ||
                          constraints.maxHeight != _currentDisplayHeight) {
                        _calculateCurrentDisplaySize(constraints);
                      }
                    });
                  }

                  // ==================== 미디어 콘텐츠 영역 ====================
                  // 전체 화면을 차지하는 SizedBox
                  return SizedBox(
                    width: double.infinity, // 전체 너비 사용
                    height: double.infinity, // 전체 높이 사용
                    child: LayoutBuilder(
                      builder: (context, innerConstraints) {
                        // 실제 미디어 콘텐츠를 렌더링
                        return _buildMediaContent(innerConstraints);
                      },
                    ),
                  );
                },
              ),
            ),

            // ==================== 설정 패널 (오른쪽 상단에 겹쳐서 표시) ====================
            // 미디어가 로드된 경우에만 표시
            if (_mediaPath != null)
              Positioned(
                top: 20, // 상단에서 20픽셀 아래
                right: 20, // 오른쪽에서 20픽셀 왼쪽
                width: _isSettingsPanelOpen ? 400 : null, // 열린 상태일 때 너비 400
                height: _isSettingsPanelOpen ? 800 : null, // 열린 상태일 때 높이 800
                child: _isSettingsPanelOpen
                    ? _buildSettingsPanel() // 설정 패널이 열린 경우
                    : _buildToggleButton(), // 설정 패널이 닫힌 경우 (토글 버튼만)
              ),
          ],
        ),
      ),
    );
  }

  /// 설정 패널을 열기 위한 토글 버튼을 생성하는 메서드
  /// 설정 패널이 닫혀있을 때 오른쪽 상단에 작은 설정 아이콘으로 표시됩니다
  Widget _buildToggleButton() {
    return Container(
      // 버튼 주변의 패딩 (4픽셀)
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        // 반투명 흰색 배경 (95% 불투명도)
        color: Colors.white.withValues(alpha: 0.95),
        // 둥근 모서리 (6픽셀 반지름)
        borderRadius: BorderRadius.circular(6),
        // 그림자 효과
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2), // 20% 불투명도의 검은색
            blurRadius: 8, // 8픽셀 블러 효과
            offset: const Offset(0, 2), // 아래쪽으로 2픽셀 이동
          ),
        ],
        // 회색 테두리 (1픽셀 두께)
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: IconButton(
        // 버튼 클릭 시 설정 패널 토글
        onPressed: _toggleSettingsPanel,
        // 설정 아이콘 (16픽셀 크기)
        icon: const Icon(Icons.settings, size: 16),
        // 마우스 호버 시 표시되는 툴팁
        tooltip: '설정 패널 열기',
        // 버튼 내부 패딩 제거
        padding: EdgeInsets.zero,
        // 버튼의 최소 크기 제한
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        // 버튼 스타일 설정
        style: IconButton.styleFrom(
          backgroundColor: Colors.blue[100], // 연한 파란색 배경
          foregroundColor: Colors.blue[700], // 진한 파란색 아이콘
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    final fileName = _mediaPath?.split('/').last ?? '';
    final filePath = _mediaPath ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        children: [
          // 상단 내용 (파일 정보 + 크롭 영역 관리)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 파일 정보
              Row(
                children: [
                  Icon(
                    _isVideo ? Icons.video_file : Icons.image,
                    color: Colors.blue[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _resetMedia,
                    icon: const Icon(Icons.refresh, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    tooltip: '초기화',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 파일 경로
              if (filePath.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '경로:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        filePath,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              // 파일 크기 정보
              if (_mediaWidth != null && _mediaHeight != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '파일 크기:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_mediaWidth × $_mediaHeight',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // CropRegion 관리 섹션
              Row(
                children: [
                  Icon(Icons.crop_square, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    '크롭 영역',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _addCropRegion,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('추가', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[100],
                      foregroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),

          // 중간 영역 (크롭 영역 리스트 또는 빈 공간)
          Expanded(
            child: _cropRegions.isNotEmpty
                ? ListView.builder(
                    shrinkWrap: true,
                    itemCount: _cropRegions.length,
                    itemBuilder: (context, index) {
                      final region = _cropRegions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: region.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: region.color.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 영역 이름과 삭제 버튼
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  region.name,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: region.color,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _cropRegions.removeAt(index);
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 입력 필드들
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // X 좌표 입력
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'X',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      SizedBox(
                                        height: 28,
                                        child: TextField(
                                          controller: TextEditingController(
                                            text: (region.x * _mediaWidth!)
                                                .toInt()
                                                .toString(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Colors.red,
                                          ),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.all(6),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            isDense: true,
                                          ),
                                          onSubmitted: (value) {
                                            _updateCropRegionFromList(
                                              index,
                                              value,
                                              'x',
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Y 좌표 입력
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Y',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      SizedBox(
                                        height: 28,
                                        child: TextField(
                                          controller: TextEditingController(
                                            text: (region.y * _mediaHeight!)
                                                .toInt()
                                                .toString(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Colors.red,
                                          ),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.all(6),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            isDense: true,
                                          ),
                                          onSubmitted: (value) {
                                            _updateCropRegionFromList(
                                              index,
                                              value,
                                              'y',
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Width 입력
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'W',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      SizedBox(
                                        height: 28,
                                        child: TextField(
                                          controller: TextEditingController(
                                            text: (region.width * _mediaWidth!)
                                                .toInt()
                                                .toString(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Colors.red,
                                          ),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.all(6),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            isDense: true,
                                          ),
                                          onSubmitted: (value) {
                                            _updateCropRegionFromList(
                                              index,
                                              value,
                                              'width',
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Height 입력
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'H',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      SizedBox(
                                        height: 28,
                                        child: TextField(
                                          controller: TextEditingController(
                                            text:
                                                (region.height * _mediaHeight!)
                                                    .toInt()
                                                    .toString(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Colors.red,
                                          ),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.all(6),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            isDense: true,
                                          ),
                                          onSubmitted: (value) {
                                            _updateCropRegionFromList(
                                              index,
                                              value,
                                              'height',
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 크롭하기 버튼
                                SizedBox(
                                  width: 80,
                                  height: 28,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _cropRegion();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: const Text(
                                      '크롭하기',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Container(), // 크롭 영역이 없을 때는 빈 컨테이너
          ),

          // 모두 크롭 하기 버튼
          if (_cropRegions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _cropAllRegions,
                      icon: const Icon(Icons.crop, size: 16),
                      label: const Text(
                        '모두 크롭 하기',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 하단 닫기 버튼 (항상 하단에 고정)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _toggleSettingsPanel,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      '닫기',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 미디어 콘텐츠를 렌더링하는 메서드
  /// 미디어가 로드되지 않은 경우 드롭존 UI를, 로드된 경우 미디어와 크롭 영역을 표시합니다
  ///
  /// [constraints] LayoutBuilder에서 제공하는 제약 조건
  Widget _buildMediaContent(BoxConstraints constraints) {
    // ==================== 미디어가 로드되지 않은 경우 ====================
    if (_mediaPath == null) {
      return Container(
        width: double.infinity, // 전체 너비 사용
        height: double.infinity, // 전체 높이 사용
        decoration: BoxDecoration(
          color: Colors.grey[100], // 연한 회색 배경
          border: Border.all(
            color: Colors.grey[300]!, // 회색 테두리
            width: 2, // 2픽셀 두께
            style: BorderStyle.solid, // 실선 스타일
          ),
        ),
        child: _isDragging
            // ==================== 파일이 드래그 중인 경우 ====================
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 클라우드 업로드 아이콘 (파란색, 64픽셀)
                    Icon(Icons.cloud_upload, size: 64, color: Colors.blue),
                    SizedBox(height: 16), // 아이콘과 텍스트 사이 간격
                    // 드래그 안내 메시지
                    Text(
                      '파일을 여기에 드래그하세요',
                      style: TextStyle(fontSize: 18, color: Colors.blue),
                    ),
                  ],
                ),
              )
            // ==================== 파일이 드래그되지 않은 경우 ====================
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 이미지 아이콘 (회색, 64픽셀)
                    Icon(Icons.image, size: 64, color: Colors.grey),
                    SizedBox(height: 16), // 아이콘과 텍스트 사이 간격
                    // 파일 드래그 안내 메시지
                    Text(
                      '비디오 또는 이미지 파일을 드래그하세요',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
      );
    }

    // ==================== 미디어 위젯 생성 ====================
    Widget mediaWidget;
    if (_isVideo) {
      // 비디오 파일인 경우 MediaKit Video 위젯 사용
      mediaWidget = Video(
        controller: _controller, // 비디오 컨트롤러
        fit: BoxFit.contain, // 비율 유지하며 화면에 맞춤
        fill: Colors.transparent, // 배경색 투명
        controls: media_kit_video_controls.NoVideoControls, // 비디오 컨트롤 숨김
      );
    } else {
      // 이미지 파일인 경우 Flutter 기본 Image.file 위젯 사용
      mediaWidget = Image.file(File(_mediaPath!), fit: BoxFit.contain);
    }

    // ==================== 미디어 콘텐츠 레이아웃 ====================
    // Stack을 사용하여 여러 레이어를 겹쳐서 표시
    return Stack(
      children: [
        // ==================== 메인 미디어 위젯 ====================
        // 전체 화면을 채우는 미디어 (이미지 또는 비디오)
        Positioned.fill(child: mediaWidget),

        // ==================== 크기 정보 박스 ====================
        // 오른쪽 하단에 미디어 크기 정보를 표시
        if (_mediaWidth != null && _mediaHeight != null)
          Positioned(bottom: 20, right: 20, child: _buildSizeInfoBox()),

        // ==================== 크롭 영역 컨테이너 ====================
        // 미디어가 실제로 표시되는 영역을 나타내는 Container
        // 이 영역 내에서 크롭 영역들이 조작됩니다
        if (_currentDisplayWidth != null && _currentDisplayHeight != null)
          Positioned(
            // 화면 중앙에 미디어 영역을 배치
            left:
                (constraints.maxWidth - _currentDisplayWidth!) / 2, // 좌우 중앙 정렬
            top:
                (constraints.maxHeight - _currentDisplayHeight!) /
                2, // 상하 중앙 정렬
            child: SizedBox(
              width: _currentDisplayWidth!, // 미디어 표시 너비
              height: _currentDisplayHeight!, // 미디어 표시 높이
              child: Stack(
                children: [
                  // ==================== 크롭 영역들 ====================
                  // 사용자가 설정한 모든 크롭 영역을 TransformableBox로 렌더링
                  ..._cropRegions.asMap().entries.map((entry) {
                    final index = entry.key; // 크롭 영역의 인덱스
                    final region = entry.value; // 크롭 영역 데이터

                    return TransformableBox(
                      key: ValueKey('crop_region_$index'),
                      rect: Rect.fromLTWH(
                        // 상대 좌표를 실제 화면 좌표로 변환
                        region.x * _currentDisplayWidth!,
                        region.y * _currentDisplayHeight!,
                        region.width * _currentDisplayWidth!,
                        region.height * _currentDisplayHeight!,
                      ),
                      clampingRect: Rect.fromLTWH(
                        0,
                        0,
                        _currentDisplayWidth ?? 0,
                        _currentDisplayHeight ?? 0,
                      ),
                      onChanged: (result, event) {
                        // 창 크기 변화 중일 때만 차단
                        if (_isResizing) {
                          return;
                        }

                        // 사용자의 정상적인 드래그/리사이즈는 허용
                        // 창 크기 변화로 인한 자동 조정만 차단

                        // 변경된 좌표를 상대 좌표로 변환하여 저장
                        final updatedRegion = region.copyWith(
                          x: result.rect.left / _currentDisplayWidth!,
                          y: result.rect.top / _currentDisplayHeight!,
                          width: result.rect.width / _currentDisplayWidth!,
                          height: result.rect.height / _currentDisplayHeight!,
                        );

                        _updateCropRegion(index, updatedRegion);
                      },
                      cornerHandleBuilder: (context, handle) {
                        return DefaultCornerHandle(
                          handle: handle,
                          size: 8,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 1),
                            color: Colors.white,
                            shape: BoxShape.rectangle,
                          ),
                        );
                      },
                      sideHandleBuilder: (context, handle) {
                        return DefaultSideHandle(
                          handle: handle,
                          length: 8,
                          thickness: 8,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 1),
                            color: Colors.white,
                            shape: BoxShape.rectangle,
                          ),
                        );
                      },
                      contentBuilder: (context, rect, flip) {
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: region.color, width: 2),
                            color: region.color.withValues(
                              alpha: 0.2,
                            ), // 알파값 20%
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // 영역 이름
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: region.color.withValues(
                                          alpha: 0.8,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        region.name,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // 좌표와 크기 정보
                                    Text(
                                      'X: ${(region.x * _mediaWidth!).toInt()}, Y: ${(region.y * _mediaHeight!).toInt()}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'W: ${(region.width * _mediaWidth!).toInt()}, H: ${(region.height * _mediaHeight!).toInt()}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // 입력 필드들
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // X 좌표 입력
                                        SizedBox(
                                          width: 49,
                                          height: 34,
                                          child: TextField(
                                            controller: TextEditingController(
                                              text: (region.x * _mediaWidth!)
                                                  .toInt()
                                                  .toString(),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'X',
                                              labelStyle: TextStyle(
                                                fontSize: 7,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.all(4),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                            onSubmitted: (value) {
                                              final newX = double.tryParse(
                                                value,
                                              );
                                              if (newX != null) {
                                                // 입력된 픽셀 값을 상대 좌표로 변환
                                                final updatedRegion = region
                                                    .copyWith(
                                                      x: newX / _mediaWidth!,
                                                    );
                                                _updateCropRegion(
                                                  index,
                                                  updatedRegion,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Y 좌표 입력
                                        SizedBox(
                                          width: 49,
                                          height: 34,
                                          child: TextField(
                                            controller: TextEditingController(
                                              text: (region.y * _mediaHeight!)
                                                  .toInt()
                                                  .toString(),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Y',
                                              labelStyle: TextStyle(
                                                fontSize: 7,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.all(4),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                            onSubmitted: (value) {
                                              final newY = double.tryParse(
                                                value,
                                              );
                                              if (newY != null) {
                                                // 입력된 값을 원본 미디어 크기 기준으로 변환
                                                final scaleY =
                                                    (_currentDisplayHeight ??
                                                        1) /
                                                    _mediaHeight!;
                                                final updatedRegion = region
                                                    .copyWith(y: newY * scaleY);
                                                _updateCropRegion(
                                                  index,
                                                  updatedRegion,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Width 입력
                                        SizedBox(
                                          width: 49,
                                          height: 34,
                                          child: TextField(
                                            controller: TextEditingController(
                                              text:
                                                  (region.width * _mediaWidth!)
                                                      .toInt()
                                                      .toString(),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'W',
                                              labelStyle: TextStyle(
                                                fontSize: 7,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.all(4),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                            onSubmitted: (value) {
                                              final newWidth = double.tryParse(
                                                value,
                                              );
                                              if (newWidth != null &&
                                                  newWidth > 0) {
                                                // 입력된 픽셀 값을 상대 좌표로 변환
                                                final updatedRegion = region
                                                    .copyWith(
                                                      width:
                                                          newWidth /
                                                          _mediaWidth!,
                                                    );
                                                _updateCropRegion(
                                                  index,
                                                  updatedRegion,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Height 입력
                                        SizedBox(
                                          width: 49,
                                          height: 34,
                                          child: TextField(
                                            controller: TextEditingController(
                                              text:
                                                  (region.height *
                                                          _mediaHeight!)
                                                      .toInt()
                                                      .toString(),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'H',
                                              labelStyle: TextStyle(
                                                fontSize: 7,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.all(4),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                            onSubmitted: (value) {
                                              final newHeight = double.tryParse(
                                                value,
                                              );
                                              if (newHeight != null &&
                                                  newHeight > 0) {
                                                // 입력된 픽셀 값을 상대 좌표로 변환
                                                final updatedRegion = region
                                                    .copyWith(
                                                      height:
                                                          newHeight /
                                                          _mediaHeight!,
                                                    );
                                                _updateCropRegion(
                                                  index,
                                                  updatedRegion,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 미디어 크기 정보를 표시하는 정보 박스를 생성하는 메서드
  /// 오른쪽 하단에 원본 크기와 현재 표시 크기를 보여줍니다
  Widget _buildSizeInfoBox() {
    return Container(
      // 박스 내부 패딩 (8픽셀)
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9), // 90% 불투명도의 흰색 배경
        borderRadius: BorderRadius.circular(8), // 8픽셀 반지름의 둥근 모서리
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1), // 10% 불투명도의 검은색 그림자
            blurRadius: 5, // 5픽셀 블러 효과
            offset: const Offset(0, 2), // 아래쪽으로 2픽셀 이동
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
        mainAxisSize: MainAxisSize.min, // 필요한 최소 크기만 사용
        children: [
          // ==================== 원본 크기 섹션 ====================
          Text(
            '원본 크기',
            style: TextStyle(
              fontSize: 10, // 작은 글씨 크기
              color: Colors.grey[600], // 회색 텍스트
              fontWeight: FontWeight.w500, // 중간 굵기
            ),
          ),
          const SizedBox(height: 4), // 라벨과 값 사이 간격
          Text(
            '${_mediaWidth ?? 0} × ${_mediaHeight ?? 0}', // 원본 미디어 크기 (픽셀)
            style: TextStyle(
              fontSize: 14, // 큰 글씨 크기
              fontWeight: FontWeight.bold, // 굵은 글씨
              color: Colors.blue[700], // 파란색 텍스트
            ),
          ),
          const SizedBox(height: 8), // 섹션 간 간격
          // ==================== 현재 표시 크기 섹션 ====================
          Text(
            '현재 크기',
            style: TextStyle(
              fontSize: 10, // 작은 글씨 크기
              color: Colors.grey[600], // 회색 텍스트
              fontWeight: FontWeight.w500, // 중간 굵기
            ),
          ),
          const SizedBox(height: 4), // 라벨과 값 사이 간격
          Text(
            '${_currentDisplayWidth?.toStringAsFixed(0) ?? '0'} × ${_currentDisplayHeight?.toStringAsFixed(0) ?? '0'}', // 현재 화면에 표시되는 크기 (픽셀)
            style: TextStyle(
              fontSize: 14, // 큰 글씨 크기
              fontWeight: FontWeight.bold, // 굵은 글씨
              color: Colors.green[700], // 초록색 텍스트
            ),
          ),
        ],
      ),
    );
  }
} // _MediaCropPageState 클래스 끝

// ==================== 파일 끝 ====================
// 이 파일은 미디어 크롭 애플리케이션의 메인 페이지를 구현합니다.
// 주요 기능:
// - 파일 드래그 앤 드롭 (desktop_drop 패키지 사용)
// - 이미지/비디오 파일 표시 (MediaKit 사용)
// - 크롭 영역 설정 및 조작 (flutter_box_transform 패키지 사용)
// - 반응형 UI (창 크기 변화에 따른 자동 조정)
