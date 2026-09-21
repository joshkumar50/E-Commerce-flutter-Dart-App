-- =============================================================================
-- Migration 02: Row Level Security (RLS) and Authorization
-- Description: Server-side security policies, is_admin() helper, auto-profile trigger, and storage rules
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. HELPER FUNCTION: Check if currently authenticated user is an Admin
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 2. AUTOMATIC PROFILE CREATION TRIGGER
-- Triggers on new user signup (Email/Password or Google OAuth) to create a
-- profile with 'customer' role by default. Prevents race conditions.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email, avatar_url, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
        COALESCE(NEW.email, ''),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture', ''),
        'customer'
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = CASE WHEN public.profiles.full_name = '' THEN EXCLUDED.full_name ELSE public.profiles.full_name END,
        avatar_url = CASE WHEN public.profiles.avatar_url = '' THEN EXCLUDED.avatar_url ELSE public.profiles.avatar_url END,
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger attached to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 3. ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 4. PROFILES RLS POLICIES
-- -----------------------------------------------------------------------------
-- Customers can view their own profile; Admins can view all profiles
CREATE POLICY "profiles_select_policy"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id OR public.is_admin());

-- Customers can update their own profile fields, but CANNOT self-escalate their role
CREATE POLICY "profiles_update_policy"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id OR public.is_admin())
    WITH CHECK (
        (auth.uid() = id AND role = (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()))
        OR public.is_admin()
    );

-- -----------------------------------------------------------------------------
-- 5. CATEGORIES RLS POLICIES
-- -----------------------------------------------------------------------------
-- Anyone authenticated can view active categories; Admins see all
CREATE POLICY "categories_select_policy"
    ON public.categories FOR SELECT
    USING (is_active = true OR public.is_admin());

-- Only admins can manage categories
CREATE POLICY "categories_admin_insert"
    ON public.categories FOR INSERT
    WITH CHECK (public.is_admin());

CREATE POLICY "categories_admin_update"
    ON public.categories FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "categories_admin_delete"
    ON public.categories FOR DELETE
    USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 6. PRODUCTS RLS POLICIES
-- -----------------------------------------------------------------------------
-- Anyone authenticated can view active products; Admins see all
CREATE POLICY "products_select_policy"
    ON public.products FOR SELECT
    USING (is_active = true OR public.is_admin());

-- Only admins can create, update, and delete products
CREATE POLICY "products_admin_insert"
    ON public.products FOR INSERT
    WITH CHECK (public.is_admin());

CREATE POLICY "products_admin_update"
    ON public.products FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "products_admin_delete"
    ON public.products FOR DELETE
    USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 7. PRODUCT IMAGES RLS POLICIES
-- -----------------------------------------------------------------------------
-- Read images belonging to readable products
CREATE POLICY "product_images_select_policy"
    ON public.product_images FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.products p
            WHERE p.id = product_images.product_id
            AND (p.is_active = true OR public.is_admin())
        )
    );

-- Only admins can manage product images
CREATE POLICY "product_images_admin_insert"
    ON public.product_images FOR INSERT
    WITH CHECK (public.is_admin());

CREATE POLICY "product_images_admin_update"
    ON public.product_images FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "product_images_admin_delete"
    ON public.product_images FOR DELETE
    USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 8. ADDRESSES RLS POLICIES
-- -----------------------------------------------------------------------------
-- Customers manage only their own addresses
CREATE POLICY "addresses_select_own"
    ON public.addresses FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "addresses_insert_own"
    ON public.addresses FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "addresses_update_own"
    ON public.addresses FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "addresses_delete_own"
    ON public.addresses FOR DELETE
    USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 9. CART ITEMS RLS POLICIES
-- -----------------------------------------------------------------------------
-- Customers manage only their own cart
CREATE POLICY "cart_items_select_own"
    ON public.cart_items FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "cart_items_insert_own"
    ON public.cart_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "cart_items_update_own"
    ON public.cart_items FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "cart_items_delete_own"
    ON public.cart_items FOR DELETE
    USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 10. WISHLIST ITEMS RLS POLICIES
-- -----------------------------------------------------------------------------
-- Customers manage only their own wishlist
CREATE POLICY "wishlist_items_select_own"
    ON public.wishlist_items FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "wishlist_items_insert_own"
    ON public.wishlist_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "wishlist_items_delete_own"
    ON public.wishlist_items FOR DELETE
    USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 11. SUPABASE REALTIME REPLICATION
-- Enable realtime publication for products and categories for live updates
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'products'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'categories'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 12. STORAGE BUCKET & POLICIES (product-images)
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Public can view product images
CREATE POLICY "product_images_bucket_public_select"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'product-images');

-- Only admins can upload, update, and delete in product-images bucket
CREATE POLICY "product_images_bucket_admin_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'product-images' AND public.is_admin());

CREATE POLICY "product_images_bucket_admin_update"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'product-images' AND public.is_admin())
    WITH CHECK (bucket_id = 'product-images' AND public.is_admin());

CREATE POLICY "product_images_bucket_admin_delete"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'product-images' AND public.is_admin());
