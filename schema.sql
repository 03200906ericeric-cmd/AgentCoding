-- Create repositories table
create table if not exists public.repositories (
    id bigint generated always as identity primary key,
    name text not null unique,
    description text,
    html_url text not null,
    language text,
    stargazers_count bigint default 0,
    forks_count bigint default 0,
    tags text[] default '{}'::text[],
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (RLS)
alter table public.repositories enable row level security;

-- Create policy to allow public select/read access
create policy "Allow public read access"
    on public.repositories
    for select
    using (true);

-- Create policy to allow authenticated insert/update/delete (or service role)
-- By default, service_role bypasses RLS, but this policy is helpful for authenticated users if configured
create policy "Allow write access for authenticated users"
    on public.repositories
    for all
    using (auth.role() = 'authenticated')
    with check (auth.role() = 'authenticated');
