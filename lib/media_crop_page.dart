import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart'
    as media_kit_video_controls;
import 'dart:io';
import 'crop_region.dart';
import 'utils.dart';

class MediaCropPage extends StatefulWidget {
  const MediaCropPage({super.key});

  @override
  State<MediaCropPage> createState() => _MediaCropPageState();
}

class _MediaCropPageState extends State<MediaCropPage> {
  // 패딩 값 설정 (언제든 변경 가능)
  static const double _paddingValue = 16.0;

  bool _isDragging = false;
  String? _mediaPath;
  bool _isVideo = false;
  bool _isSettingsPanelOpen = true; // 설정 패널 열림/닫힘 상태
  late final Player _player;
  late final VideoController _controller;
  int? _mediaWidth;
  int? _mediaHeight;
  double? _currentDisplayWidth;
  double? _currentDisplayHeight;

  // CropRegion 관리
  final List<CropRegion> _cropRegions = [];
  int _nextRegionId = 1;

  // 창 크기 변화 중인지 추적하는 플래그
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    // 초기 창 크기 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        _currentDisplayWidth = size.width - (_paddingValue * 2);
        _currentDisplayHeight = size.height - (_paddingValue * 2);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _resetMedia() {
    setState(() {
      _mediaPath = null;
      _isVideo = false;
      _mediaWidth = null;
      _mediaHeight = null;
      _currentDisplayWidth = null;
      _currentDisplayHeight = null;
      // 크롭 영역도 함께 초기화
      _cropRegions.clear();
      _nextRegionId = 1;
    });
    _player.stop();
  }

  void _toggleSettingsPanel() {
    setState(() {
      _isSettingsPanelOpen = !_isSettingsPanelOpen;
    });
  }

  void _calculateCurrentDisplaySize([BoxConstraints? constraints]) {
    // LayoutBuilder의 constraints를 사용하거나 MediaQuery를 사용
    double screenWidth, screenHeight;

    if (constraints != null) {
      // LayoutBuilder의 constraints는 이미 패딩이 적용된 공간
      screenWidth = constraints.maxWidth;
      screenHeight = constraints.maxHeight;
    } else {
      // MediaQuery를 사용할 때는 패딩을 제외
      screenWidth =
          MediaQuery.of(context).size.width - (_paddingValue * 2); // 좌우 패딩 제외
      screenHeight =
          MediaQuery.of(context).size.height - (_paddingValue * 2); // 상하 패딩 제외
    }

    if (_mediaWidth != null && _mediaHeight != null) {
      final aspectRatio = _mediaWidth! / _mediaHeight!;

      // BoxFit.contain으로 표시되는 크기 계산
      double displayWidth, displayHeight;

      if (screenWidth / screenHeight > aspectRatio) {
        // 사용 가능한 공간이 더 넓음 - 높이에 맞춤
        displayHeight = screenHeight;
        displayWidth = screenHeight * aspectRatio;
      } else {
        // 사용 가능한 공간이 더 좁음 - 너비에 맞춤
        displayWidth = screenWidth;
        displayHeight = screenWidth / aspectRatio;
      }

      // 크기가 실제로 변경되었는지 확인하고, 변경된 경우에만 업데이트
      if (_currentDisplayWidth != displayWidth ||
          _currentDisplayHeight != displayHeight) {
        setState(() {
          _currentDisplayWidth = displayWidth;
          _currentDisplayHeight = displayHeight;
          _isResizing = true; // 창 크기 변화 중임을 표시
        });

        // 리사이징 완료 후 플래그 해제
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isResizing = false;
            });
          }
        });
      }
    }
  }

  void _getMediaDimensions(String path) async {
    if (_isVideo) {
      // 비디오의 경우 media_kit을 사용하여 실제 메타데이터에서 크기 정보 가져오기
      try {
        final media = Media(path);
        await _player.open(media);
        await _player.setPlaylistMode(PlaylistMode.single);

        // 비디오 메타데이터가 로드될 때까지 대기
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

  void _parseImageSizeManually(List<int> bytes) {
    if (bytes.length < 24) return;

    try {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        // JPEG 파일 크기 파싱
        int i = 2;
        while (i < bytes.length - 9) {
          if (bytes[i] == 0xFF && bytes[i + 1] == 0xC0) {
            // SOF0 마커 (Start of Frame)
            if (i + 9 < bytes.length) {
              setState(() {
                _mediaHeight = (bytes[i + 5] << 8) | bytes[i + 6];
                _mediaWidth = (bytes[i + 7] << 8) | bytes[i + 8];
              });
            }
            break;
          }
          i++;
        }
      } else if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        // PNG 파일 크기 파싱
        if (bytes.length > 32) {
          setState(() {
            _mediaWidth =
                (bytes[16] << 24) |
                (bytes[17] << 16) |
                (bytes[18] << 8) |
                bytes[19];
            _mediaHeight =
                (bytes[20] << 24) |
                (bytes[21] << 16) |
                (bytes[22] << 8) |
                bytes[23];
          });
        }
      } else if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        // GIF 파일 크기 파싱
        if (bytes.length > 10) {
          setState(() {
            _mediaWidth = bytes[6] | (bytes[7] << 8);
            _mediaHeight = bytes[8] | (bytes[9] << 8);
          });
        }
      }
    } catch (e) {
      // 수동 파싱 중 오류: 무시
    }
  }

  void _addCropRegion() {
    if (_mediaWidth != null &&
        _mediaHeight != null &&
        _currentDisplayWidth != null &&
        _currentDisplayHeight != null) {
      // 기본 크기를 200x200으로 설정 (원본 미디어 크기 대비 상대값)
      final cropWidth = 200.0 / _mediaWidth!;
      final cropHeight = 200.0 / _mediaHeight!;

      // 미디어 영역의 중앙에 크롭 영역 배치 (상대 좌표)
      final cropLeft = 0.5 - (cropWidth / 2);
      final cropTop = 0.5 - (cropHeight / 2);

      final newRegion = CropRegion(
        name: '영역 $_nextRegionId',
        x: cropLeft,
        y: cropTop,
        width: cropWidth,
        height: cropHeight,
        color: Utils.generateRandomColor(),
      );

      setState(() {
        _cropRegions.add(newRegion);
        _nextRegionId++;
      });
    }
  }

  void _updateCropRegion(int index, CropRegion newRegion) {
    setState(() {
      _cropRegions[index] = newRegion;
    });
  }

  void _updateCropRegionFromList(int index, String value, String field) {
    final region = _cropRegions[index];

    double? newValue;
    if (field == 'x') {
      newValue = double.tryParse(value);
      if (newValue != null) {
        // 입력된 픽셀 값을 상대 좌표로 변환
        _updateCropRegion(index, region.copyWith(x: newValue / _mediaWidth!));
      }
    } else if (field == 'y') {
      newValue = double.tryParse(value);
      if (newValue != null) {
        // 입력된 픽셀 값을 상대 좌표로 변환
        _updateCropRegion(index, region.copyWith(y: newValue / _mediaHeight!));
      }
    } else if (field == 'width') {
      newValue = double.tryParse(value);
      if (newValue != null && newValue > 0) {
        // 입력된 픽셀 값을 상대 좌표로 변환
        _updateCropRegion(
          index,
          region.copyWith(width: newValue / _mediaWidth!),
        );
      }
    } else if (field == 'height') {
      newValue = double.tryParse(value);
      if (newValue != null && newValue > 0) {
        // 입력된 픽셀 값을 상대 좌표로 변환
        _updateCropRegion(
          index,
          region.copyWith(height: newValue / _mediaHeight!),
        );
      }
    }
  }

  /// 모든 크롭 영역에 대해 크롭 작업 수행
  void _cropAllRegions() {
    if (_cropRegions.isEmpty) {
      // 크롭 영역이 없으면 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('크롭할 영역이 없습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 크롭 작업 수행 (현재는 콘솔에 정보만 출력)
    print('=== 모든 크롭 영역 크롭 시작 ===');
    for (int i = 0; i < _cropRegions.length; i++) {
      final region = _cropRegions[i];
      final pixelX = (region.x * _mediaWidth!).toInt();
      final pixelY = (region.y * _mediaHeight!).toInt();
      final pixelWidth = (region.width * _mediaWidth!).toInt();
      final pixelHeight = (region.height * _mediaHeight!).toInt();

      print('영역 ${i + 1}: ${region.name}');
      print('  위치: ($pixelX, $pixelY)');
      print('  크기: ${pixelWidth}x$pixelHeight');
      print('  색상: ${region.color}');
    }

    // 성공 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_cropRegions.length}개 영역 크롭 완료!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _cropRegion() {
    print('=== 크롭 영역 크롭 시작 ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(_paddingValue),
        child: Stack(
          children: [
            // 미디어 영역 (전체 화면)
            DropTarget(
              onDragDone: (detail) {
                if (detail.files.isNotEmpty) {
                  final file = detail.files.first;
                  final path = file.path;
                  setState(() {
                    _mediaPath = path;
                    _isVideo = Utils.isVideoFile(path);
                  });

                  if (_isVideo) {
                    _player.open(Media(path));
                  }

                  // 미디어 크기 정보 가져오기
                  _getMediaDimensions(path);
                }
              },
              onDragEntered: (detail) {
                setState(() {
                  _isDragging = true;
                });
              },
              onDragExited: (detail) {
                setState(() {
                  _isDragging = false;
                });
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
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

                  return SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, innerConstraints) {
                        return _buildMediaContent(innerConstraints);
                      },
                    ),
                  );
                },
              ),
            ),
            // 설정 패널 (오른쪽 상단에 겹쳐서 표시)
            if (_mediaPath != null)
              Positioned(
                top: 20,
                right: 20,
                width: _isSettingsPanelOpen ? 400 : null, // 너비를 400으로 설정
                height: _isSettingsPanelOpen ? 800 : null, // 높이를 800으로 설정
                child: _isSettingsPanelOpen
                    ? _buildSettingsPanel()
                    : _buildToggleButton(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: IconButton(
        onPressed: _toggleSettingsPanel,
        icon: const Icon(Icons.settings, size: 16),
        tooltip: '설정 패널 열기',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        style: IconButton.styleFrom(
          backgroundColor: Colors.blue[100],
          foregroundColor: Colors.blue[700],
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

  Widget _buildMediaContent(BoxConstraints constraints) {
    if (_mediaPath == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(
            color: Colors.grey[300]!,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: _isDragging
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload, size: 64, color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      '파일을 여기에 드래그하세요',
                      style: TextStyle(fontSize: 18, color: Colors.blue),
                    ),
                  ],
                ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '비디오 또는 이미지 파일을 드래그하세요',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
      );
    }

    Widget mediaWidget;
    if (_isVideo) {
      mediaWidget = Video(
        controller: _controller,
        fit: BoxFit.contain,
        fill: Colors.transparent,
        controls: media_kit_video_controls.NoVideoControls,
      );
    } else {
      mediaWidget = Image.file(File(_mediaPath!), fit: BoxFit.contain);
    }

    return Stack(
      children: [
        // 메인 미디어 위젯
        Positioned.fill(child: mediaWidget),
        // 크기 정보 박스를 오른쪽 하단에 배치
        if (_mediaWidth != null && _mediaHeight != null)
          Positioned(bottom: 20, right: 20, child: _buildSizeInfoBox()),
        // 미디어 영역을 나타내는 Container (크롭 영역을 위한 경계)
        if (_currentDisplayWidth != null && _currentDisplayHeight != null)
          Positioned(
            left: (constraints.maxWidth - _currentDisplayWidth!) / 2,
            top: (constraints.maxHeight - _currentDisplayHeight!) / 2,
            child: SizedBox(
              width: _currentDisplayWidth!,
              height: _currentDisplayHeight!,
              child: Stack(
                children: [
                  // CropRegion TransformableBox들
                  ..._cropRegions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final region = entry.value;

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

  Widget _buildSizeInfoBox() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '원본 크기',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_mediaWidth ?? 0} × ${_mediaHeight ?? 0}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '현재 크기',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_currentDisplayWidth?.toStringAsFixed(0) ?? '0'} × ${_currentDisplayHeight?.toStringAsFixed(0) ?? '0'}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}
