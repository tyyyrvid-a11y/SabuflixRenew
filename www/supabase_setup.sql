-- Rode este código no SQL Editor do Supabase para criar a tabela 'my_list' e configurar as permissões

-- 1. Criar a tabela
create table if not exists public.my_list (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  tmdb_id text not null,
  media_type text not null,
  title text,
  poster_path text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, tmdb_id)
);

-- 2. Habilitar a segurança em nível de linha (Row Level Security - RLS)
alter table public.my_list enable row level security;

-- 3. Criar as políticas de segurança para que cada usuário só acesse sua própria lista
create policy "Users can view their own list" on public.my_list for select using (auth.uid() = user_id);
create policy "Users can insert their own list" on public.my_list for insert with check (auth.uid() = user_id);
create policy "Users can delete their own list" on public.my_list for delete using (auth.uid() = user_id);
