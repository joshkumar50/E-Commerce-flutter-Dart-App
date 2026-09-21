# Supabase Backend Setup & Configuration Guide

This directory contains the PostgreSQL migrations, Row Level Security (RLS) policies, and seed data for the **B-Buys Grocery Platform**.

---

## 1. How to Apply Migrations

### Option A: Using the Supabase Web Dashboard (Recommended for quick setup)
1. Log in to your [Supabase Dashboard](https://app.supabase.com) and open your project.
2. Go to the **SQL Editor** tab on the left sidebar.
3. Execute the SQL migration files in this exact sequential order:
   - `migrations/20260921000001_initial_schema.sql` (Tables, constraints, indexes, triggers)
   - `migrations/20260921000002_row_level_security.sql` (RLS policies, `is_admin()` helper, `on_auth_user_created` trigger, storage policies)
   - `migrations/20260921000003_seed_data.sql` (Grocery categories and fresh product seed data)

### Option B: Using Supabase CLI
```bash
# Link to your Supabase project
supabase link --project-ref your-project-id

# Push all migrations
supabase db push
```

---

## 2. Assigning the First Admin Account

By default, all new Google and Email signups are assigned the `customer` role for security.

To promote an account to **`admin`**:
1. Sign up/Log in with your email or Google account on the app.
2. Run this SQL query in the Supabase SQL Editor:
```sql
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'your-admin-email@example.com';
```

---

## 3. Google OAuth Setup in Supabase

1. Open **Google Cloud Console** > **APIs & Services** > **Credentials**.
2. Create an **OAuth 2.0 Client ID** (Web application).
3. Set the **Authorized redirect URI** to your Supabase Auth callback URL:
   `https://<your-project-id>.supabase.co/auth/v1/callback`
4. In your Supabase Dashboard:
   - Go to **Authentication** > **Providers** > **Google**.
   - Toggle **Enable Google**.
   - Paste the **Client ID** and **Client Secret** from Google Cloud Console.
   - Save changes.

---

## 4. Connecting the Flutter App

You can supply your credentials at build/run time:

### In VS Code (`.vscode/launch.json` or terminal):
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project-id.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-publishable-key
```

*If `SUPABASE_URL` is omitted or empty, the Flutter app automatically runs in **Demo Mode** using rich offline grocery mock data.*
