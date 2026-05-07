import '../data/restaurant_data.dart';
import 'models/menu_item_dto.dart';

class FallbackData {
  // --- Restaurants ---
  static List<Restaurant> get restaurants => [
    const Restaurant(
      id: '1',
      name: 'The Grand Pavilion',
      category: 'Thai Fusion • Fine Dining',
      rating: 4.8,
      reviewCount: 1250,
      distance: '0.8 km',
      imagePath: 'https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=1200&auto=format&fit=crop',
      logoPath: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSx-D7wYn9S1_0N3WzS-Yk8yV_zXp9z_GgD9g&s',
      deliveryTime: '25-35 min',
      status: 'Open',
      deliveryFee: '฿0',
      originalDeliveryFee: '฿40',
    ),
    const Restaurant(
      id: '2',
      name: 'Sushi Mitsu',
      category: 'Japanese • Sushi',
      rating: 4.9,
      reviewCount: 890,
      distance: '1.2 km',
      imagePath: 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?q=80&w=1200&auto=format&fit=crop',
      logoPath: 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=100&q=80',
      deliveryTime: '30-40 min',
      status: 'Open',
      deliveryFee: '฿20',
    ),
    const Restaurant(
      id: '3',
      name: 'Burger Craft',
      category: 'American • Burgers',
      rating: 4.5,
      reviewCount: 2100,
      distance: '2.5 km',
      imagePath: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=1200&auto=format&fit=crop',
      logoPath: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Burger_King_logo_%282021%29.svg/1024px-Burger_King_logo_%282021%29.svg.png',
      deliveryTime: '20-30 min',
      status: 'Open',
      deliveryFee: '฿15',
    ),
  ];

  // --- Lost Items ---
  static List<Map<String, String>> get lostItems => [
    {
      'description': 'Lost a black leather wallet containing a Thai ID and credit cards near Siam Paragon. Reward offered.',
      'imageUrl': 'https://images.unsplash.com/photo-1627123424574-724758594e93?q=80&w=600&auto=format&fit=crop',
      'timeAgo': '5m ago',
    },
    {
      'description': 'Found a set of BMW car keys at Lumphini Park. Message me to identify the keychain.',
      'imageUrl': 'https://images.unsplash.com/photo-1582139329536-e7284fece509?q=80&w=600&auto=format&fit=crop',
      'timeAgo': '12m ago',
    },
    {
      'description': 'Found a grey Herschel backpack on the BTS Sukhumvit line. Many personal items inside.',
      'imageUrl': 'https://images.unsplash.com/photo-1547949003-9792a18a2601?q=80&w=600&auto=format&fit=crop',
      'timeAgo': '45m ago',
    },
  ];

  // --- Trending News ---
  static List<Map<String, String>> get news => [
    {
      'title': 'New Skywalk connects Siam Square to MBK: A boost for Bangkok pedestrians.',
      'imageUrl': 'https://picsum.photos/seed/skywalk/800/600',
      'source': 'Bangkok Post',
      'timeAgo': '10m ago',
    },
    {
      'title': 'The Songkran Festival 2026: Official dates and main event locations announced.',
      'imageUrl': 'https://picsum.photos/seed/songkran/800/600',
      'source': 'Thai PBS',
      'timeAgo': '1h ago',
    },
    {
      'title': 'Local startups receive major funding boost to develop eco-friendly food packaging.',
      'imageUrl': 'https://picsum.photos/seed/startup/800/600',
      'source': 'Reuters',
      'timeAgo': '3h ago',
    },
    {
      'title': 'Bangkok Food Festival 2026 kicks off with hundreds of local and international stalls.',
      'imageUrl': 'https://picsum.photos/seed/food/800/600',
      'source': 'Mytogether News',
      'timeAgo': '5h ago',
    },
  ];

  // --- Top Places ---
  static List<Map<String, dynamic>> get topPlaces => [
    {
      'name': 'The Grand Palace',
      'category': 'Historical Landmark',
      'distance': '2.1 km',
      'imagePath': 'https://plus.unsplash.com/premium_photo-1661919589683-f11880119fb7?q=80&w=1400&auto=format&fit=crop',
      'description': 'A complex of buildings at the heart of Bangkok, the Grand Palace has been the official residence of the Kings of Siam since 1782.',
      'hours': '8:30 AM - 3:30 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1544015759-338276f920f3?q=80&w=800&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1569424888066-8848db9980d2?q=80&w=800&auto=format&fit=crop',
      ],
    },
    {
      'name': 'Wat Arun',
      'category': 'Temple',
      'distance': '1.8 km',
      'imagePath': 'https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?q=80&w=1400&auto=format&fit=crop',
      'description': 'Wat Arun, the "Temple of Dawn", is one of Bangkok\'s most iconic symbols situated on the west bank of the Chao Phraya River.',
      'hours': '8:00 AM - 6:00 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?q=80&w=800&fit=crop',
        'https://images.unsplash.com/photo-1589394815804-964ed0be2eb5?q=80&w=800&fit=crop',
      ],
    },
    {
      'name': 'Lumpini Park',
      'category': 'City Park',
      'distance': '3.5 km',
      'imagePath': 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?q=80&w=1400&auto=format&fit=crop',
      'description': 'The first public park in Bangkok, offering a green oasis with a large artificial lake, jogging tracks, and playgrounds.',
      'hours': '4:30 AM - 9:00 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=800',
      ],
    },
    {
      'name': 'Siam Paragon',
      'category': 'Shopping Mall',
      'distance': '0.5 km',
      'imagePath': 'https://images.unsplash.com/photo-1565967511849-76a60a516170?q=80&w=1400&auto=format&fit=crop',
      'description': 'One of the largest shopping malls in Thailand, featuring high-end brands, a massive aquarium, and luxury cinemas.',
      'hours': '10:00 AM - 10:00 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?q=80&w=800',
      ],
    },
    {
      'name': 'Wat Phra Kaew',
      'category': 'Temple',
      'distance': '2.3 km',
      'imagePath': 'https://images.unsplash.com/photo-1533154683836-84ea7a0bc310?q=80&w=1400&auto=format&fit=crop',
      'description': 'Commonly known in English as the Temple of the Emerald Buddha and officially as Wat Phra Si Rattana Satsadaram.',
      'hours': '8:30 AM - 3:30 PM',
      'gallery': [
        'https://images.unsplash.com/photo-1569424888066-8848db9980d2?q=80&w=800&auto=format&fit=crop',
      ],
    },
  ];

  // --- Popular Brands ---
  static List<Map<String, dynamic>> get popularBrands => [
    {
      'name': 'YKKO',
      'rating': '4.7',
      'time': '35min',
      'distance': '1.5km',
      'logoUrl': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSx-D7wYn9S1_0N3WzS-Yk8yV_zXp9z_GgD9g&s',
    },
    {
      'name': 'KFC',
      'rating': '4.5',
      'time': '20min',
      'distance': '1.0km',
      'logoUrl': 'https://images_production.sgp1.digitaloceanspaces.com/logo/kfc_logo.png',
    },
    {
      'name': 'Burger King',
      'rating': '4.3',
      'time': '30min',
      'distance': '1.8km',
      'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Burger_King_logo_%282021%29.svg/1024px-Burger_King_logo_%282021%29.svg.png',
    },
    {
      'name': 'Starbucks',
      'rating': '4.8',
      'time': '15min',
      'distance': '0.5km',
      'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/d/d3/Starbucks_Corporation_Logo_2011.svg/1200px-Starbucks_Corporation_Logo_2011.svg.png',
    },
    {
      'name': 'Sushi Place',
      'rating': '4.7',
      'time': '40min',
      'distance': '2.2km',
      'logoUrl': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=100&q=80',
    },
    {
      'name': 'Shwe Tea House',
      'rating': '4.7',
      'time': '40min',
      'distance': '2.0km',
      'logoUrl': 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=100&q=80',
    },
    {
      'name': "McDonald's",
      'rating': '4.2',
      'time': '20min',
      'distance': '1.2km',
      'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/McDonald%27s_Golden_Arches.svg/1200px-McDonald%27s_Golden_Arches.svg.png',
    },
    {
      'name': 'Pizza Hut',
      'rating': '4.4',
      'time': '35min',
      'distance': '2.2km',
      'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/d/d2/Pizza_Hut_logo.svg/1200px-Pizza_Hut_logo.svg.png',
    },
    {
      'name': 'The Pizza Company',
      'rating': '4.6',
      'time': '45min',
      'distance': '3.0km',
      'logoUrl': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR6_GZ-8v7z-qf9v1XzVz-fXvXw-y9fXvXw-g&s',
    },
  ];

  // --- Together Deals ---
  static List<Map<String, dynamic>> get togetherDeals => [
    {
      'name': 'Spicy Tofu Salad',
      'price': 65,
      'originalPrice': 75,
      'deliveryFee': 25,
      'minutes': 30,
      'imagePath': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?q=80&w=400',
    },
    {
      'name': 'Avocado Toast',
      'price': 45,
      'originalPrice': 75,
      'deliveryFee': 35,
      'minutes': 20,
      'imagePath': 'https://images.unsplash.com/photo-1525351484163-7529414344d8?q=80&w=400',
    },
    {
      'name': 'Mango Sticky Rice',
      'price': 95,
      'originalPrice': 120,
      'deliveryFee': 40,
      'minutes': 40,
      'imagePath': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=400',
    },
    {
      'name': 'Special Pad Thai',
      'price': 115,
      'originalPrice': 150,
      'deliveryFee': 30,
      'minutes': 25,
      'imagePath': 'https://images.unsplash.com/photo-1559339352-11d035aa65de?q=80&w=400',
    },
    {
      'name': 'Classic Pancakes',
      'price': 55,
      'originalPrice': 80,
      'deliveryFee': 20,
      'minutes': 15,
      'imagePath': 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?q=80&w=400',
    },
  ];

  // --- Trending Items ---
  static List<MenuItemDto> get trendingItems => [
    MenuItemDto(
      id: 't1',
      restaurantId: '1',
      restaurantName: 'The Grand Pavilion',
      title: 'Signature Pad Thai',
      price: 185.0,
      currency: '฿',
      imagePath: 'https://images.unsplash.com/photo-1559339352-11d035aa65de?q=80&w=600',
      category: 'Thai',
      isFavorite: false,
      rating: 4.8,
      reviewCount: 450,
      distanceKm: 0.8,
      estimatedTime: '25 min',
      deliveryFee: '฿0',
      originalDeliveryFee: '฿40',
      originalPrice: 220.0,
      displayPrice: '฿185',
    ),
    MenuItemDto(
      id: 't2',
      restaurantId: '2',
      restaurantName: 'Sushi Mitsu',
      title: 'Premium Sashimi Set',
      price: 450.0,
      currency: '฿',
      imagePath: 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?q=80&w=600',
      category: 'Japanese',
      isFavorite: true,
      rating: 4.9,
      reviewCount: 320,
      distanceKm: 1.2,
      estimatedTime: '35 min',
      deliveryFee: '฿20',
      displayPrice: '฿450',
    ),
    MenuItemDto(
      id: 't3',
      restaurantId: '3',
      restaurantName: 'Burger Craft',
      title: 'Truffle Wagyu Burger',
      price: 320.0,
      currency: '฿',
      imagePath: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=600',
      category: 'American',
      isFavorite: false,
      rating: 4.7,
      reviewCount: 1200,
      distanceKm: 2.5,
      estimatedTime: '30 min',
      deliveryFee: '฿15',
      originalPrice: 380.0,
      displayPrice: '฿320',
    ),
  ];
}
