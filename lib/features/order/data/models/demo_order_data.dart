class DemoOrder {
  final String id;
  final String shopName;
  final String shopLogoUrl;
  final String type; // 'active', 'completed', 'cancelled'
  final String priceDisplay;
  final int itemCount;
  final String dateDisplay;
  final List<String> itemThumbnails;

  // Custom states for Completed
  final bool hasRatingRow;
  final bool isRated;
  final int ratingScore;

  // Custom states for Active
  final String deliveryStatusTitle;
  final String deliveryStatusSubtitle;

  DemoOrder({
    required this.id,
    required this.shopName,
    required this.shopLogoUrl,
    required this.type,
    required this.priceDisplay,
    required this.itemCount,
    required this.dateDisplay,
    required this.itemThumbnails,
    this.hasRatingRow = true,
    this.isRated = false,
    this.ratingScore = 0,
    this.deliveryStatusTitle = '',
    this.deliveryStatusSubtitle = '',
  });
}

// SPECIFIC High-Quality Unsplash IDs for Restaurants & Food (NOT RANDOM)
const String _shopLogoLotteria = 'https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?q=80&w=200&h=200&auto=format&fit=crop'; // Burgers
const String _shopLogoStarbucks = 'https://images.unsplash.com/photo-1544148103-0773bf10d330?q=80&w=200&h=200&auto=format&fit=crop'; // Coffee shop
const String _shopLogoKFC = 'https://images.unsplash.com/photo-1562967082-d5df244dcef5?q=80&w=200&h=200&auto=format&fit=crop'; // Fried chicken
const String _shopLogoBurgerKing = 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=200&h=200&auto=format&fit=crop'; // Burger icon

const List<String> _foodThumbs = [
  'https://images.unsplash.com/photo-1513104890138-7c749659a591?q=80&w=300&h=300&auto=format&fit=crop', // Pizza
  'https://images.unsplash.com/photo-1551024601-bec78aea704b?q=80&w=300&h=300&auto=format&fit=crop', // Cake
  'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?q=80&w=300&h=300&auto=format&fit=crop', // Pasta
  'https://images.unsplash.com/photo-1541167760496-1628856ab772?q=80&w=300&h=300&auto=format&fit=crop', // Coffee cup
  'https://images.unsplash.com/photo-1540331547168-8b63109225b7?q=80&w=300&h=300&auto=format&fit=crop', // Donuts
  'https://images.unsplash.com/photo-1460306855393-0410f61241c7?q=80&w=300&h=300&auto=format&fit=crop', // Burger with fries
  'https://images.unsplash.com/photo-1499028344343-cd173ffc68a9?q=80&w=300&h=300&auto=format&fit=crop', // Burger bun
];

final List<DemoOrder> demoCompletedOrders = [
  DemoOrder(
    id: 'c1',
    shopName: 'Lotteria',
    shopLogoUrl: _shopLogoLotteria,
    type: 'completed',
    priceDisplay: '฿677',
    itemCount: 3,
    dateDisplay: 'Dec 18, 2025 at 2:48 AM',
    itemThumbnails: [_foodThumbs[0], _foodThumbs[1], _foodThumbs[2]],
    hasRatingRow: true,
    isRated: false,
  ),
  DemoOrder(
    id: 'c2',
    shopName: 'Starbucks',
    shopLogoUrl: _shopLogoStarbucks,
    type: 'completed',
    priceDisplay: '฿1,777',
    itemCount: 2,
    dateDisplay: 'Dec 17, 2025 at 8:30 AM',
    itemThumbnails: [_foodThumbs[3], _foodThumbs[4]],
    hasRatingRow: true,
    isRated: true,
    ratingScore: 4,
  ),
  DemoOrder(
    id: 'c3',
    shopName: 'Lotteria',
    shopLogoUrl: _shopLogoLotteria, // Using consistent logo
    type: 'completed',
    priceDisplay: '฿450',
    itemCount: 2,
    dateDisplay: 'Dec 16, 2025 at 1:15 PM',
    itemThumbnails: [_foodThumbs[2], _foodThumbs[5]],
    hasRatingRow: true,
    isRated: false,
  ),
  DemoOrder(
    id: 'c4',
    shopName: 'KFC',
    shopLogoUrl: _shopLogoKFC,
    type: 'completed',
    priceDisplay: '฿890',
    itemCount: 4,
    dateDisplay: 'Dec 15, 2025 at 7:00 PM',
    itemThumbnails: [_foodThumbs[0], _foodThumbs[6], _foodThumbs[1], _foodThumbs[2]],
    hasRatingRow: true,
    isRated: false,
  ),
  DemoOrder(
    id: 'c5',
    shopName: 'Burger King',
    shopLogoUrl: _shopLogoBurgerKing,
    type: 'completed',
    priceDisplay: '฿520',
    itemCount: 3,
    dateDisplay: 'Dec 14, 2025 at 12:45 PM',
    itemThumbnails: [_foodThumbs[3], _foodThumbs[4], _foodThumbs[5]],
    hasRatingRow: true,
    isRated: false,
  ),
];

final List<DemoOrder> demoCancelledOrders = [
  DemoOrder(
    id: 'ca1',
    shopName: 'Starbucks',
    shopLogoUrl: _shopLogoStarbucks,
    type: 'cancelled',
    priceDisplay: '฿1,200',
    itemCount: 4,
    dateDisplay: 'Dec 18, 2025 at 8:00 PM',
    itemThumbnails: [_foodThumbs[6], _foodThumbs[5], _foodThumbs[1], _foodThumbs[2]],
  ),
  DemoOrder(
    id: 'ca2',
    shopName: 'Lotteria',
    shopLogoUrl: _shopLogoLotteria,
    type: 'cancelled',
    priceDisplay: '฿320',
    itemCount: 2,
    dateDisplay: 'Dec 16, 2025 at 9:30 AM',
    itemThumbnails: [_foodThumbs[3], _foodThumbs[4]],
  ),
];

final List<DemoOrder> demoActiveOrders = [
  DemoOrder(
    id: 'a1',
    shopName: 'Starbucks',
    shopLogoUrl: _shopLogoStarbucks,
    type: 'active',
    priceDisplay: '฿750',
    itemCount: 3,
    dateDisplay: '',
    itemThumbnails: [_foodThumbs[4], _foodThumbs[5], _foodThumbs[6]],
    deliveryStatusTitle: 'Delivering to you',
    deliveryStatusSubtitle: 'Estimate arrival: 09:45 PM',
  ),
];
