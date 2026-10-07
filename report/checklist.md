# 🐾 반려동물 자동 급식기 Edge AI 데이터 전처리 현장 조사 체크리스트

## 1. 조명 및 광원 환경 (Lighting Environment)
- **[1-1] 주 광원 종류 (중복 선택 가능)**
  - [ ] 자연광 (창문 direct/indirect)
  - [ ] 형광등 (FL)
  - [ ] LED (백색/주광색)
  - [ ] 백열등/할로겐 (전구색)
  - [ ] 야간 무드등 / 암전 상태
  * 이유: 광원 종류에 따라 색온도(White Balance) 보정 방식과 야간 IR 전환 스레시홀드 설정 기준이 달라집니다.

- **[1-2] 조도(Lux) 수준 (주간 기준)**
  - [ ] 매우 밝음 (> 1,000 Lux - 직사광선 침투)
  - [ ] 보통 (300 ~ 1,000 Lux - 일반 거실/실내)
  - [ ] 어두움 (50 ~ 300 Lux - 복도/그늘진 곳)
  - [ ] 극심한 저조도 (< 50 Lux)
  * 이유: 조도 수준에 따라 노이즈 제거(Denoising) 필터의 강도 및 Exposure/Gain 제어 알고리즘이 결정됩니다.

- **[1-3] 플리커(Flicker) 현상 유무**
  - [ ] 없음 (눈/프레임 상 떨림 없음)
  - [ ] 있음 (형광등/저가 LED로 인한 영상 띠 현상)
  * 이유: 50Hz/60Hz 플리커 발생 시 전처리 단계에서 Anti-flicker 알고리즘 또는 temporal smoothing 필터 적용이 필수적입니다.

- **[1-4] 광원 변동성 (Dynamic Range)**
  - [ ] 일정함 (24시간 인공조명 유지)
  - [ ] 시간에 따른 변화 심함 (주/야간 차이 큼)
  - [ ] 역광(Backlight) 존재 (배경에 창문 배치)
  * 이유: 역광 및 조명 변화가 심한 경우 CLAHE(Contrast Limited Adaptive Histogram Equalization)나 Gamma 보정이 필수적입니다.

---

## 2. 카메라 및 센서 사양 (Camera & Sensor Specs)
- **[2-1] 카메라 설치 높이 및 각도**
  - 설치 높이 (지면으로부터 센서 위치): [   ] cm
  - 화각 기울기 (Tilt Angle): [   ] 도 (아이레벨 / 앙마시 / 부감)
  * 이유: 카메라 시점에 따른 원근감 및 기하학적 왜곡을 보정하기 위해 Affine/Perspective Transform 파이프라인 수립이 필요합니다.

- **[2-2] 카메라 센서 및 렌즈 특성**
  - [ ] Wide-angle (광각/어렌즈 - 왜곡 있음)
  - [ ] Standard (일반 화각)
  - [ ] Dual Mode (RGB + IR Cut Filter 자동 전환)
  * 이유: 광각 렌즈 왜곡(Lens Distortion)의 경우 계수값을 기반으로 전처리 시 왜곡 펴기(Undistort)를 최우선 실행해야 합니다.

- **[2-3] 야간 촬영 모드 지원**
  - [ ] IR LED 보조조명 탑재 (흑백 모드 전환)
  - [ ] low-light RGB 센서 (컬러 유지 시도)
  * 이유: IR 모드 전환 시 RGB 3채널 데이터가 단일 채널(Grayscale) 상태로 변하므로, 입력 데이터 채널 맞춤 알고리즘이 달라집니다.

---

## 3. 피사체(반려동물) 및 환경 모션 특성 (Target & Motion)
- **[3-1] 피사체 이동 속도 및 접근 패턴**
  - [ ] 서서히 접근 (일반적인 식사 접근)
  - [ ] 뛰어옴/빠른 움직임 (뛰쳐나오는 행동)
  - [ ] 식기 근처에서 지속적인 고개 털기/움직임
  * 이유: 빠른 움직임으로 인한 모션블러(Motion Blur) 정도를 측정하여 Deblurring 필터 또는 Motion Blur frame rejection 로직을 추가해야 합니다.

- **[3-2] 피사체 수 및 품종/외형 특성**
  - 대상 개체 수: [   ] 마리
  - [ ] 단모종 (장모 대비 이목구비 명확)
  - [ ] 장모종/눈을 가리는 털
  - [ ] 검은색/단색 피사체 (이목구비 음영 구분 어려움)
  * 이유: 피사체의 털 색상 및 장모 여부에 따라 Edge Detection 및 Sharpening 필터 매개변수가 달라집니다.

- **[3-3] 이물질 및 가림(Occlusion) 유무**
  - [ ] 사료 그릇/급식기 구조물에 의한 가림
  - [ ] 타 개체에 의한 오버랩(Inter-animal occlusion)
  - [ ] 사료 가루/침으로 인한 렌즈 오염 가능성
  * 이유: 부분 가림 현상(Partial Occlusion) 비율에 따른 ROI(Region of Interest) Crop 및 Bounding Box 확장 비율을 계산해야 합니다.

---

## 4. Edge AI 시스템 제한 조건 (Edge Device Constraints)
- **[4-1] 입력 해상도 및 FPS 설정**
  - 센서 원본 해상도: [ 1080p / 720p / VGA ]
  - 목표 전처리 해상도: [   ] x [   ] (예: 224x224, 112x112)
  - 처리 프레임 레이트: [   ] FPS
  * 이유: Edge NPU 메모리 및 추론 latency 제한에 맞춰 Resize 알고리즘(Bilinear vs Nearest vs Bicubic) 및 크롭 범위를 최적화해야 합니다.

- **[4-2] 연산 리소스 한계**
  - [ ] 극저전력 MCU (ESP32-S3 계열 - 수 ms 단위 전처리 한계)
  - [ ] 경량 NPU SoC (RK3566/NPU 계열 - 상대적으로 여유 있음)
  * 이유: 복잡한 OpenCV 전처리 연산(예: Gaussian Blur, Bilateral Filter)의 Edge 단 탑재 가능 여부를 판단하기 위함입니다.