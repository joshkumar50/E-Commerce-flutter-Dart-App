-- ============================================================================
-- LIVE DATABASE SEED SCRIPT: REAL ONLINE STORE CATEGORIES & PRODUCTS
-- ============================================================================
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/eqhkqkewhpvxfwaggkmt/sql/new
--
-- This populates your real Supabase PostgreSQL tables (categories & products)
-- with real online catalog items, prices in Indian Rupees (INR ₹),
-- inventory stock, and high-resolution images.
-- ============================================================================

-- 0. Wipe out any old mock / placeholder data safely with CASCADE
TRUNCATE TABLE 
  public.inventory_reservations,
  public.inventory_ledger,
  public.order_items,
  public.cart_items,
  public.wishlist_items,
  public.product_images,
  public.products,
  public.categories
CASCADE;

-- 1. Insert Real Categories
INSERT INTO public.categories (id, name, description, image_url, sort_order, is_active)
VALUES
  (
    'c1111111-1111-1111-1111-111111111111',
    'Fruits',
    'Fresh seasonal and exotic organic fruits harvested daily',
    'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?auto=format&fit=crop&w=640&q=80',
    1,
    true
  ),
  (
    'c2222222-2222-2222-2222-222222222222',
    'Vegetables',
    'Farm-fresh leafy greens and root vegetables',
    'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=640&q=80',
    2,
    true
  ),
  (
    'c3333333-3333-3333-3333-333333333333',
    'Dairy & Eggs',
    'Fresh cow milk, paneer, butter, cheese, and farm eggs',
    'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=640&q=80',
    3,
    true
  ),
  (
    'c4444444-4444-4444-4444-444444444444',
    'Bakery',
    'Fresh artisan bread, burger buns, and morning pastries',
    'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=640&q=80',
    4,
    true
  ),
  (
    'c5555555-5555-5555-5555-555555555555',
    'Beverages',
    'Cold-pressed juices, tender coconut water, and artisanal teas',
    'https://images.unsplash.com/photo-1534353473418-4cfa6c56fd38?auto=format&fit=crop&w=640&q=80',
    5,
    true
  ),
  (
    'c6666666-6666-6666-6666-666666666666',
    'Snacks',
    'Roasted nuts, dry fruits, energy bars, and treats',
    'https://images.unsplash.com/photo-1621996346565-e3d5d6281729?auto=format&fit=crop&w=640&q=80',
    6,
    true
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  image_url = EXCLUDED.image_url,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;

-- 2. Insert Real Products
INSERT INTO public.products (id, category_id, name, description, price, sale_price, stock_quantity, unit, image_url, is_active, version)
VALUES
  (
    1,
    'c1111111-1111-1111-1111-111111111111',
    'Fresh Robusta Bananas',
    'Naturally ripened, sweet Robusta bananas rich in potassium and energy.',
    55.00,
    48.00,
    150,
    '1 kg (approx 6-8 pcs)',
    'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    2,
    'c1111111-1111-1111-1111-111111111111',
    'Royal Gala Crisp Apples',
    'Crispy, sweet, and fragrant red Gala apples imported from highland orchards.',
    220.00,
    185.00,
    80,
    '1 kg (4-5 pcs)',
    'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    3,
    'c1111111-1111-1111-1111-111111111111',
    'Ripe Hass Avocados (Pack of 3)',
    'Buttery and nutrient-dense Hass avocados at peak eating ripeness.',
    299.00,
    249.00,
    60,
    'Pack of 3',
    'https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    4,
    'c2222222-2222-2222-2222-222222222222',
    'Hydroponic Baby Spinach',
    'Pesticide-free, tender washed baby spinach ready for salads and smoothies.',
    45.00,
    35.00,
    100,
    '200g pack',
    'https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    5,
    'c2222222-2222-2222-2222-222222222222',
    'Farm-Fresh Hybrid Tomatoes',
    'Juicy, firm red vine tomatoes perfect for Indian curries and sauces.',
    40.00,
    32.00,
    200,
    '1 kg',
    'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    6,
    'c2222222-2222-2222-2222-222222222222',
    'Nasik Red Onions',
    'Crisp, pungent red onions sourced directly from farmers. Kitchen staple.',
    50.00,
    42.00,
    180,
    '1 kg',
    'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    7,
    'c3333333-3333-3333-3333-333333333333',
    'Pure Cow Milk (Homogenized)',
    'Farm-fresh pure cow milk pasteurized and chilled. Rich in calcium and vitamins.',
    60.00,
    56.00,
    120,
    '1 Litre bottle',
    'https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    8,
    'c3333333-3333-3333-3333-333333333333',
    'Free-Range Country Eggs (12 pcs)',
    'Naturally laid farm-fresh brown eggs with rich golden yolks.',
    120.00,
    98.00,
    110,
    'Pack of 12',
    'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    9,
    'c3333333-3333-3333-3333-333333333333',
    'Fresh Malai Paneer',
    'Soft, creamy cottage cheese made from 100% cow milk with zero preservatives.',
    110.00,
    95.00,
    75,
    '200g block',
    'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    10,
    'c4444444-4444-4444-4444-444444444444',
    'Whole Wheat Sourdough Loaf',
    'Artisanal naturally fermented sourdough loaf with crisp golden crust and chewy crumb.',
    160.00,
    135.00,
    40,
    '400g loaf',
    'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    11,
    'c4444444-4444-4444-4444-444444444444',
    '100% Whole Wheat Brown Bread',
    'High-fibre multigrain brown bread baked fresh every morning without maida.',
    50.00,
    45.00,
    65,
    '400g pack',
    'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    12,
    'c5555555-5555-5555-5555-555555555555',
    'Cold-Pressed Valencia Orange Juice',
    '100% pure raw cold-pressed orange juice without added sugar or water.',
    130.00,
    110.00,
    90,
    '250 ml bottle',
    'https://images.unsplash.com/photo-1613478223719-2ab802602423?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    13,
    'c5555555-5555-5555-5555-555555555555',
    'Fresh Tender Coconut Water',
    'Naturally sweet and electrolyte-packed water from tender green coconuts.',
    65.00,
    55.00,
    140,
    '1 pc (approx 300 ml)',
    'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    14,
    'c6666666-6666-6666-6666-666666666666',
    'California Roasted & Salted Almonds',
    'Crunchy, premium non-GMO California almonds slow roasted and lightly sea-salted.',
    320.00,
    275.00,
    85,
    '250g resealable pouch',
    'https://images.unsplash.com/photo-1508061252445-5350f3ab0a55?auto=format&fit=crop&w=640&q=80',
    true,
    1
  ),
  (
    15,
    'c6666666-6666-6666-6666-666666666666',
    'Whole Jumbo Cashew Nuts (W320)',
    'Creamy, sweet Grade W320 whole cashew nuts rich in healthy fats.',
    380.00,
    330.00,
    70,
    '250g resealable pouch',
    'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?auto=format&fit=crop&w=640&q=80',
    true,
    1
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  sale_price = EXCLUDED.sale_price,
  stock_quantity = EXCLUDED.stock_quantity,
  unit = EXCLUDED.unit,
  image_url = EXCLUDED.image_url,
  is_active = EXCLUDED.is_active;

-- Confirmation output
SELECT 
  (SELECT COUNT(*) FROM public.categories) AS total_categories,
  (SELECT COUNT(*) FROM public.products) AS total_products;
