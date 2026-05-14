# Supabase Setup (First Step)

This app currently stores data locally with SwiftData.  
This setup adds Supabase as the source of truth so we can remove local-only/mock-style behavior.

## 1) Create Supabase project

1. Create a project in Supabase.
2. Copy:
- `Project URL`
- `anon public key`
3. Put both in `Bob/Info.plist`:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## 2) Create database schema

Run this SQL in Supabase SQL editor:

```sql
create extension if not exists "pgcrypto";

create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  sf_symbol text not null default 'circle',
  sort_order integer not null default 0,
  kind_raw text not null,
  created_at timestamptz not null default now()
);

create table if not exists expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  amount numeric(12,2) not null,
  occurred_at timestamptz not null,
  note text,
  merchant text,
  category_id uuid references categories(id) on delete set null,
  kind_raw text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_expenses_user_date on expenses(user_id, occurred_at desc);
create index if not exists idx_categories_user_kind on categories(user_id, kind_raw, sort_order);
```

## 3) Enable RLS (required)

```sql
alter table categories enable row level security;
alter table expenses enable row level security;
```

For now, keep policies strict and add auth next. Do **not** use wide-open public policies in production.

## 4) Next implementation steps

1. Add Supabase Auth (anonymous or email) to get `user_id`.
2. Add repository layer (`ExpensesRepository`, `CategoriesRepository`) backed by Supabase.
3. Replace direct SwiftData writes in add/edit flows with repository writes.
4. Keep SwiftData only as cache/offline mirror.
5. Add bidirectional sync with conflict strategy (`updated_at` + server-wins or last-write-wins).

