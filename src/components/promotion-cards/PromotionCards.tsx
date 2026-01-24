
import React from 'react';
import { Swiper, SwiperSlide } from 'swiper/react';
import { Pagination } from 'swiper/modules';
import 'swiper/css';
import 'swiper/css/pagination';
import './PromotionCards.css';
import { useTranslation } from 'react-i18next';

// Generic placeholder images if assets aren't available yet or use what we have
const MOCK_IMAGE = '/assets/services/food.png'; // Reuse existing asset for now

const promotions = [
    {
        id: 1,
        type: 'blue',
        title: 'Discount for',
        highlight: 'Monday',
        subtitle: 'Save On Your First Order',
        image: 'https://pngimg.com/uploads/pizza/pizza_PNG44093.png'
    },
    {
        id: 2,
        type: 'red',
        title: 'Special Deal',
        highlight: '30% OFF',
        subtitle: 'For all lunch sets today',
        image: 'https://pngimg.com/uploads/salad/salad_PNG2815.png'
    },
    {
        id: 3,
        type: 'blue',
        title: 'Exclusive',
        highlight: 'Free Drink',
        subtitle: 'With any main course',
        image: 'https://pngimg.com/uploads/juice/juice_PNG7186.png'
    },
];

const PromotionCards: React.FC = () => {
    const { t } = useTranslation();

    return (
        <div className="promotion-cards-container">
            <div className="section-header">
                <div className="section-title">
                    {t('section_special_promotion')}
                </div>
                <a href="#" className="see-more-link">{t('section_see_more')}</a>
            </div>
            <Swiper
                modules={[Pagination]}
                pagination={{ clickable: true }}
                spaceBetween={16}
                slidesPerView={1.2}
                breakpoints={{
                    640: { slidesPerView: 2.2 },
                    768: { slidesPerView: 3.2 }
                }}
                className="promotion-swiper"
            >
                {promotions.map((promo) => (
                    <SwiperSlide key={promo.id}>
                        <div className={`promo-card ${promo.type}`}>
                            <div className="promo-content">
                                <div className="promo-title">{promo.title}</div>
                                <div className="promo-highlight">{promo.highlight}</div>
                                <div className="promo-subtitle">{promo.subtitle}</div>
                                <button className="promo-btn">Order Now</button>
                            </div>
                            <div className="promo-image-wrapper">
                                <img src={promo.image} alt="promo" className="promo-image" />
                            </div>
                        </div>
                    </SwiperSlide>
                ))}
            </Swiper>
        </div>
    );
};

export default PromotionCards;
