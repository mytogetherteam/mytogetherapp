import React, { useState, useEffect } from 'react';
import { IonGrid, IonRow, IonCol, IonSearchbar, IonIcon, IonRippleEffect, IonSelect, IonSelectOption } from '@ionic/react';
import { Heart, Plus, Faders } from '@phosphor-icons/react';
import './ShopMenu.css';
import MenuDetailModal from '../../components/menu-detail-modal/MenuDetailModal';

import { MenuItem } from '../../types/MenuTypes';

const categories = ['All', 'Mohinga', 'Noodles', 'Salads', 'Curries', 'Rice', 'Snacks', 'Drinks'];

const initialProducts: MenuItem[] = [
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
        id: 105, name: 'Iced Milk Tea', price: '35 THB', category: 'Drinks', image: 'https://loremflickr.com/600/400/tea,drink?random=1', isPopular: true,
        description: 'Sweet and creamy Burmese style milk tea, brewed strong.',
        sizes: [{name: 'Regular', price: '35 THB'}, {name: 'Large', price: '45 THB'}],
        addons: [{name: 'Extra Condensed Milk', price: '+5 THB'}, {name: 'Less Ice', price: 'Free'}]
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
    },
    { 
        id: 108, name: 'Fried Tofu', price: '30 THB', category: 'Snacks', image: 'https://loremflickr.com/600/400/tofu,food?random=3', isPopular: false,
        description: 'Crispy yellow tofu (made from chickpeas) served with a tangy tamarind dipping sauce.',
        addons: [{name: 'Spicy Sauce', price: 'Free'}, {name: 'Tamarind Sauce', price: 'Free'}]
    },
    { 
        id: 109, name: 'Lime Juice', price: '25 THB', category: 'Drinks', image: 'https://loremflickr.com/600/400/juice,lime?random=4', isPopular: false,
         sizes: [{name: 'Regular', price: '25 THB'}, {name: 'Large', price: '35 THB'}]
    },
    { 
        id: 110, name: 'Sticky Rice Cake', price: '20 THB', category: 'Snacks', image: 'https://loremflickr.com/600/400/cake,rice?random=5', isPopular: false,
        description: 'Traditional sweet sticky rice cake, often enjoyed with tea.'
    },
    { 
        id: 111, name: 'Duck Curry', price: '150 THB', category: 'Curries', image: 'https://loremflickr.com/600/400/curry,duck?random=6', isPopular: false 
    },
    { 
        id: 112, name: 'Dan Pauk', price: '130 THB', category: 'Rice', image: 'https://loremflickr.com/600/400/biryani,rice?random=7', isPopular: true,
        description: 'Burmese style Biryani with chicken or mutton.',
        addons: [{name: 'Mango Pickle', price: '+10 THB'}, {name: 'Extra Chicken', price: '+40 THB'}]
    },
];

const ShopMenu: React.FC = () => {
    const [searchText, setSearchText] = useState('');
    const [selectedCategory, setSelectedCategory] = useState('All');
    const [filteredProducts, setFilteredProducts] = useState(initialProducts);
    const [likedItems, setLikedItems] = useState<Set<number>>(new Set());
    const [selectedItem, setSelectedItem] = useState<MenuItem | null>(null);

    useEffect(() => {
        let result = initialProducts;

        // Filter by Category
        if (selectedCategory === 'Popular') {
            result = result.filter(p => p.isPopular);
        } else if (selectedCategory !== 'All') {
            result = result.filter(p => p.category === selectedCategory);
        }

        // Filter by Search
        if (searchText) {
            const lowerQuery = searchText.toLowerCase();
            result = result.filter(p => p.name.toLowerCase().includes(lowerQuery));
        }

        setFilteredProducts(result);
    }, [searchText, selectedCategory]);

    const toggleLike = (id: number) => {
        setLikedItems(prev => {
            const newSet = new Set(prev);
            if (newSet.has(id)) newSet.delete(id);
            else newSet.add(id);
            return newSet;
        });
    };

    return (
        <div className="shop-menu-container">
            <div className="menu-sticky-header">
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                    {/* Search Bar */}
                    <IonSearchbar 
                        value={searchText} 
                        onIonInput={e => setSearchText(e.detail.value!)} 
                        className="menu-search-bar"
                        placeholder="Search menu..."
                        style={{ margin: 0, flex: 1 }}
                    />
                    
                    {/* Filter Dropdown */}
                    <div className="filter-dropdown-wrapper">
                         <IonSelect 
                            interface="popover" 
                            placeholder="Filter" 
                            className="custom-filter-select"
                            onIonChange={(e) => console.log('Filter:', e.detail.value)}
                         >
                            <IonSelectOption value="recommended">Recommended</IonSelectOption>
                            <IonSelectOption value="price_low">Price: Low to High</IonSelectOption>
                            <IonSelectOption value="price_high">Price: High to Low</IonSelectOption>
                            <IonSelectOption value="rating">Top Rated</IonSelectOption>
                         </IonSelect>
                         <div className="filter-icon-overlay">
                            <Faders size={18} />
                         </div>
                    </div>
                </div>

                {/* Categories */}
                <div className="menu-categories-wrapper">
                    {categories.map(cat => (
                        <div 
                            key={cat} 
                            className={`menu-category-chip ion-activatable ${selectedCategory === cat ? 'active' : ''}`}
                            onClick={() => setSelectedCategory(cat)}
                        >
                            {cat}
                            <IonRippleEffect />
                        </div>
                    ))}
                </div>
            </div>

            {/* Product Grid */}
            <IonGrid className="ion-no-padding">
                <IonRow key={selectedCategory}>
                    {filteredProducts.map((product, index) => (
                        <IonCol size="6" key={product.id} style={{ padding: '8px' }}>
                            <div 
                                className="menu-card ion-activatable" 
                                style={{ animationDelay: `${index * 0.05}s` }}
                                onClick={() => setSelectedItem(product)}
                            >
                                <div className="menu-image-wrapper">
                                    <img src={product.image} alt={product.name} className="menu-image" />
                                    
                                    <div className="menu-heart-btn" onClick={(e) => { e.stopPropagation(); toggleLike(product.id); }}>
                                        <Heart 
                                            size={20} 
                                            weight={likedItems.has(product.id) ? 'fill' : 'regular'}
                                            color={likedItems.has(product.id) ? '#EF4982' : '#111'}
                                        />
                                    </div>
                                    
                                    {product.isPopular && (
                                        <div className="menu-best-seller">Top Rated</div>
                                    )}
                                </div>
                                
                                <div className="menu-content">
                                    <div className="menu-item-title">{product.name}</div>
                                    <div className="menu-item-bottom">
                                        <div className="menu-item-price">{product.price}</div>
                                        <div className="add-btn" style={{ display:'flex', justifyContent:'center', alignItems:'center' }}>
                                            <Plus size={16} />
                                        </div>
                                    </div>
                                    <IonRippleEffect />
                                </div>
                            </div>
                        </IonCol>
                    ))}
                    {filteredProducts.length === 0 && (
                        <div style={{ width: '100%', textAlign: 'center', padding: '20px', color: '#888' }}>
                            No items found.
                        </div>
                    )}
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

export default ShopMenu;
