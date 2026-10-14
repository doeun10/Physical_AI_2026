-- PawFeeder AI 하드웨어 부품 DB: 테이블 구조
-- 보고서 report/hardware_parts.md 의 내용을 표로 나눠 저장합니다.
--
--   hw_part_groups   부품 그룹 (처리 장치, 센서, 구동부 ...)
--   hw_parts         부품 목록 (전압, 전류, 통신 방식)
--   hw_comm_methods  통신 방식 (Wi-Fi, BLE, I2C, SPI ...)
--   hw_connections   부품 관계도의 연결선 (어떤 부품이 어떤 통신 방식으로 연결되는지)
--   hw_power_rails   전원 레일 (12V / 5V / 3.3V)
--   project_reports  보고서 원문 (Markdown)
--   hw_connection_map (뷰) 연결선을 부품 이름으로 풀어서 보여줌

-- 1) 부품 그룹
create table if not exists public.hw_part_groups (
  code        text primary key,
  name        text not null,
  description text,
  sort_order  smallint not null
);
comment on table public.hw_part_groups is '부품 그룹: 처리 장치, 센서, 구동부, 사용자 인터페이스, 전원부, 외부 장치';

-- 2) 부품
create table if not exists public.hw_parts (
  id             smallint primary key,
  code           text not null unique,
  name           text not null,
  group_code     text not null references public.hw_part_groups (code),
  model          text,
  role           text not null,
  voltage_v      numeric(4,1),
  voltage_range  text,
  power_rail     text check (power_rail in ('12V', '5V', '3.3V')),
  current_typ_ma numeric(8,3),
  current_max_ma numeric(8,3),
  interfaces     text,
  necessity      text check (necessity in ('필수', '권장', '선택')),
  is_onboard     boolean not null default true,
  note           text
);
comment on table  public.hw_parts is '급식기에 들어가는 하드웨어 부품 (전압, 전류, 통신 방식 포함). 외부 장치(스마트폰, 서버)는 is_onboard = false';
comment on column public.hw_parts.code           is '부품 식별 코드 (연결선 테이블에서 참조)';
comment on column public.hw_parts.voltage_v      is '이 제품에서 실제로 공급하는 전압 (V)';
comment on column public.hw_parts.voltage_range  is '데이터시트상 동작 전압 범위';
comment on column public.hw_parts.power_rail     is '전원을 받는 레일 (hw_power_rails.voltage)';
comment on column public.hw_parts.current_typ_ma is '평상시 전류 (mA)';
comment on column public.hw_parts.current_max_ma is '최대 전류 (mA)';
comment on column public.hw_parts.interfaces     is '사용하는 통신 방식';
comment on column public.hw_parts.necessity      is '필수 / 권장 / 선택';

-- 3) 통신 방식
create table if not exists public.hw_comm_methods (
  code        text primary key,
  name        text not null,
  scope       text not null check (scope in ('기기 밖', '기기 안')),
  medium      text not null check (medium in ('무선', '유선')),
  speed       text,
  range_desc  text,
  description text not null,
  is_used     boolean not null,
  reason      text
);
comment on table  public.hw_comm_methods is '통신 방식 정의. is_used = false 는 검토했지만 쓰지 않는 방식 (ESP-NOW, Ethernet)';
comment on column public.hw_comm_methods.reason is '쓰거나 쓰지 않는 이유';

-- 4) 부품 관계도 (연결선)
create table if not exists public.hw_connections (
  id          smallint primary key,
  from_part   text not null references public.hw_parts (code),
  to_part     text not null references public.hw_parts (code),
  comm_method text not null references public.hw_comm_methods (code),
  direction   text not null check (direction in ('단방향', '양방향')),
  data_desc   text not null
);
comment on table  public.hw_connections is '부품 관계도의 연결선: from_part 에서 to_part 로 어떤 통신 방식으로 무엇을 보내는지';
comment on column public.hw_connections.data_desc is '오가는 데이터';

-- 5) 전원 레일
create table if not exists public.hw_power_rails (
  voltage     text primary key,
  source_part text not null references public.hw_parts (code),
  capacity_a  numeric(4,2) not null,
  max_load_a  numeric(4,2) not null,
  max_power_w numeric(5,1) not null,
  consumers   text not null,
  sort_order  smallint not null
);
comment on table  public.hw_power_rails is '전원 레일별 용량과 최대 부하 (가장 나쁜 경우 기준)';
comment on column public.hw_power_rails.capacity_a is '공급 장치 용량 (A)';
comment on column public.hw_power_rails.max_load_a is '연결된 부품의 최대 전류 합 (A)';

-- 6) 보고서 원문
create table if not exists public.project_reports (
  id         bigserial primary key,
  file_path  text not null unique,
  title      text not null,
  doc_type   text not null,
  version    text,
  written_on date,
  content    text not null,
  updated_at timestamptz not null default now()
);
comment on table public.project_reports is '과제 보고서 원문 (Markdown). 챗봇 검색용 조각은 documents 테이블에 따로 저장';

-- 7) 관계도 보기용 뷰
create or replace view public.hw_connection_map
with (security_invoker = true) as
select c.id,
       f.name        as from_name,
       t.name        as to_name,
       m.name        as comm_method,
       m.medium,
       c.direction,
       c.data_desc
from public.hw_connections c
join public.hw_parts f        on f.code = c.from_part
join public.hw_parts t        on t.code = c.to_part
join public.hw_comm_methods m on m.code = c.comm_method
order by c.id;
comment on view public.hw_connection_map is '부품 관계도를 사람이 읽기 쉽게 부품 이름으로 풀어 놓은 뷰';

-- 8) RLS: documents 와 같이 공개 키로는 접근 불가, 서버와 대시보드(service_role)만 접근
alter table public.hw_part_groups  enable row level security;
alter table public.hw_parts        enable row level security;
alter table public.hw_comm_methods enable row level security;
alter table public.hw_connections  enable row level security;
alter table public.hw_power_rails  enable row level security;
alter table public.project_reports enable row level security;
