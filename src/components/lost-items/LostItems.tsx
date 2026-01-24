import React from 'react';
import { Swiper, SwiperSlide } from 'swiper/react';
import 'swiper/css';
import { MapPin, Clock } from '@phosphor-icons/react';
import { useTranslation } from 'react-i18next';
import './LostItems.css';

const items = [
    {
        id: 1,
        name: 'Brown Leather Wallet',
        location: 'Central Park',
        time: '2 hours ago',
        image: 'https://loremflickr.com/400/300/wallet,leather?random=1'
    },
    {
        id: 2,
        name: 'Car Keys (Toyota)',
        location: 'Siam Paragon Parking',
        time: '5 hours ago',
        image: 'https://loremflickr.com/400/300/keys,car?random=2'
    },
    {
        id: 3,
        name: 'Ginger Cat',
        location: 'Sukhumvit Soi 11',
        time: '1 day ago',
        image: 'https://loremflickr.com/400/300/cat,ginger?random=3'
    },
    {
        id: 4,
        name: 'Blue iPhone 13',
        location: 'BTS Asok',
        time: '30 mins ago',
        image: 'https://loremflickr.com/400/300/iphone,blue?random=4'
    },
    {
        id: 5,
        name: 'Black Backpack',
        location: 'Lumpini Park',
        time: '3 hours ago',
        image: 'https://loremflickr.com/400/300/backpack,black?random=5'
    }
];

const LostItems: React.FC = () => {
    const { t } = useTranslation();
    return (
        <div className="lost-items-container">
            <div className="li-header">
                <div className="li-title">{t('section_lost_items')}</div>
                <a href="#" className="li-see-more">{t('section_see_more')}</a>
            </div>
            
            <Swiper
                spaceBetween={12}
                slidesPerView={1.2} /* Wider horizontal cards */
                breakpoints={{
                    640: { slidesPerView: 2.2 },
                    768: { slidesPerView: 3.2 }
                }}
                className="li-swiper"
            >
                {items.map((item) => (
                    <SwiperSlide key={item.id}>
                        <div className="li-card">
                            <div className="li-image-wrapper">
                                <span className="li-badge">{t('lost_item_badge')}</span>
                                <img src={item.image} alt={item.name} className="li-image" />
                            </div>
                            <div className="li-content">
                                <div className="li-name">{item.name}</div>
                                <div className="li-location">
                                    <MapPin size={16} color="#EF4982" weight="fill" style={{ marginRight: '4px' }} />
                                    {item.location}
                                </div>
                                <div className="li-time">
                                    <Clock size={16} style={{ marginRight: '4px' }} />
                                    {t('posted_prefix')} {item.time}
                                </div>
                            </div>
                        </div>
                    </SwiperSlide>
                ))}
            </Swiper>
        </div>
    );
};

export default LostItems;
