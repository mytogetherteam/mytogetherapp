class DemoFoodSearchData {
  static const List<Map<String, String>> categories = [
    {'name': 'Lunch', 'emoji': '🍔'},
    {'name': 'Dinner', 'emoji': '🍝'},
    {'name': 'Snacks', 'emoji': '🍿'},
    {'name': 'Desserts', 'emoji': '🍰'},
    {'name': 'Brunch', 'emoji': '🥂'},
    {'name': 'Appetizers', 'emoji': '🍤'},
    {'name': 'Salads', 'emoji': '🥗'},
    {'name': 'Beverages', 'emoji': '🍹'},
    {'name': 'Street Food', 'emoji': '🌭'},
    {'name': 'Fast Food', 'emoji': '🍟'},
    {'name': 'Gourmet', 'emoji': '🍽️'},
    {'name': 'Vegan', 'emoji': '🥑'},
    {'name': 'Gluten-Free', 'emoji': '🍚'},
    {'name': 'Comfort Food', 'emoji': '🍜'},
    {'name': 'Seafood', 'emoji': '🦞'},
    {'name': 'Barbecue', 'emoji': '🍗'},
  ];

  static const List<String> recentSearches = [
    'KFC', 'Lotteria', 'Mr. Jerry BBQ', 'နေပြည်တော်စာရိန်မာထမင်းဆိုင်'
  ];

  static const List<String> suggestions = [
    'Tea & Coffee', 'Starbucks coffee', 'Amazon Cafe'
  ];

  static const List<Map<String, dynamic>> typingRestaurants = [
    {
      'id': '1',
      'name': 'Bistro Bliss',
      'rating': 4.7,
      'time': '40min',
      'distance': '2.0km',
      'image': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&q=80&w=200&h=200',
    },
    {
      'id': '2',
      'name': 'Culinary Corner',
      'rating': 4.7,
      'time': '40min',
      'distance': '2.0km',
      'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=200&h=200',
    },
    {
      'id': '3',
      'name': 'Savory Haven',
      'rating': 4.7,
      'time': '40min',
      'distance': '2.0km',
      'image': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&q=80&w=200&h=200',
    },
    {
      'id': '4',
      'name': 'Bistro Bliss',
      'rating': 4.7,
      'time': '40min',
      'distance': '2.0km',
      'image': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&q=80&w=200&h=200',
    },
    {
      'id': '5',
      'name': 'Culinary Corner',
      'rating': 4.7,
      'time': '40min',
      'distance': '2.0km',
      'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=200&h=200',
    },
    {
      'id': '6',
      'name': 'Savory Haven',
      'rating': 4.7,
      'time': '40min',
      'distance': '2.0km',
      'image': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&q=80&w=200&h=200',
    },
  ];

  static const List<Map<String, dynamic>> resultRestaurants = [
    {
      'id': 'kfc',
      'name': 'KFC',
      'logo': 'https://upload.wikimedia.org/wikipedia/en/thumb/b/bf/KFC_logo.svg/1024px-KFC_logo.svg.png',
      'rating': 4.7,
      'time': '40min',
      'distance': '2.0km',
      'badges': ['20% off select items', 'Free Deli'],
      'menuItems': [
        {
          'id': 'kfc_1',
          'name': 'Crispy Chicken Fillet Burger',
          'price': 55.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'kfc_2',
          'name': 'Crispy Chicken Fillet Burger',
          'price': 55.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'kfc_3',
          'name': 'Spicy Tuna Sashimi',
          'price': 120.0,
          'originalPrice': 120.0,
          'image': 'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'kfc_4',
          'name': 'Vege Rolls',
          'price': 75.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&q=80&w=200&h=200'
        },
      ]
    },
    {
      'id': 'bk',
      'name': 'Burger King',
      'logo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/Burger_King_2020.svg/1024px-Burger_King_2020.svg.png',
      'rating': 4.8,
      'time': '31min',
      'distance': '1.2km',
      'badges': ['20% off select items'],
      'menuItems': [
        {
          'id': 'bk_1',
          'name': 'Crispy Chicken Fillet Burger',
          'price': 55.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'bk_2',
          'name': 'Crispy Chicken Fillet Burger',
          'price': 55.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'bk_3',
          'name': 'Spicy Tuna Sashimi',
          'price': 120.0,
          'originalPrice': 120.0,
          'image': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'bk_4',
          'name': 'Vege Rolls',
          'price': 75.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1493770348161-369560ae357d?auto=format&fit=crop&q=80&w=200&h=200'
        },
      ]
    },
    {
      'id': 'ph',
      'name': 'Pizza Hut',
      'logo': 'https://upload.wikimedia.org/wikipedia/sco/thumb/d/d2/Pizza_Hut_logo.svg/1024px-Pizza_Hut_logo.svg.png',
      'rating': 4.5,
      'time': '25min',
      'distance': '0.9km',
      'badges': [],
      'menuItems': [
        {
          'id': 'ph_1',
          'name': 'Crispy Chicken Fillet Burger',
          'price': 55.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'ph_2',
          'name': 'Crispy Chicken Fillet Burger',
          'price': 55.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'ph_3',
          'name': 'Spicy Tuna Sashimi',
          'price': 120.0,
          'originalPrice': 120.0,
          'image': 'https://images.unsplash.com/photo-1590947132387-155cc02f3212?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'ph_4',
          'name': 'Vege Rolls',
          'price': 75.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&q=80&w=200&h=200'
        },
      ]
    },
    {
      'id': 'tb',
      'name': 'Taco Bell',
      'logo': 'https://upload.wikimedia.org/wikipedia/en/thumb/b/b3/Taco_Bell_2016.svg/1024px-Taco_Bell_2016.svg.png',
      'rating': 4.3,
      'time': '20min',
      'distance': '1.5km',
      'badges': [],
      'menuItems': [
        {
          'id': 'tb_1',
          'name': 'Crispy Chicken Fillet Burger',
          'price': 55.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'tb_2',
          'name': 'Crispy Chicken Fillet Burger',
          'price': 55.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1565299507177-b08bcbedba68?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'tb_3',
          'name': 'Spicy Tuna Sashimi',
          'price': 120.0,
          'originalPrice': 120.0,
          'image': 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&q=80&w=200&h=200'
        },
        {
          'id': 'tb_4',
          'name': 'Vege Rolls',
          'price': 75.0,
          'originalPrice': 75.0,
          'image': 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&q=80&w=200&h=200'
        },
      ]
    },
  ];
}
