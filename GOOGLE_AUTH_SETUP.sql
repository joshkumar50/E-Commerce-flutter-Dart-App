-- ============================================================================
-- GOOGLE & SOCIAL AUTH USER PROFILE SYNC TRIGGER
-- ============================================================================
-- Run this script in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/eqhkqkewhpvxfwaggkmt/sql/new
--
-- This ensures that whenever a user signs in with Google (or email/phone),
-- their real name, email address, and Google profile picture are automatically
-- synchronized into public.profiles, enabling full order and cart tracking.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  v_name text;
  v_avatar text;
BEGIN
  -- Extract user display name from Google OAuth metadata
  v_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1),
    'Customer'
  );

  -- Extract avatar image URL from Google OAuth metadata
  v_avatar := COALESCE(
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.raw_user_meta_data->>'picture',
    NULL
  );

  -- Upsert customer profile row
  INSERT INTO public.profiles (
    id,
    full_name,
    email,
    phone,
    avatar_url,
    role,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    v_name,
    COALESCE(NEW.email, ''),
    NEW.phone,
    v_avatar,
    'customer',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = CASE 
      WHEN public.profiles.full_name IS NULL OR public.profiles.full_name = '' 
      THEN EXCLUDED.full_name 
      ELSE public.profiles.full_name 
    END,
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
    email = CASE 
      WHEN EXCLUDED.email != '' THEN EXCLUDED.email 
      ELSE public.profiles.email 
    END,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if present
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Recreate trigger on auth.users table
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Confirmation output
SELECT 'Google Auth Profile Synchronizer installed successfully!' AS status;
