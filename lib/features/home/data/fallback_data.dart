import '../data/restaurant_data.dart';
import 'models/menu_item_dto.dart';

class FallbackData {
  // --- Restaurants ---
  static List<Restaurant> get restaurants => [
    const Restaurant(
      id: '1',
      name: 'Rangoon Tea House Bangkok',
      category: 'Myanmar Fine Dining • Tea',
      rating: 4.5,
      reviewCount: 393,
      distance: '2.4 km',
      imagePath:
          'https://lh3.googleusercontent.com/places/ANXAkqGIoJ643eeDg7vLw854ntE7Kv7FW4_uzRC-q1IU1Dn8PGgYj2j9-YrxRKc6d-m-qEu5nkReU7pYwHodQS92PQs8fVa8is72B3E=s1200-w800-h600',
      logoPath:
          'https://lh3.googleusercontent.com/places/ANXAkqGIoJ643eeDg7vLw854ntE7Kv7FW4_uzRC-q1IU1Dn8PGgYj2j9-YrxRKc6d-m-qEu5nkReU7pYwHodQS92PQs8fVa8is72B3E=s1200-w800-h600',
      deliveryTime: '25-35 min',
      status: 'Open',
      deliveryFee: '฿30',
      popularDishes: [
        MenuItemDto(
          id: 'fb1-1',
          restaurantId: '1',
          restaurantName: 'Rangoon Tea House Bangkok',
          title: 'Mohinga',
          price: 180.0,
          currency: '฿',
          imagePath: 'https://delishglobe.com/wp-content/uploads/2025/02/Burmese-Mohinga-Fish-Noodle-Soup.png',
          category: 'Noodles',
        ),
        MenuItemDto(
          id: 'fb1-2',
          restaurantId: '1',
          restaurantName: 'Rangoon Tea House Bangkok',
          title: 'Lahpet Thoke',
          price: 150.0,
          currency: '฿',
          imagePath: 'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiJP_TSChaB8kcMV1epjHfE3suOqLEoNOdDl6GrK2hBrt8oTOvO7hDoSix-pFo5EZYSkL8ZDziC6ObRjChyphenhyphenZiX0Vyy02cLg1S_efG2aClJ2BDssSwRH0FYwpD-7IkMADU8ozPh08hlAPbwJ/s1600/IMG_4012.JPG',
          category: 'Salads',
        ),
      ],
      recommendations: [
        MenuItemDto(
          id: 'fb1-3',
          restaurantId: '1',
          restaurantName: 'Rangoon Tea House Bangkok',
          title: 'Myanmar Milk Tea',
          price: 80.0,
          currency: '฿',
          imagePath: 'https://myfoodmyanmar.com/wp-content/uploads/2023/03/Royal-Milk-Tea-3.jpg',
          category: 'Beverages',
        ),
      ],
    ),
    const Restaurant(
      id: '2',
      name: 'ThaNaKa Myanmar Restaurant',
      category: 'Myanmar Home Cooking',
      rating: 4.4,
      reviewCount: 98,
      distance: '1.8 km',
      imagePath:
          'https://lh3.googleusercontent.com/places/ANXAkqFaykNogx5SUXlxCh2T-t4XwyZ_QOXGOEeozCRNfbqeGSZ1SA2bTGPPXV25CL5Dy9FMLkv91b5wwHOlfcFjOj6N0KyMORvIHtc=s1200-w800-h600',
      logoPath:
          'https://lh3.googleusercontent.com/places/ANXAkqFaykNogx5SUXlxCh2T-t4XwyZ_QOXGOEeozCRNfbqeGSZ1SA2bTGPPXV25CL5Dy9FMLkv91b5wwHOlfcFjOj6N0KyMORvIHtc=s1200-w800-h600',
      deliveryTime: '20-30 min',
      status: 'Open',
      deliveryFee: '฿30',
      popularDishes: [
        MenuItemDto(
          id: 'fb2-1',
          restaurantId: '2',
          restaurantName: 'ThaNaKa Myanmar Restaurant',
          title: 'Chicken Curry',
          price: 120.0,
          currency: '฿',
          imagePath: 'https://static01.nyt.com/images/2021/01/06/dining/04Cookbooksrex2-curry/merlin_181749069_bac75581-7b0e-4426-8d8b-1803663440fd-mediumSquareAt3X.jpg',
          category: 'Curries',
        ),
      ],
      recommendations: [
        MenuItemDto(
          id: 'fb2-2',
          restaurantId: '2',
          restaurantName: 'ThaNaKa Myanmar Restaurant',
          title: 'Steamed Rice',
          price: 20.0,
          currency: '฿',
          imagePath: 'https://images.unsplash.com/photo-1516684732162-798a0062be99?w=400',
          category: 'Rice',
        ),
      ],
    ),
    const Restaurant(
      id: '3',
      name: 'The Burma Food House',
      category: 'Myanmar & Rakhine Cuisine',
      rating: 4.7,
      reviewCount: 304,
      distance: '3.1 km',
      imagePath:
          'https://lh3.googleusercontent.com/place-photos/AL8-SNFiMFBdK4eewtN23mCBS_crMVNRFYz2Ra2F7_lsIeT7ozxUfLEI9Mt9WYNd5JWERcL4FNqbCW3gLnwZfrc9yl2MNsYC060k9NX_21WbTxjmzYWsYVl7T0_SK-b71W2ZilfHH5qy1h8cKwaRq0uNJ8kwOw=s1200-w800-h600',
      logoPath:
          'https://lh3.googleusercontent.com/place-photos/AL8-SNFiMFBdK4eewtN23mCBS_crMVNRFYz2Ra2F7_lsIeT7ozxUfLEI9Mt9WYNd5JWERcL4FNqbCW3gLnwZfrc9yl2MNsYC060k9NX_21WbTxjmzYWsYVl7T0_SK-b71W2ZilfHH5qy1h8cKwaRq0uNJ8hwOw=s1200-w800-h600',
      deliveryTime: '30-40 min',
      status: 'Open',
      deliveryFee: '฿30',
      popularDishes: [
        MenuItemDto(
          id: 'fb3-1',
          restaurantId: '3',
          restaurantName: 'The Burma Food House',
          title: 'Shan Noodles',
          price: 110.0,
          currency: '฿',
          imagePath: 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400',
          category: 'Noodles',
        ),
      ],
      recommendations: [
        MenuItemDto(
          id: 'fb3-2',
          restaurantId: '3',
          restaurantName: 'The Burma Food House',
          title: 'Papaya Salad',
          price: 80.0,
          currency: '฿',
          imagePath: 'https://images.unsplash.com/photo-1559847844-5315695dadae?w=400',
          category: 'Salads',
        ),
      ],
    ),
  ];

  // --- Lost Items ---
  static List<Map<String, String>> get lostItems => [
    {
      'description':
          'Lost a black leather wallet containing a Thai ID and credit cards near Siam Paragon. Reward offered.',
      'imageUrl':
          'https://images.unsplash.com/photo-1627123424574-724758594e93?q=80&w=600&auto=format&fit=crop',
      'timeAgo': '5m ago',
    },
    {
      'description':
          'Found a set of BMW car keys at Lumphini Park. Message me to identify the keychain.',
      'imageUrl':
          'https://images.unsplash.com/photo-1582139329536-e7284fece509?q=80&w=600&auto=format&fit=crop',
      'timeAgo': '12m ago',
    },
    {
      'description':
          'Found a grey Herschel backpack on the BTS Sukhumvit line. Many personal items inside.',
      'imageUrl':
          'https://images.unsplash.com/photo-1547949003-9792a18a2601?q=80&w=600&auto=format&fit=crop',
      'timeAgo': '45m ago',
    },
  ];

  // --- Trending News ---
  static List<Map<String, String>> get news => [
    {
      'title':
          'New Skywalk connects Siam Square to MBK: A boost for Bangkok pedestrians.',
      'imageUrl':
          'https://images.unsplash.com/photo-1546422904-90eab23c3d7e?q=80&w=800&auto=format&fit=crop',
      'source': 'Bangkok Post',
      'timeAgo': '10m ago',
    },
    {
      'title':
          'The Songkran Festival 2026: Official dates and main event locations announced.',
      'imageUrl':
          'https://images.unsplash.com/photo-1504711432869-b39743a4be9a?q=80&w=800&auto=format&fit=crop',
      'source': 'Thai PBS',
      'timeAgo': '1h ago',
    },
    {
      'title':
          'Local startups receive major funding boost to develop eco-friendly food packaging.',
      'imageUrl':
          'https://images.unsplash.com/photo-1495020689067-958852a7765e?q=80&w=1400&auto=format&fit=crop',
      'source': 'Reuters',
      'timeAgo': '3h ago',
    },
  ];

  // --- Top Places ---
  static List<Map<String, dynamic>> get topPlaces => [
    {
      'name': 'The Grand Palace',
      'category': 'Historical Landmark',
      'distance': '2.1 km',
      'imagePath':
          'https://image.umetravel.com/edit_upload/20200714/1594695690198299.jpg',
      'description':
          'A complex of buildings at the heart of Bangkok, the Grand Palace has been the official residence of the Kings of Siam since 1782.',
      'hours': '8:30 AM - 3:30 PM',
      'gallery': [
        'https://www.travelonline.com/thailand/attractions/grand-palace/thailand-generic-grand-palace-hd-56219-banner.jpg',
        'https://cdn.britannica.com/59/252559-050-F959E5DC/Grand-palace-and-Wat-Phra-Keaw-Bangkok.jpg',
      ],
    },
    {
      'name': 'Wat Arun',
      'category': 'Temple',
      'distance': '1.8 km',
      'imagePath':
          'https://static.wixstatic.com/media/2cc94a_07e55de318fe41538e17cb9de596cb45~mv2.jpg/v1/fill/w_2500,h_1406,al_c/2cc94a_07e55de318fe41538e17cb9de596cb45~mv2.jpg',
      'description':
          'Wat Arun, the "Temple of Dawn", is one of Bangkok\'s most iconic symbols situated on the west bank of the Chao Phraya River.',
      'hours': '8:00 AM - 6:00 PM',
      'gallery': [
        'https://www.agoda.com/wp-content/uploads/2024/07/Wat-Arun-at-Sunset.jpg',
        'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEhu4YkkapGaVVFdaRXfZypzqcekONZ2bNNd4orvZDpq3xY9q5Vo6SAbKbZfYTjcJ8AI-ZqrSRcj_Yi2LoxPmHmCm3DS8N8K6Z9Qn6tRs1xzkjSf7FVAUoHhRKBdnQGAt_cUVOj32a2lSxp6xmyUvwcRA-DM2mzZDrcn7SDHwuNRds7ejMSg4TmFjVJKig/s1600/Wat%20Arun-14.jpg',
      ],
    },
    {
      'name': 'Lumpini Park',
      'category': 'City Park',
      'distance': '3.5 km',
      'imagePath':
          'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/10/b8/3b/d3/lumpini-park-4.jpg?w=900&h=500&s=1',
      'description':
          'The first public park in Bangkok, offering a green oasis with a large artificial lake, jogging tracks, and playgrounds.',
      'hours': '4:30 AM - 9:00 PM',
      'gallery': [
        'https://www.pelago.com/img/collections/lumpini-park/0710-0226_lumpini-park-bangkok.jpg',
      ],
    },
    {
      'name': 'Siam Paragon',
      'category': 'Shopping Mall',
      'distance': '0.5 km',
      'imagePath':
          'http://fridaybangkok.com/_next/image?url=%2Fapi%2Fimage-proxy%3Furl%3Dhttps%253A%252F%252Fd1xbecb6qvn9r4.cloudfront.net%252F%252FSiam_Paragon_0c1addeb19.jpg&w=3840&q=75',
      'description':
          'One of the largest shopping malls in Thailand, featuring high-end brands, a massive aquarium, and luxury cinemas.',
      'hours': '10:00 AM - 10:00 PM',
      'gallery': [
        'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/24/5c/8d/5b/sealife.jpg?w=900&h=500&s=1',
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
      'logoUrl':
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSx-D7wYn9S1_0N3WzS-Yk8yV_zXp9z_GgD9g&s',
    },
    {
      'name': 'KFC',
      'rating': '4.5',
      'time': '20min',
      'distance': '1.0km',
      'logoUrl':
          'https://images_production.sgp1.digitaloceanspaces.com/logo/kfc_logo.png',
    },
    {
      'name': 'Burger King',
      'rating': '4.3',
      'time': '30min',
      'distance': '1.8km',
      'logoUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Burger_King_logo_%282021%29.svg/1024px-Burger_King_logo_%282021%29.svg.png',
    },
    {
      'name': 'Starbucks',
      'rating': '4.8',
      'time': '15min',
      'distance': '0.5km',
      'logoUrl':
          'https://upload.wikimedia.org/wikipedia/en/thumb/d/d3/Starbucks_Corporation_Logo_2011.svg/1200px-Starbucks_Corporation_Logo_2011.svg.png',
    },
    {
      'name': 'Sushi Place',
      'rating': '4.7',
      'time': '40min',
      'distance': '2.2km',
      'logoUrl':
          'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=100&q=80',
    },
    {
      'name': 'Shwe Tea House',
      'rating': '4.7',
      'time': '40min',
      'distance': '2.0km',
      'logoUrl':
          'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=100&q=80',
    },
    {
      'name': "McDonald's",
      'rating': '4.2',
      'time': '20min',
      'distance': '1.2km',
      'logoUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/McDonald%27s_Golden_Arches.svg/1200px-McDonald%27s_Golden_Arches.svg.png',
    },
    {
      'name': 'Pizza Hut',
      'rating': '4.4',
      'time': '35min',
      'distance': '2.2km',
      'logoUrl':
          'https://upload.wikimedia.org/wikipedia/en/thumb/d/d2/Pizza_Hut_logo.svg/1200px-Pizza_Hut_logo.svg.png',
    },
    {
      'name': 'The Pizza Company',
      'rating': '4.6',
      'time': '45min',
      'distance': '3.0km',
      'logoUrl':
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR6_GZ-8v7z-qf9v1XzVz-fXvXw-y9fXvXw-g&s',
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
      'imagePath':
          'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?q=80&w=400',
    },
    {
      'name': 'Avocado Toast',
      'price': 45,
      'originalPrice': 75,
      'deliveryFee': 35,
      'minutes': 20,
      'imagePath':
          'https://images.unsplash.com/photo-1525351484163-7529414344d8?q=80&w=400',
    },
    {
      'name': 'Mango Sticky Rice',
      'price': 95,
      'originalPrice': 120,
      'deliveryFee': 40,
      'minutes': 40,
      'imagePath':
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=400',
    },
    {
      'name': 'Special Pad Thai',
      'price': 115,
      'originalPrice': 150,
      'deliveryFee': 30,
      'minutes': 25,
      'imagePath':
          'https://images.unsplash.com/photo-1559339352-11d035aa65de?q=80&w=400',
    },
    {
      'name': 'Classic Pancakes',
      'price': 55,
      'originalPrice': 80,
      'deliveryFee': 20,
      'minutes': 15,
      'imagePath':
          'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?q=80&w=400',
    },
  ];

  // --- Trending Items ---
  static List<MenuItemDto> get trendingItems => [
    MenuItemDto(
      id: 't1',
      restaurantId: '1',
      restaurantName: 'Rangoon Tea House',
      title: 'Lahpet Thoke (Tea Leaf Salad)',
      price: 150.0,
      currency: '฿',
      imagePath:
          'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=800&h=600&fit=crop&auto=format',
      category: 'Myanmar',
      isFavorite: false,
      rating: 4.7,
      reviewCount: 185,
      distanceKm: 2.4,
      estimatedTime: '25 min',
      deliveryFee: '฿30',
      displayPrice: '฿150',
    ),
    MenuItemDto(
      id: 't2',
      restaurantId: '2',
      restaurantName: 'ThaNaKa Restaurant',
      title: 'Shan Noodles (Dry)',
      price: 100.0,
      currency: '฿',
      imagePath:
          'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800&h=600&fit=crop&auto=format',
      category: 'Shan',
      isFavorite: true,
      rating: 4.7,
      reviewCount: 104,
      distanceKm: 1.8,
      estimatedTime: '20 min',
      deliveryFee: '฿30',
      displayPrice: '฿100',
    ),
    MenuItemDto(
      id: 't3',
      restaurantId: '3',
      restaurantName: 'The Burma Food House',
      title: 'Nan Gyi Thoke',
      price: 120.0,
      currency: '฿',
      imagePath:
          'https://images.unsplash.com/photo-1511690656952-34342bfca0de?w=800&h=600&fit=crop&auto=format',
      category: 'Noodles',
      isFavorite: false,
      rating: 4.8,
      reviewCount: 167,
      distanceKm: 3.1,
      estimatedTime: '30 min',
      deliveryFee: '฿30',
      displayPrice: '฿120',
    ),
    MenuItemDto(
      id: 't4',
      restaurantId: '4',
      restaurantName: 'Laxmi Myanmar Food',
      title: 'Chicken Biryani',
      price: 150.0,
      currency: '฿',
      imagePath:
          'https://images.unsplash.com/photo-1617196034183-421b4040ed20?w=800&h=600&fit=crop&auto=format',
      category: 'Rice',
      isFavorite: false,
      rating: 4.6,
      reviewCount: 82,
      distanceKm: 3.4,
      estimatedTime: '25 min',
      deliveryFee: '฿30',
      displayPrice: '฿150',
    ),
    MenuItemDto(
      id: 't5',
      restaurantId: '5',
      restaurantName: 'Bagan Myay',
      title: 'Bagan Papaya Salad',
      price: 120.0,
      currency: '฿',
      imagePath:
          'https://images.unsplash.com/photo-1559847844-5315695dadae?w=800&h=600&fit=crop&auto=format',
      category: 'Salads',
      isFavorite: false,
      rating: 4.4,
      reviewCount: 78,
      distanceKm: 4.5,
      estimatedTime: '35 min',
      deliveryFee: '฿30',
      displayPrice: '฿120',
    ),
    MenuItemDto(
      id: 't6',
      restaurantId: '6',
      restaurantName: 'Feel Restaurant',
      title: 'Za Lone Rice Salad',
      price: 100.0,
      currency: '฿',
      imagePath:
          'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&h=600&fit=crop&auto=format',
      category: 'Rice',
      isFavorite: false,
      rating: 4.5,
      reviewCount: 87,
      distanceKm: 5.2,
      estimatedTime: '30 min',
      deliveryFee: '฿30',
      displayPrice: '฿100',
    ),
  ];
}
