-- GASKEN AUTO SERVICE - Supabase/PostgreSQL foundation
-- Jalankan setelah membuat project Supabase. Jangan masukkan service_role key ke browser.
create extension if not exists pgcrypto;

do $$ begin
  create type public.staff_role as enum ('owner','cashier','mechanic','advisor');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.service_mode as enum ('workshop','home_service');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.work_order_status as enum ('waiting','on_the_way','in_progress','awaiting_approval','completed','cancelled');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  username text unique not null,
  role public.staff_role not null default 'mechanic',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  address text,
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id),
  plate_number text not null,
  brand text,
  model text,
  model_year integer,
  odometer integer,
  vin text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plate_number)
);
create table if not exists public.work_orders (
  id uuid primary key default gen_random_uuid(),
  work_order_number text unique not null,
  customer_id uuid not null references public.customers(id),
  vehicle_id uuid not null references public.vehicles(id),
  service_mode public.service_mode not null,
  service_address text,
  service_lat numeric(10,7),
  service_lng numeric(10,7),
  service_distance_km numeric(10,2) check (service_distance_km is null or service_distance_km >= 0),
  visit_fee numeric(14,2) not null default 0 check (visit_fee >= 0),
  customer_complaint text not null,
  diagnosis text,
  mechanic_id uuid references public.profiles(id),
  status public.work_order_status not null default 'waiting',
  scheduled_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  created_by uuid references public.profiles(id),
  device_mutation_id uuid unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (service_mode <> 'home_service' or coalesce(length(trim(service_address)),0) > 0)
);
alter table public.work_orders add column if not exists service_distance_km numeric(10,2) check (service_distance_km is null or service_distance_km >= 0);

create table if not exists public.home_service_settings (
  id boolean primary key default true check (id = true),
  rate_per_km numeric(14,2) not null default 0 check (rate_per_km >= 0),
  minimum_visit_fee numeric(14,2) not null default 0 check (minimum_visit_fee >= 0),
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.service_catalog (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  name text not null,
  default_price numeric(14,2) not null default 0 check (default_price >= 0),
  is_active boolean not null default true
);
create table if not exists public.work_order_items (
  id uuid primary key default gen_random_uuid(),
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  item_type text not null check (item_type in ('service','part')),
  description text not null,
  quantity numeric(12,2) not null default 1 check (quantity > 0),
  unit_price numeric(14,2) not null default 0 check (unit_price >= 0),
  unit_cost numeric(14,2) not null default 0 check (unit_cost >= 0),
  created_at timestamptz not null default now()
);
create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  sku text unique,
  name text not null,
  stock_qty numeric(12,2) not null default 0,
  min_stock numeric(12,2) not null default 0,
  cost_price numeric(14,2) not null default 0,
  sell_price numeric(14,2) not null default 0,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);
create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  inventory_item_id uuid not null references public.inventory_items(id),
  quantity_delta numeric(12,2) not null,
  movement_type text not null check (movement_type in ('purchase','sale','adjustment','return')),
  reference_id uuid,
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  device_mutation_id uuid unique
);
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  work_order_id uuid not null references public.work_orders(id),
  amount numeric(14,2) not null check (amount > 0),
  method text not null check (method in ('cash','transfer','qris','debit','other')),
  reference_number text,
  received_by uuid references public.profiles(id),
  paid_at timestamptz not null default now(),
  device_mutation_id uuid unique
);
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  expense_date date not null default current_date,
  category text not null,
  description text,
  amount numeric(14,2) not null check (amount > 0),
  created_by uuid references public.profiles(id),
  approved_by uuid references public.profiles(id),
  device_mutation_id uuid unique,
  created_at timestamptz not null default now()
);
create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  table_name text not null,
  record_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.current_role() returns public.staff_role
language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() and is_active = true $$;
create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(public.current_role() = 'owner'::public.staff_role, false) $$;
create or replace function public.has_any_role(allowed public.staff_role[]) returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(public.current_role() = any(allowed), false) $$;

alter table public.profiles enable row level security;
alter table public.home_service_settings enable row level security;
alter table public.customers enable row level security;
alter table public.vehicles enable row level security;
alter table public.work_orders enable row level security;
alter table public.service_catalog enable row level security;
alter table public.work_order_items enable row level security;
alter table public.inventory_items enable row level security;
alter table public.stock_movements enable row level security;
alter table public.payments enable row level security;
alter table public.expenses enable row level security;
alter table public.audit_logs enable row level security;

-- Tarif Home Service hanya dapat dibaca staf terautentikasi; hanya pemilik yang dapat mengubahnya.
create policy "staff read home service settings" on public.home_service_settings for select to authenticated using (public.current_role() is not null);
create policy "owner manage home service settings" on public.home_service_settings for all to authenticated using (public.is_owner()) with check (public.is_owner());

-- Profil: pengguna melihat profil sendiri; pemilik mengelola seluruh profil.
create policy "profile read self or owner" on public.profiles for select to authenticated using (id = auth.uid() or public.is_owner());
create policy "owner manage profiles" on public.profiles for all to authenticated using (public.is_owner()) with check (public.is_owner());

-- Pelanggan dan kendaraan.
create policy "staff read customers" on public.customers for select to authenticated using (public.current_role() is not null);
create policy "authorized create customers" on public.customers for insert to authenticated with check (public.has_any_role(array['owner','advisor','cashier']::public.staff_role[]));
create policy "authorized update customers" on public.customers for update to authenticated using (public.has_any_role(array['owner','advisor','cashier']::public.staff_role[])) with check (public.has_any_role(array['owner','advisor','cashier']::public.staff_role[]));
create policy "owner delete customers" on public.customers for delete to authenticated using (public.is_owner());
create policy "staff read vehicles" on public.vehicles for select to authenticated using (public.current_role() is not null);
create policy "authorized create vehicles" on public.vehicles for insert to authenticated with check (public.has_any_role(array['owner','advisor','cashier']::public.staff_role[]));
create policy "authorized update vehicles" on public.vehicles for update to authenticated using (public.has_any_role(array['owner','advisor','cashier']::public.staff_role[])) with check (public.has_any_role(array['owner','advisor','cashier']::public.staff_role[]));
create policy "owner delete vehicles" on public.vehicles for delete to authenticated using (public.is_owner());

-- Work order: mekanik hanya dapat membaca tugas yang ditugaskan kepadanya.
create policy "read assigned work orders" on public.work_orders for select to authenticated using (public.is_owner() or public.has_any_role(array['advisor','cashier']::public.staff_role[]) or mechanic_id = auth.uid());
create policy "advisor owner create work orders" on public.work_orders for insert to authenticated with check (public.has_any_role(array['owner','advisor']::public.staff_role[]));
create policy "owner advisor update work orders" on public.work_orders for update to authenticated using (public.has_any_role(array['owner','advisor']::public.staff_role[])) with check (public.has_any_role(array['owner','advisor']::public.staff_role[]));
-- Pembaruan mekanik pada kolom diagnosis/status sebaiknya diekspos melalui RPC terverifikasi,
-- bukan UPDATE langsung, agar mekanik tidak dapat mengubah harga, penugasan, atau data pelanggan.

create policy "staff read service catalog" on public.service_catalog for select to authenticated using (public.current_role() is not null);
create policy "owner manage service catalog" on public.service_catalog for all to authenticated using (public.is_owner()) with check (public.is_owner());
create policy "staff read work order items" on public.work_order_items for select to authenticated using (exists(select 1 from public.work_orders w where w.id=work_order_id and (public.is_owner() or public.has_any_role(array['advisor','cashier']::public.staff_role[]) or w.mechanic_id=auth.uid())));
create policy "owner advisor manage work order items" on public.work_order_items for all to authenticated using (public.has_any_role(array['owner','advisor']::public.staff_role[])) with check (public.has_any_role(array['owner','advisor']::public.staff_role[]));

create policy "staff read inventory" on public.inventory_items for select to authenticated using (public.current_role() is not null);
create policy "owner manage inventory" on public.inventory_items for all to authenticated using (public.is_owner()) with check (public.is_owner());
create policy "staff read stock movements" on public.stock_movements for select to authenticated using (public.current_role() is not null);
create policy "owner manage stock movements" on public.stock_movements for all to authenticated using (public.is_owner()) with check (public.is_owner());

create policy "owner cashier read payments" on public.payments for select to authenticated using (public.has_any_role(array['owner','cashier']::public.staff_role[]));
create policy "cashier owner create payments" on public.payments for insert to authenticated with check (public.has_any_role(array['owner','cashier']::public.staff_role[]));
create policy "owner only payment changes" on public.payments for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy "owner only payment delete" on public.payments for delete to authenticated using (public.is_owner());
create policy "owner read expenses" on public.expenses for select to authenticated using (public.is_owner());
create policy "owner create expenses" on public.expenses for insert to authenticated with check (public.is_owner());
create policy "owner manage expenses" on public.expenses for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy "owner read audit logs" on public.audit_logs for select to authenticated using (public.is_owner());

-- RPC terbatas untuk mekanik: hanya diagnosis dan status tugas miliknya.
create or replace function public.mechanic_update_work_order(
  p_work_order_id uuid,
  p_diagnosis text,
  p_status public.work_order_status
) returns void
language plpgsql security definer set search_path = public
as $$
begin
  if public.current_role() <> 'mechanic'::public.staff_role then
    raise exception 'Hanya akun mekanik yang dapat menggunakan fungsi ini';
  end if;
  update public.work_orders
     set diagnosis = p_diagnosis,
         status = p_status,
         started_at = case when p_status = 'in_progress' and started_at is null then now() else started_at end,
         completed_at = case when p_status = 'completed' then now() else completed_at end,
         updated_at = now()
   where id = p_work_order_id and mechanic_id = auth.uid();
  if not found then raise exception 'Work order tidak ditemukan atau bukan tugas mekanik ini'; end if;
end;
$$;
revoke all on function public.mechanic_update_work_order(uuid,text,public.work_order_status) from public;
grant execute on function public.mechanic_update_work_order(uuid,text,public.work_order_status) to authenticated;

-- PENTING: buat user pertama melalui Supabase Auth, lalu buat baris profiles role='owner'
-- untuk UUID user tersebut melalui SQL Editor/dashboard Supabase. Setelah itu pemilik
-- dapat mengundang akun staf melalui backend tepercaya (Edge Function); jangan pernah
-- menaruh service_role key di kode browser.

-- Indeks untuk pencarian cepat dan antrean sinkronisasi idempoten.
create index if not exists idx_vehicles_plate on public.vehicles(plate_number);
create index if not exists idx_work_orders_status_date on public.work_orders(status, created_at desc);
create index if not exists idx_work_orders_mechanic on public.work_orders(mechanic_id, status);
create index if not exists idx_payments_paid_at on public.payments(paid_at desc);
create index if not exists idx_stock_movements_item_date on public.stock_movements(inventory_item_id, created_at desc);
