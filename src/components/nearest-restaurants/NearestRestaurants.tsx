import React, { useState } from 'react';
import { useHistory } from 'react-router-dom';
import { Swiper, SwiperSlide } from 'swiper/react';
import { useTranslation } from 'react-i18next';
import { Heart, Clock, Star, Car } from '@phosphor-icons/react';
import 'swiper/css';
import './NearestRestaurants.css';

const restaurants = [
    {
        id: 1,
        name: 'Inle Traditional Food',
        distance: '2.5km',
        tag: 'Best Choice',
        time: '20-35 min',
        rating: 4.8,
        ratingCount: '200+',
        image: 'https://loremflickr.com/600/400/food,burmese?random=1'
    },
    {
        id: 2,
        name: 'Feel Myanmar',
        distance: '3.0km',
        tag: 'Authentic',
        time: '30-45 min',
        rating: 4.5,
        ratingCount: '500+',
        image: 'https://loremflickr.com/600/400/curry,asia?random=2'
    },
    {
        id: 3,
        name: 'Shwe Htee Restaurant',
        distance: '1.8km',
        tag: 'Shan Style',
        time: '15-25 min',
        rating: 4.7,
        ratingCount: '120+',
        image: 'https://loremflickr.com/600/400/noodle,soup?random=3'
    },
    {
        id: 4,
        name: 'Kalyana Restaurant',
        distance: '4.2km',
        tag: 'Popular',
        time: '35-50 min',
        rating: 4.9,
        ratingCount: '300+',
        image: 'https://loremflickr.com/600/400/restaurant,food?random=4'
    },
    {
        id: 5,
        name: 'Mandalay Food House',
        distance: '2.0km',
        tag: 'Cozy',
        time: '25-40 min',
        rating: 4.6,
        ratingCount: '150+',
        image: 'https://loremflickr.com/600/400/dish,meal?random=5'
    },
    {
        id: 6,
        name: 'AYAR House',
        distance: '5.5km',
        tag: 'Cultural',
        time: '40-55 min',
        rating: 4.4,
        ratingCount: '80+',
        image: 'https://loremflickr.com/600/400/dining,asian?random=6'
    },
    {
        id: 7,
        name: 'The Burma Food House',
        distance: '6.0km',
        tag: 'Kyay Oh',
        time: '45-60 min',
        rating: 4.3,
        ratingCount: '90+',
        image: 'https://loremflickr.com/600/400/lunch,dinner?random=7'
    },
    {
        id: 8,
        name: 'Tong Pai Shan',
        distance: '3.5km',
        tag: 'Shan Noodle',
        time: '30-45 min',
        rating: 4.7,
        ratingCount: '180+',
        image: 'https://loremflickr.com/600/400/cooking,burmese?random=8'
    },
    {
        id: 9,
        name: 'Bagan Myay',
        distance: '4.0km',
        tag: 'New & Hot',
        time: '35-50 min',
        rating: 4.5,
        ratingCount: '100+',
        image: 'https://loremflickr.com/600/400/rice,curry?random=9'
    },
    {
        id: 10,
        name: 'Mona\'s Restaurant',
        distance: '2.8km',
        tag: 'Street Food',
        time: '20-30 min',
        rating: 4.8,
        ratingCount: '250+',
        image: 'https://loremflickr.com/600/400/market,food?random=10'
    }
];

const NearestRestaurants: React.FC = () => {
    const history = useHistory();
    const { t } = useTranslation();
    const [likedItems, setLikedItems] = useState<Set<number>>(new Set());

    const toggleLike = (id: number) => {
        setLikedItems(prev => {
            const newSet = new Set(prev);
            if (newSet.has(id)) {
                newSet.delete(id);
            } else {
                newSet.add(id);
            }
            return newSet;
        });
    };

    return (
        <div className="nr-container">
            <div className="nr-header">
                <div className="nr-title">{t('section_nearest_restaurant')}</div>
                <a href="#" className="nr-see-more">{t('section_see_more')}</a>
            </div>
            
            <Swiper
                spaceBetween={16}
                slidesPerView={1.6}
                breakpoints={{
                    640: { slidesPerView: 2.2 },
                    768: { slidesPerView: 3.2 }
                }}
                className="nr-swiper"
            >
                {restaurants.map((restaurant) => (
                    <SwiperSlide key={restaurant.id}>
                        <div className="nr-card" onClick={() => history.push('/shop-detail')}>
                            <div className="nr-image-wrapper">
                                <img src={restaurant.image} alt={restaurant.name} className="nr-image" />
                                
                                <div className="nr-heart-btn" onClick={(e) => {
                                    e.stopPropagation();
                                    toggleLike(restaurant.id);
                                }}>
                                    <Heart 
                                        size={20}
                                        weight={likedItems.has(restaurant.id) ? 'fill' : 'regular'}
                                        color={likedItems.has(restaurant.id) ? '#EF4982' : 'white'}
                                    />
                                </div>
                            </div>
                            
                            <div className="nr-info">
                                <div className="nr-name-row">
                                    <div className="nr-name">{restaurant.name}</div>
                                </div>
                                <div className="nr-rating-row">
                                    <span style={{ color: '#6b7280' }}>{restaurant.tag}</span>
                                    <span>•</span>
                                    <span>{restaurant.rating}</span>
                                    <Star size={14} weight="fill" className="nr-rating-star" />
                                </div>
                                <div className="nr-meta-row">
                                    <Car size={18} className="nr-meta-icon" />
                                    <span>{restaurant.distance}</span>
                                </div>
                            </div>
                        </div>
                    </SwiperSlide>
                ))}
            </Swiper>
        </div>
    );
};

export default NearestRestaurants;
