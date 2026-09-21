-- =============================================================================
-- Migration 03: Realistic Grocery Seed Data for B-Buys Platform
-- Description: Core grocery categories and fresh products for immediate development and testing
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. SEED CATEGORIES
-- -----------------------------------------------------------------------------
INSERT INTO public.categories (id, name, description, image_url, sort_order, is_active)
VALUES
    ('c1111111-1111-1111-1111-111111111111', 'Fruits', 'Fresh, juicy organic fruits harvested daily', 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=640&q=80', 1, true),
    ('c2222222-2222-2222-2222-222222222222', 'Vegetables', 'Farm-fresh green and root vegetables', 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=640&q=80', 2, true),
    ('c3333333-3333-3333-3333-333333333333', 'Dairy & Eggs', 'Pure milk, cheese, butter, and farm eggs', 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=640&q=80', 3, true),
    ('c4444444-4444-4444-4444-444444444444', 'Bakery', 'Artisan bread, buns, and fresh daily pastries', 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=640&q=80', 4, true),
    ('c5555555-5555-5555-5555-555555555555', 'Snacks', 'Nuts, dried fruits, chips, and chocolates', 'https://images.unsplash.com/photo-1621996346565-e3d5d6281729?w=640&q=80', 5, true),
    ('c6666666-6666-6666-6666-666666666666', 'Beverages', 'Cold pressed juices, mineral water, and tea', 'https://images.unsplash.com/photo-1534353473418-4cfa6c56fd38?w=640&q=80', 6, true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    image_url = EXCLUDED.image_url,
    sort_order = EXCLUDED.sort_order;

-- -----------------------------------------------------------------------------
-- 2. SEED PRODUCTS
-- -----------------------------------------------------------------------------
INSERT INTO public.products (id, category_id, name, description, price, sale_price, stock_quantity, unit, image_url, is_active)
OVERRIDING SYSTEM VALUE
VALUES
    (
        1,
        'c3333333-3333-3333-3333-333333333333',
        'Organic Whole Milk',
        'Fresh farm-sourced organic whole milk. Rich in calcium and vitamins. 1 litre bottle.',
        2.49,
        2.19,
        150,
        '1 Litre',
        'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=640&q=80',
        true
    ),
    (
        2,
        'c4444444-4444-4444-4444-444444444444',
        'Fresh Sourdough Bread',
        'Stone-baked sourdough with a crisp crust and chewy interior. Baked daily.',
        4.99,
        NULL,
        45,
        '500g loaf',
        'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=640&q=80',
        true
    ),
    (
        3,
        'c1111111-1111-1111-1111-111111111111',
        'Ripe Hass Avocados (Pack of 3)',
        'Hand-selected Hass avocados at peak ripeness. Perfect for guacamole or toast.',
        3.99,
        3.49,
        80,
        'Pack of 3',
        'https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?w=640&q=80',
        true
    ),
    (
        4,
        'c3333333-3333-3333-3333-333333333333',
        'Free-Range Eggs (12 pcs)',
        'Dozen large free-range eggs from certified humane farms. Rich golden yolks.',
        5.49,
        NULL,
        120,
        '1 Dozen',
        'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=640&q=80',
        true
    ),
    (
        5,
        'c3333333-3333-3333-3333-333333333333',
        'Greek Yoghurt 500g',
        'Thick and creamy full-fat Greek yoghurt. High protein, no artificial additives.',
        3.29,
        NULL,
        60,
        '500g Tub',
        'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=640&q=80',
        true
    ),
    (
        6,
        'c2222222-2222-2222-2222-222222222222',
        'Organic Baby Spinach',
        'Washed and ready-to-eat baby spinach. Perfect for salads and smoothies. 200g.',
        2.79,
        2.29,
        95,
        '200g Bag',
        'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=640&q=80',
        true
    ),
    (
        7,
        'c1111111-1111-1111-1111-111111111111',
        'Golden Ripe Bananas',
        'Sweet, naturally ripened Cavendish bananas. Rich in potassium and energy.',
        1.89,
        NULL,
        200,
        '1 kg (approx 6-7 pcs)',
        'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=640&q=80',
        true
    ),
    (
        8,
        'c1111111-1111-1111-1111-111111111111',
        'Crisp Royal Gala Apples',
        'Crisp, sweet, and juicy red Gala apples from highland orchards.',
        3.49,
        2.99,
        140,
        '1 kg pack',
        'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=640&q=80',
        true
    ),
    (
        9,
        'c2222222-2222-2222-2222-222222222222',
        'Vine Ripe Red Tomatoes',
        'Freshly picked red tomatoes with intense flavour for salads and curries.',
        2.19,
        NULL,
        180,
        '1 kg',
        'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=640&q=80',
        true
    ),
    (
        10,
        'c2222222-2222-2222-2222-222222222222',
        'Red Onions (Farm Fresh)',
        'Crisp and pungent red onions with tight skins. Kitchen essential.',
        1.99,
        1.49,
        250,
        '1 kg bag',
        'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=640&q=80',
        true
    ),
    (
        11,
        'c1111111-1111-1111-1111-111111111111',
        'Fresh Green Kiwi (Pack of 4)',
        'Tangy and vitamin C-packed Zespri green kiwis. Great for breakfast bowls.',
        3.99,
        NULL,
        70,
        'Pack of 4',
        'https://images.unsplash.com/photo-1585059895524-72359e06133a?w=640&q=80',
        true
    ),
    (
        12,
        'c1111111-1111-1111-1111-111111111111',
        'Ruby Red Pomegranates',
        'Sweet and antioxidant-rich whole ruby pomegranates.',
        4.49,
        3.89,
        50,
        '2 pcs (approx 700g)',
        'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=640&q=80',
        true
    ),
    (
        13,
        'c5555555-5555-5555-5555-555555555555',
        'Rainforest Dark Chocolate (72%)',
        'Single-origin Ecuadorian cacao bar with notes of roasted hazelnut and berry.',
        3.49,
        NULL,
        110,
        '100g Bar',
        'https://images.unsplash.com/photo-1606312619070-d48b4c652a52?w=640&q=80',
        true
    ),
    (
        14,
        'c6666666-6666-6666-6666-666666666666',
        'Cold-Pressed Orange Juice',
        '100% pure squeezed Valencia oranges with juicy pulp. Never from concentrate.',
        3.99,
        3.49,
        85,
        '750ml Bottle',
        'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=640&q=80',
        true
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category_id = EXCLUDED.category_id,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    sale_price = EXCLUDED.sale_price,
    stock_quantity = EXCLUDED.stock_quantity,
    unit = EXCLUDED.unit,
    image_url = EXCLUDED.image_url,
    is_active = EXCLUDED.is_active;
