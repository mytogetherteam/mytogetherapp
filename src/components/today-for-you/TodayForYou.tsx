import { IonCol, IonGrid, IonRow } from '@ionic/react';
import { Heart } from '@phosphor-icons/react';
import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import './TodayForYou.css';
import MenuDetailModal from '../../components/menu-detail-modal/MenuDetailModal';
import { MenuItem } from '../../types/MenuTypes';

// Online image URLs for Myanmar food (using loremflickr for reliability)
const products: MenuItem[] = [
    { 
        id: 101, name: 'Traditional Mohinga', price: '60 THB', category: 'Mohinga', image: 'https://pinkysnowfoods.co.uk/cdn/shop/files/A5A48E2A-5072-489B-B768-95EB2EAB65F3.webp?v=1723143581&width=1445', isPopular: true,
        description: 'Myanmar\'s national dish. Rice noodles in a rich fish broth, garnished with crispy fritters and egg.',
        addons: [{name: 'Extra Fish', price: '+20 THB'}, {name: 'Duck Egg', price: '+15 THB'}, {name: 'Fried Gourd', price: '+10 THB'}, {name: 'Fish Cake', price: '+10 THB'}],
        relatedItems: [
                { id: 105, name: 'Iced Milk Tea', price: '35 THB', image: 'https://loremflickr.com/600/400/tea,drink?random=1' },
                { id: 108, name: 'Fried Tofu', price: '30 THB', image: 'https://loremflickr.com/600/400/tofu,food?random=3' }
        ]
    },
    { 
        id: 102, name: 'Shan Noodle Soup', price: '50 THB', category: 'Noodles', image: 'https://delishglobe.com/wp-content/uploads/2025/02/Shan-Noodles.png', isPopular: true,
        description: 'Sticky rice noodles with chicken or pork in a light tomato curry, served with soup or dry.',
        addons: [{name: 'Extra Pork', price: '+20 THB'}, {name: 'Pickled Mustard', price: '+5 THB'}, {name: 'Fried Tofu', price: '+10 THB'}],
        sizes: [{name: 'Regular', price: '50 THB'}, {name: 'Large', price: '70 THB'}]
    },
    { 
        id: 103, name: 'Tea Leaf Salad', price: '45 THB', category: 'Salads', image: 'https://upload.wikimedia.org/wikipedia/commons/7/72/Green_tea_and_peanut_nibbles_%2810808703485%29.jpg', isPopular: false,
        description: 'Fermented tea leaves mixed with crunchy beans, garlic, nuts, and oil. A unique Burmese delicacy.',
        addons: [{name: 'Double Beans', price: '+10 THB'}, {name: 'Extra Tomato', price: '+5 THB'}, {name: 'Spicy Chilies', price: 'Free'}]
    },
    { 
        id: 104, name: 'Chicken Curry Set', price: '120 THB', category: 'Curries', image: 'https://www.cookeatworld.com/wp-content/uploads/2019/11/Burmese-Chicken-10.jpg', isPopular: false,
        description: 'Oily and rich Burmese style chicken curry served with rice and side vegetables.',
        addons: [{name: 'Extra Rice', price: '+10 THB'}, {name: 'Vegetable Side', price: '+15 THB'}]
    },
    { 
        id: 106, name: 'Coconut Noodle', price: '55 THB', category: 'Noodles', image: 'https://clubrangoon.com.hk/wp-content/uploads/2025/04/ohn-no-khao-swe-coconut-chicken-noodle-soup-recipe-1745526173.jpg', isPopular: false,
        description: 'Wheat noodles in a creamy coconut chicken soup, garnished with crispy noodles and onions.',
        addons: [{name: 'Extra Chicken', price: '+20 THB'}, {name: 'Crispy Fritters', price: '+10 THB'}]
    },
    { 
        id: 107, name: 'Nan Gyi Thoke', price: '60 THB', category: 'Salads', image: 'https://clubrangoon.com.hk/wp-content/uploads/2025/04/burmese-nan-gyi-thoke-recipe-1745525992.jpg', isPopular: true,
            description: 'Thick rice round noodles mixed with chicken curry gravy.',
        addons: [{name: 'Extra Chicken', price: '+20 THB'}, {name: 'Boiled Egg', price: '+10 THB'}]
    }
];

const TodayForYou: React.FC = () => {
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

    const [selectedItem, setSelectedItem] = useState<MenuItem | null>(null);

    return (
        <div className="today-for-you-container">
            <div className="tfy-header">
                <div className="tfy-title">{t('section_today_for_you')}</div>
                <a href="#" className="tfy-refresh-link">{t('section_see_more')}</a>
            </div>
            
            <IonGrid className="ion-no-padding">
                <IonRow>
                    {products.map((product) => (
                        <IonCol size="6" key={product.id} style={{ padding: '6px' }}>
                            <div className="tfy-card" onClick={() => setSelectedItem(product)}>
                                <div className="tfy-image-wrapper">
                                    <img src={product.image} alt={product.name} className="tfy-image" />
                                    <div className="tfy-heart-btn" onClick={(e) => { e.stopPropagation(); toggleLike(product.id); }}>
                                        <Heart 
                                            size={24}
                                            weight={likedItems.has(product.id) ? 'fill' : 'regular'}
                                            color={likedItems.has(product.id) ? '#ff383c' : '#FFFFFF'}
                                        />
                                    </div>
                                </div>
                                <div className="tfy-content">
                                    <div className="tfy-item-title">{product.name}</div>
                                    <div className="tfy-item-price">{product.price}</div>
                                </div>
                            </div>
                        </IonCol>
                    ))}
                </IonRow>
            </IonGrid>

            {/* Menu Detail Modal */}
            <MenuDetailModal 
                isOpen={!!selectedItem} 
                onDismiss={() => setSelectedItem(null)} 
                item={selectedItem}
            />
        </div>
    );
};

export default TodayForYou;
