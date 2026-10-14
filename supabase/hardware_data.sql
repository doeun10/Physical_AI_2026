-- PawFeeder AI 하드웨어 부품 DB: 데이터 (report/hardware_parts.md 기준)
-- hardware_schema.sql 실행 후 실행하세요. 다시 실행하면 내용을 지우고 새로 넣습니다.

truncate public.hw_connections, public.hw_power_rails, public.hw_parts, public.hw_comm_methods, public.hw_part_groups;

insert into public.hw_part_groups (code, name, description, sort_order) values
  ('processor', '처리 장치',           '두뇌: AI로 얼굴을 알아보고 모든 부품에 명령을 내림',        1),
  ('sensor',    '센서',                '눈과 감각: 누가 왔는지, 얼마나 가까운지, 사료가 얼마나 있는지 측정', 2),
  ('actuator',  '구동부',              '손과 발: 사료를 내보내고 그릇 덮개를 여닫음',               3),
  ('ui',        '사용자 인터페이스',   '얼굴: 사용자에게 상태를 보여주고 입력을 받음',              4),
  ('power',     '전원부',              '심장: 부품마다 필요한 전압을 만들어 공급',                  5),
  ('external',  '외부 장치',           '기기 밖에서 연결되는 장치 (부품 수에 포함하지 않음)',       6);

insert into public.hw_parts
  (id, code, name, group_code, model, role, voltage_v, voltage_range, power_rail, current_typ_ma, current_max_ma, interfaces, necessity, is_onboard, note) values
  ( 1, 'RK3566',   'AI 프로세서 (SBC)', 'processor', 'Rockchip RK3566 SoM',              '카메라 영상으로 AI 얼굴 인식, Wi-Fi로 서버 통신, BLE로 초기 설정', 5.0, '5V (보드 입력)',              '5V',   750,    2000, 'MIPI CSI-2, UART, Wi-Fi, BLE', '필수', true, 'NPU 약 0.8 TOPS. 평상시 0.5~1A'),
  ( 2, 'ESP32S3',  '제어 MCU',          'processor', 'Espressif ESP32-S3-WROOM-1',       '모터, 센서, LCD, 버튼 등 주변 부품을 실시간 제어',                3.3, '3.0~3.6V',                    '3.3V', 70,     250,  'UART, I2C, SPI, PWM, GPIO',    '필수', true, '무선은 RK3566이 맡으므로 Wi-Fi/BLE 끔. 평상시 40~100mA'),
  ( 3, 'CAMERA',   '카메라',            'sensor',    '2MP RGB-IR 글로벌 셔터 (OmniVision OG02B 계열)', '반려동물 얼굴 촬영 (주간 컬러, 야간 적외선)',        null, '2.8V / 1.8V / 1.2V (모듈 내장 레귤레이터)', '5V', 100, 150, 'MIPI CSI-2, SCCB(I2C)', '필수', true, 'RK3566 보드에서 전원 공급. 글로벌 셔터라 움직여도 번지지 않음'),
  ( 4, 'IR_LED',   'IR LED 보조조명',   'sensor',    '850nm 적외선 LED + MOSFET',         '어두운 곳에서 얼굴 촬영을 위한 적외선 조명',                     5.0, '5V (LED 1개당 Vf 약 1.5V)',   '5V',   0,      300,  'PWM',                          '필수', true, null),
  ( 5, 'PIR',      'PIR 인체감지 센서', 'sensor',    'AM312',                             '초저전력으로 움직임을 감지해 시스템을 깨움',                     3.3, '2.7~12V',                     '3.3V', 0.015,  0.015,'GPIO',                         '권장', true, 'ToF만으로 대체 가능하지만 대기 전력·발열을 줄임'),
  ( 6, 'TOF',      'ToF 거리 센서',     'sensor',    'ST VL53L1X',                        '30cm 안으로 접근했는지 거리 측정 (최대 4m)',                     3.3, '2.6~3.5V',                    '3.3V', 0.005,  20,   'I2C',                          '필수', true, 'I2C 주소를 0x29 → 0x30으로 변경'),
  ( 7, 'LOADCELL', '로드셀',            'sensor',    '3kg 빔형 로드셀',                   '그릇 무게 측정 (토출량, 섭취량 계산)',                           5.0, '3.3~5V (여기전압)',           '5V',   4,      5,    '아날로그',                     '필수', true, 'HX711이 여기전압 공급'),
  ( 8, 'HX711',    '로드셀 ADC',        'sensor',    'Avia HX711',                        '로드셀의 미세 신호를 증폭해 24bit 디지털 값으로 변환',          5.0, '2.6~5.5V (아날로그 5V / 디지털 3.3V)', '5V', 1.5, 1.5, '2선 시리얼 (PD_SCK, DOUT)', '필수', true, null),
  ( 9, 'LEVEL',    '사료 잔량 센서',    'sensor',    'ST VL53L0X',                        '사료통 표면까지 거리로 남은 양 추정, 사료 부족 알림',           3.3, '2.6~3.5V',                    '3.3V', 0.005,  19,   'I2C',                          '권장', true, null),
  (10, 'RTC',      '실시간 시계 (RTC)', 'sensor',    'Maxim DS3231 + CR2032',             '전원·인터넷이 끊겨도 현재 시각 유지 (오프라인 급여)',           3.3, '2.3~5.5V',                    '3.3V', 0.2,    0.2,  'I2C',                          '권장', true, null),
  (11, 'STEPPER',  '스텝 모터',         'actuator',  'NEMA17 (17HS4401급)',               '디스펜서(나선형 스크루)를 회전시켜 정량 토출',                   12.0,'12V (드라이버 경유)',         '12V',  0,      1700, '드라이버 구동',                '필수', true, '회전 각도 = 사료량'),
  (12, 'TMC2209',  '스텝 모터 드라이버','actuator',  'Trinamic TMC2209',                  'MCU 신호를 모터 구동 전류로 변환, 저소음 구동, 막힘 감지',       12.0,'모터 4.75~29V / 로직 3.3~5V', '12V',  null,   2000, 'STEP/DIR, UART, GPIO(DIAG)',   '필수', true, 'StallGuard로 토출구 막힘 감지'),
  (13, 'SERVO',    '서보 모터',         'actuator',  'TowerPro MG90S',                    '그릇 덮개 개폐 (다른 개체가 남은 사료를 먹지 못하게 함)',       5.0, '4.8~6V',                      '5V',   10,     700,  'PWM 50Hz',                     '필수', true, '동작 시 약 200~400mA'),
  (14, 'LCD',      'TFT LCD',           'ui',        '1.69인치 240×280 (ST7789)',         '섭취량, 다음 급여 시간, 잔량, 오류 표시',                       3.3, '3.3V',                        '3.3V', 5,      50,   'SPI, PWM(백라이트)',           '필수', true, '평소 백라이트 꺼짐, 버튼·오류 시에만 켬'),
  (15, 'BUTTON',   '택트 버튼',         'ui',        '택트 스위치',                       '화면 켜기, 수동 급여, Wi-Fi 재설정',                            3.3, '3.3V (풀업)',                 '3.3V', 0,      0,    'GPIO',                         '필수', true, null),
  (16, 'ADAPTER',  'DC 어댑터',         'power',     '12V 4A (KC 인증)',                  'AC 220V를 DC 12V로 변환, 전체 전원 공급',                       12.0,'입력 AC 220V',                null,   null,   4000, null,                           '필수', true, '48W, 입력단 PTC 퓨즈·역전압 방지 다이오드'),
  (17, 'BUCK',     '벅 컨버터',         'power',     'XL4015급 12V→5V',                   '12V를 5V로 낮춤',                                                5.0, '입력 12V',                    '12V',  null,   5000, null,                           '필수', true, null),
  (18, 'LDO',      'LDO 레귤레이터',    'power',     'AMS1117-3.3',                       '5V를 3.3V로 낮춤',                                               3.3, '입력 5V',                     '5V',   null,   1000, null,                           '필수', true, null),
  (19, 'PHONE',    '사용자 스마트폰',   'external',  '앱',                                '처음 설치할 때 BLE로 Wi-Fi 정보 전달',                          null,null,                          null,   null,   null, 'Bluetooth (BLE)',              null,  false, null),
  (20, 'CLOUD',    '클라우드 서버',     'external',  'AWS IoT Core',                      '섭취 기록 저장, 푸시 알림, 펌웨어 업데이트',                    null,null,                          null,   null,   null, 'Wi-Fi + MQTT over TLS',        null,  false, null);

insert into public.hw_comm_methods (code, name, scope, medium, speed, range_desc, description, is_used, reason) values
  ('WIFI',     'Wi-Fi (MQTT over TLS)', '기기 밖', '무선', '수십~수백 Mbps', '실내 약 30~50m', '공유기를 거쳐 인터넷에 연결',              true,  '가정마다 공유기가 있고 서버와 직접 통신 가능'),
  ('BLE',      'Bluetooth (BLE)',       '기기 밖', '무선', '약 1~2 Mbps',    '약 10m',         '가까운 기기끼리 저전력으로 1:1 연결',      true,  '화면·키보드 없이 폰으로 Wi-Fi 설정 가능'),
  ('ESPNOW',   'ESP-NOW',               '기기 밖', '무선', '약 1 Mbps',      '약 100m 이상 (실외)', 'Espressif 자체 방식. 공유기 없이 ESP 기기끼리 직접 통신', false, '지금은 기기가 하나라 불필요. 급수기·체중계 추가 시 확장용'),
  ('ETHERNET', 'Ethernet',              '기기 밖', '유선', '100 Mbps~1 Gbps','케이블 최대 100m', 'LAN 케이블 유선 연결',                     false, '바닥에 두는 제품이라 케이블이 걸리적거리고 반려동물이 씹을 위험'),
  ('MIPI',     'MIPI CSI-2',            '기기 안', '유선', '고속 (Gbps급)',  '기판 안',         '카메라 영상 전용 고속 통신',               true,  '2MP 영상을 빠르게 전송'),
  ('SCCB',     'SCCB (I2C 호환)',       '기기 안', '유선', '최대 400 kbps',  '기판 안',         '카메라 설정값 전송',                       true,  '카메라 센서 표준 설정 방식'),
  ('UART',     'UART',                  '기기 안', '유선', '115.2 kbps~',    '기판 안',         'TX/RX 두 선으로 1:1 통신',                 true,  '두 칩 사이 명령 전달에 간단함'),
  ('I2C',      'I2C',                   '기기 안', '유선', '최대 400 kbps',  '기판 안',         '선 2개(SDA, SCL)에 여러 부품을 주소로 구분해 연결', true, '센서 여러 개를 선 2개로 연결'),
  ('SPI',      'SPI',                   '기기 안', '유선', '수십 Mbps',      '기판 안',         'SCK, MOSI, CS, DC 4선 고속 통신',          true,  '화면 데이터를 빠르게 전송'),
  ('HX711_SERIAL', '2선 시리얼 (HX711)','기기 안', '유선', '수십 kbps',      '기판 안',         'PD_SCK, DOUT 두 선을 쓰는 HX711 전용 방식', true, 'HX711 전용'),
  ('STEPDIR',  'STEP/DIR',              '기기 안', '유선', '펄스',           '기판 안',         '펄스 1개에 한 칸 회전, DIR로 방향 지정',    true,  '펄스 수로 회전 각도를 정확히 지정'),
  ('PWM',      'PWM',                   '기기 안', '유선', '50Hz~수십 kHz',  '기판 안',         '켜짐/꺼짐 비율로 세기나 각도 전달',         true,  '서보 각도, LED 밝기를 간단히 조절'),
  ('GPIO',     'GPIO',                  '기기 안', '유선', '-',              '기판 안',         '켜짐/꺼짐 신호 하나',                       true,  '감지됨/눌림만 알리면 됨'),
  ('ANALOG',   '아날로그 신호',         '기기 안', '유선', '-',              '기판 안',         '전압 크기 자체가 값 (mV 수준)',             true,  '로드셀 출력 방식'),
  ('MOTOR',    '모터 구동선',           '기기 안', '유선', '-',              '기판 안',         '드라이버가 모터 코일에 직접 전류를 흘림 (데이터 통신 아님)', true, '스텝 모터 구동');

insert into public.hw_connections (id, from_part, to_part, comm_method, direction, data_desc) values
  ( 1, 'PHONE',    'RK3566',   'BLE',          '단방향', 'Wi-Fi 이름·비밀번호 (처음 설치할 때 1회)'),
  ( 2, 'RK3566',   'CLOUD',    'WIFI',         '양방향', '섭취 기록, 알림 / 펌웨어 업데이트(OTA), 급여 스케줄'),
  ( 3, 'CAMERA',   'RK3566',   'MIPI',         '단방향', '얼굴 영상'),
  ( 4, 'RK3566',   'CAMERA',   'SCCB',         '단방향', '노출, 해상도 등 카메라 설정'),
  ( 5, 'RK3566',   'ESP32S3',  'UART',         '양방향', '명령 "A에게 25g" / 결과 "토출 완료 24.8g", 센서 상태'),
  ( 6, 'TOF',      'ESP32S3',  'I2C',          '단방향', '접근 거리 (30cm 판정)'),
  ( 7, 'LEVEL',    'ESP32S3',  'I2C',          '단방향', '사료통 잔량 거리'),
  ( 8, 'RTC',      'ESP32S3',  'I2C',          '양방향', '현재 시각 읽기 / 시각 맞추기'),
  ( 9, 'PIR',      'ESP32S3',  'GPIO',         '단방향', '움직임 감지 인터럽트'),
  (10, 'BUTTON',   'ESP32S3',  'GPIO',         '단방향', '버튼 눌림 인터럽트'),
  (11, 'LOADCELL', 'HX711',    'ANALOG',       '단방향', '무게에 따른 미세 전압 (mV)'),
  (12, 'HX711',    'ESP32S3',  'HX711_SERIAL', '단방향', '24bit 무게 값'),
  (13, 'ESP32S3',  'TMC2209',  'STEPDIR',      '단방향', '회전 펄스와 방향'),
  (14, 'ESP32S3',  'TMC2209',  'UART',         '양방향', '전류·소음 모드 설정, 상태 읽기'),
  (15, 'TMC2209',  'ESP32S3',  'GPIO',         '단방향', 'DIAG: 모터 걸림(토출구 막힘) 알림'),
  (16, 'TMC2209',  'STEPPER',  'MOTOR',        '단방향', '코일 구동 전류'),
  (17, 'ESP32S3',  'SERVO',    'PWM',          '단방향', '덮개 각도 (50Hz, 펄스 폭 1~2ms)'),
  (18, 'ESP32S3',  'IR_LED',   'PWM',          '단방향', '적외선 조명 밝기 (MOSFET 경유)'),
  (19, 'ESP32S3',  'LCD',      'SPI',          '단방향', '화면 데이터'),
  (20, 'ESP32S3',  'LCD',      'PWM',          '단방향', '백라이트 밝기');

insert into public.hw_power_rails (voltage, source_part, capacity_a, max_load_a, max_power_w, consumers, sort_order) values
  ('12V',  'ADAPTER', 4.00, 1.50, 18.0, 'TMC2209 → 스텝 모터',                                   1),
  ('5V',   'BUCK',    5.00, 3.00, 15.0, 'RK3566(+카메라), 서보 모터, IR LED, HX711(+로드셀)',     2),
  ('3.3V', 'LDO',     1.00, 0.35,  1.2, 'ESP32-S3, VL53L1X, VL53L0X, PIR, DS3231, TFT LCD, 버튼', 3);
