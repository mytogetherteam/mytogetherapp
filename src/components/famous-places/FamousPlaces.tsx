import React from 'react';
import { Swiper, SwiperSlide } from 'swiper/react';
import { useTranslation } from 'react-i18next';
import 'swiper/css';
import './FamousPlaces.css';

const places = [
    {
        id: 1,
        name: 'Siam Paragon',
        location: 'Shopping Mall',
        description: 'A premier luxury shopping mall with high-end brands and the largest aquarium in SE Asia.',
        image: 'https://loremflickr.com/600/400/mall,shopping?random=1'
    },
    {
        id: 2,
        name: 'CentralWorld',
        location: 'Shopping Mall',
        description: 'One of the largest shopping complexes in the world, offering a vast range of shops and dining.',
        image: 'https://loremflickr.com/600/400/center,mall?random=2'
    },
    {
        id: 3,
        name: 'ICONSIAM',
        location: 'Riverside Mall',
        description: 'Iconic riverside destination featuring an indoor floating market and stunning city views.',
        image: 'https://loremflickr.com/600/400/river,mall?random=3'
    },
    {
        id: 4,
        name: 'Lumpini Park',
        location: 'Public Park',
        description: 'Bangkok’s green lung, perfect for jogging, relaxing, and spotting monitor lizards.',
        image: 'https://loremflickr.com/600/400/park,green?random=4'
    },
    {
        id: 5,
        name: 'Benjakitti Park',
        location: 'Forest Park',
        description: 'A massive forest park ideal for cycling and evening walks with skyline views.',
        image: 'https://loremflickr.com/600/400/forest,park?random=5'
    },
    {
        id: 6,
        name: 'Chatuchak Market',
        location: 'Weekend Market',
        description: 'World-famous weekend market with over 15,000 stalls selling everything imaginable.',
        image: 'https://loremflickr.com/600/400/market,stall?random=6'
    },
    {
        id: 7,
        name: 'Asiatique',
        location: 'Night Market',
        description: 'Open-air mall by the river with a giant ferris wheel and vibrant night markets.',
        image: 'https://loremflickr.com/600/400/night,market?random=7'
    },
    {
        id: 8,
        name: 'Pratunam Market',
        location: 'Wholesale Market',
        description: 'Bustling wholesale fashion market known for affordable clothing and accessories.',
        image: 'https://loremflickr.com/600/400/clothes,market?random=8'
    },
    {
        id: 9,
        name: 'Chinatown',
        location: 'Street Food',
        description: 'A food paradise at night, famous for its vibrant street food stalls and gold shops.',
        image: 'https://loremflickr.com/600/400/chinatown,food?random=9'
    },
    {
        id: 10,
        name: 'EmQuartier',
        location: 'Luxury Mall',
        description: 'Futuristic mall with a beautiful waterfall and hanging garden in the city center.',
        image: 'https://loremflickr.com/600/400/luxury,mall?random=10'
    }
];

const FamousPlaces: React.FC = () => {
  const { t } = useTranslation();

  return (
    <div className="famous-places-container">
      <div className="fp-header">
        <div className="fp-title">{t('section_top_places')}</div>
        <a href="#" className="fp-see-more">{t('section_see_more')}</a>
      </div>
            
            <Swiper
                spaceBetween={16}
                slidesPerView={1.1} /* Show a peek of the next slide */
                centeredSlides={true} /* Center the active slide */
                loop={true} /* allow infinite loop */
                className="fp-swiper"
            >
                {places.map((place) => (
                    <SwiperSlide key={place.id}>
                        <div className="fp-card">
                            <div className="fp-image-wrapper">
                                <img src={place.image} alt={place.name} className="fp-image" />
                            </div>
                            <div className="fp-content">
                                <div className="fp-name">{place.name}</div>
                                <div className="fp-location">{place.location}</div>
                                <div className="fp-description">{place.description}</div>
                            </div>
                        </div>
                    </SwiperSlide>
                ))}
            </Swiper>
        </div>
    );
};

export default FamousPlaces;
