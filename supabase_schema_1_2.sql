
-- Factory Manager V4 - Supabase Schema - Clean Version (Fixed)
-- Safe migration: no IF NOT EXISTS for policies

-- 1. Core accounts
create table if not exists accts (
  id bigint primary key,
  code text not null,
  name text not null,
  t text check (t in ('A','L','Q','I','X')),
  k text,
  cash boolean default false,
  cur text default 'EGP',
  created_at timestamptz default now()
);
create table if not exists wh (
  id bigint primary key,
  name text not null,
  created_at timestamptz default now()
);
create table if not exists items (
  id bigint primary key,
  name text not null,
  sku text,
  wh bigint references wh(id),
  unit text default 'قطعة',
  model text,
  buy numeric default 0,
  retail numeric default 0,
  wholesale numeric default 0,
  img text,
  val numeric default 0,
  created_at timestamptz default now()
);
create table if not exists item_stocks (
  id bigserial primary key,
  item_id bigint references items(id) on delete cascade,
  v text not null,
  qty numeric default 0,
  unique(item_id, v)
);
create table if not exists codes (
  id bigserial primary key,
  iid bigint references items(id) on delete cascade,
  v text not null,
  code text not null unique,
  created_at timestamptz default now(),
  unique(iid, v)
);
create table if not exists partners (
  id bigint primary key,
  name text not null,
  phone text,
  c int default 0,
  s int default 0,
  type text check (type in ('r','w')),
  gov text,
  city text,
  adr text,
  created_at timestamptz default now()
);
create table if not exists docs (
  id bigint primary key,
  t text check (t in ('sale','pur','sret','pret')),
  no text not null unique,
  pid bigint references partners(id),
  date date not null,
  ts bigint,
  cat text check (cat in ('mfg','sup')),
  dest bigint,
  total numeric default 0,
  disc numeric default 0,
  note text,
  img text,
  created_at timestamptz default now()
);
create table if not exists doc_lines (
  id bigserial primary key,
  doc_id bigint references docs(id) on delete cascade,
  iid bigint references items(id),
  name text,
  v text,
  qty numeric,
  price numeric,
  cost numeric,
  note text,
  unit text,
  sku text,
  model text,
  barcode text
);
create table if not exists po (
  id bigint primary key,
  no text not null unique,
  date date,
  ts bigint,
  iname text,
  wh bigint,
  desc_text text,
  st int default 0,
  mat_cost numeric default 0,
  wc numeric default 0,
  done date,
  created_at timestamptz default now()
);
create table if not exists po_subs (
  id bigserial primary key,
  po_id bigint references po(id) on delete cascade,
  v text,
  qty numeric
);
create table if not exists po_rec (
  id bigserial primary key,
  po_id bigint references po(id) on delete cascade,
  v text,
  qty numeric
);
create table if not exists po_mats (
  id bigserial primary key,
  po_id bigint references po(id) on delete cascade,
  iid bigint references items(id),
  qty numeric,
  cost numeric
);
create table if not exists po_expenses (
  id bigserial primary key,
  po_id bigint references po(id) on delete cascade,
  a bigint references accts(id),
  amt numeric,
  note text
);
create table if not exists vch (
  id bigint primary key,
  dir text check (dir in ('in','out')),
  no text not null unique,
  date date,
  ts bigint,
  title text,
  who text,
  total numeric,
  desc_text text,
  link text,
  img text,
  created_at timestamptz default now()
);
create table if not exists vch_ac (
  id bigserial primary key,
  vch_id bigint references vch(id) on delete cascade,
  a bigint references accts(id),
  amt numeric,
  cur text default 'EGP',
  fx numeric default 1
);
create table if not exists vch_alloc (
  id bigserial primary key,
  vch_id bigint references vch(id) on delete cascade,
  doc_id bigint references docs(id),
  amount numeric,
  unique(vch_id, doc_id)
);
create table if not exists je (
  id bigint primary key,
  no text unique,
  date date,
  ts bigint,
  desc_text text,
  created_at timestamptz default now()
);
create table if not exists ledger (
  id bigserial primary key,
  d date,
  ts bigint,
  ref text,
  desc_text text,
  a bigint references accts(id),
  dr numeric default 0,
  cr numeric default 0,
  pid bigint references partners(id),
  src text,
  rid bigint,
  fc numeric default 0,
  created_at timestamptz default now()
);
create index if not exists ledger_a_idx on ledger(a);
create index if not exists ledger_pid_idx on ledger(pid);
create index if not exists ledger_rid_idx on ledger(rid);
create table if not exists mv (
  id bigserial primary key,
  d date,
  ts bigint,
  iid bigint references items(id),
  v text,
  q numeric,
  val numeric,
  ref text,
  pid bigint references partners(id),
  rid bigint,
  src text
);
create index if not exists mv_iid_idx on mv(iid);
create table if not exists emp (
  id bigint primary key,
  name text,
  p1 text,
  p2 text,
  gov text,
  city text,
  adr text,
  perm text[],
  img text,
  created_at timestamptz default now()
);
create table if not exists wo (
  id bigint primary key,
  ref text,
  c numeric,
  desc_text text,
  po bigint references po(id),
  ts bigint,
  created_at timestamptz default now()
);
create table if not exists sync_queue (
  id bigserial primary key,
  client_id text not null,
  table_name text not null,
  op text check (op in ('insert','update','delete')),
  payload jsonb,
  status text default 'pending' check (status in ('pending','syncing','done','failed')),
  attempts int default 0,
  idempotency_key text unique not null,
  error text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create table if not exists idempotency_keys (
  key text primary key,
  response jsonb,
  created_at timestamptz default now()
);
create table if not exists curs (
  code text primary key
);
create table if not exists settings (
  key text primary key,
  value jsonb
);

-- RLS enable
alter table accts enable row level security;
alter table wh enable row level security;
alter table items enable row level security;
alter table item_stocks enable row level security;
alter table codes enable row level security;
alter table partners enable row level security;
alter table docs enable row level security;
alter table doc_lines enable row level security;
alter table po enable row level security;
alter table po_subs enable row level security;
alter table po_rec enable row level security;
alter table po_mats enable row level security;
alter table po_expenses enable row level security;
alter table vch enable row level security;
alter table vch_ac enable row level security;
alter table vch_alloc enable row level security;
alter table je enable row level security;
alter table ledger enable row level security;
alter table mv enable row level security;
alter table emp enable row level security;
alter table wo enable row level security;
alter table sync_queue enable row level security;
alter table idempotency_keys enable row level security;

-- Drop existing policies if exist, then create (Postgres doesn't support IF NOT EXISTS for policies)
do $$ 
declare t text;
begin
  for t in select unnest(array['accts','wh','items','item_stocks','codes','partners','docs','doc_lines','po','po_subs','po_rec','po_mats','po_expenses','vch','vch_ac','vch_alloc','je','ledger','mv','emp','wo','sync_queue','idempotency_keys','curs','settings'])
  loop
    execute format('drop policy if exists "allow all" on %I', t);
    execute format('create policy "allow all" on %I for all using (true) with check (true)', t);
  end loop;
end $$;

-- Seed
insert into curs(code) values ('EGP'),('USD'),('EUR'),('SAR') on conflict do nothing;
insert into accts(id,code,name,t,k,cash,cur) values
(1,'1001','الخزنة','A','',true,'EGP'),
(2,'1002','بنك','A','',true,'EGP'),
(3,'1003','فودافون كاش','A','',true,'EGP'),
(4,'1100','العملاء','A','ar',false,'EGP'),
(5,'1200','المخزون','A','inv',false,'EGP'),
(6,'1250','تحت التصنيع','A','wip',false,'EGP'),
(7,'2100','الموردون','L','ap',false,'EGP'),
(8,'3001','رأس المال','Q','cap',false,'EGP'),
(9,'4100','المبيعات','I','sales',false,'EGP'),
(10,'5100','تكلفة المبيعات','X','cogs',false,'EGP')
on conflict (id) do nothing;
insert into wh(id,name) values (1,'قماش'),(2,'مستلزمات'),(3,'منتج نهائي') on conflict do nothing;
