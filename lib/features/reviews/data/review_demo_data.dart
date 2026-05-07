import 'models/review_model.dart';

class ReviewDemoData {
  static final List<Review> reviews = [
    Review(
      id: '1',
      userAvatar: 'https://i.pravatar.cc/150?img=1',
      userName: 'Emerson Stanton',
      rating: 5,
      text: 'Lorem ipsum dolor sit amet consectetur. Ultricies faucibus nunc sed malesuada turpis sed egestas convallis vulputate.',
      photoUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
      date: DateTime(2025, 12, 25),
      tags: ['Taste', 'Customer Service'],
    ),
    Review(
      id: '2',
      userAvatar: 'https://i.pravatar.cc/150?img=2',
      userName: 'Allison Septimus',
      rating: 4,
      text: 'Lorem ipsum dolor sit amet consectetur. Ultricies faucibus nunc sed malesuada turpis sed egestas convallis vulputate.',
      photoUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
      date: DateTime(2025, 12, 26),
      tags: [],
    ),
    Review(
      id: '3',
      userAvatar: 'https://i.pravatar.cc/150?img=3',
      userName: 'Talan Ekstrom Bothman',
      rating: 5,
      text: 'Lorem ipsum dolor sit amet consectetur. Ultricies faucibus nunc sed malesuada turpis sed egestas convallis vulputate.',
      photoUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
      date: DateTime(2025, 12, 25),
      tags: [],
    ),
    Review(
      id: '4',
      userAvatar: 'https://i.pravatar.cc/150?img=4',
      userName: 'Jaxson Westervelt',
      rating: 4,
      text: 'Lorem ipsum dolor sit amet consectetur. Ultricies faucibus nunc sed malesuada turpis sed egestas convallis vulputate.',
      photoUrl: '', // No photo, but specifications say "full-width photo at top". The demo shows all having photos, but let's see. Let's provide a photo. 
      date: DateTime(2025, 12, 25),
      tags: ['Taste', 'Customer Service'],
    ),
  ];

  static final List<String> writeReviewTags = [
    'Taste',
    'Food Quality',
    'Customer Service',
    'Cleanliness',
    'Fast Service',
    'Order accuracy',
    // kasdf
  ];
}
