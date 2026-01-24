import React, { useState, useEffect } from 'react';
import { IonModal, IonContent, IonIcon, IonCheckbox, IonRippleEffect } from '@ionic/react';
import { Swiper, SwiperSlide } from 'swiper/react';
import 'swiper/css';
import { ArrowLeft, Heart, Star, Plus, Minus, ShoppingCart, Fire } from '@phosphor-icons/react';
import { useTranslation } from 'react-i18next';
import './MenuDetailModal.css';
import { MenuItem } from '../../types/MenuTypes';

interface MenuDetailModalProps {
    isOpen: boolean;
    onDismiss: () => void;
    item: MenuItem | null; 
}

const MenuDetailModal: React.FC<MenuDetailModalProps> = ({ isOpen, onDismiss, item }) => {
    const { t } = useTranslation();
    const [quantity, setQuantity] = useState(1);
    const [selectedSize, setSelectedSize] = useState<string>('');
    const [selectedSpice, setSelectedSpice] = useState<string>('');
    const [isFavorite, setIsFavorite] = useState(false);
    
    useEffect(() => {
        if (isOpen) {
            setQuantity(1);
            if (item?.sizes && item.sizes.length > 0) {
                setSelectedSize(item.sizes[0].name);
            }
             if (item?.spiceLevels && item.spiceLevels.length > 0) {
                setSelectedSpice(item.spiceLevels[1] || item.spiceLevels[0]); // Default to Medium if available
            }
        }
    }, [isOpen, item]);

    if (!item) return null;

    const sizes = item.sizes || [];
    const addons = item.addons || [];
    const spiceLevels = item.spiceLevels || [];
    const relatedItems = item.relatedItems || [];

    const decreaseQty = () => {
        if (quantity > 1) setQuantity(quantity - 1);
    };

    const increaseQty = () => setQuantity(quantity + 1);

    const renderSpiceIcons = (levelIndex: number) => {
        const icons = [];
        for (let i = 0; i <= levelIndex; i++) {
            icons.push(<Fire key={i} size={16} weight="fill" className="spice-icon" />);
        }
        return icons;
    };

    // Generate dynamic content based on item
    const description = item.description || `Indulge in our delicious ${item.name}. Prepared with premium ingredients to give you the authentic taste.`;
    
    // Deterministic random rating based on id (pseudo-random)
    const rating = (4.0 + (item.id % 10) / 10).toFixed(1);
    const reviewCount = 50 + (item.id * 7) % 200;

    return (
        <IonModal isOpen={isOpen} onDidDismiss={onDismiss} className="menu-detail-modal">
            {/* Fixed Buttons - Placed outside Content to stay fixed relative to Modal Viewport if needed, 
                but CSS position: fixed works inside IonContent too in some versions. 
                Ideally, place them here for z-index layering over content. */}
            <div className="menu-detail-header-btn back ion-activatable" onClick={onDismiss}>
                <ArrowLeft size={24} />
                <IonRippleEffect />
            </div>

            <div className="menu-detail-header-btn fav ion-activatable" onClick={() => setIsFavorite(!isFavorite)}>
                <Heart size={24} weight={isFavorite ? 'fill' : 'regular'} color={isFavorite ? '#dc2626' : 'currentColor'} />
                <IonRippleEffect />
            </div>

            <IonContent>
                {/* Header Image */}
                <div className="menu-detail-image-container">
                    <img src={item.image} alt={item.name} className="menu-detail-image" />
                </div>

                <div className="menu-detail-content">
                    {/* Info Card */}
                    <div className="menu-detail-info-card">
                        <div className="menu-detail-title-row">
                            <h2 className="menu-detail-title">{item.name}</h2>
                            <span className="menu-detail-price">{item.price}</span>
                        </div>
                        
                        <div className="menu-detail-subtitle">
                            <span>{item.category || 'Asian'}</span>
                            <span>•</span>
                            <div className="menu-detail-rating">
                                <Star size={16} weight="fill" />
                                {rating} ({reviewCount} {t('menu_detail.reviews')})
                            </div>
                        </div>

                        <p className="menu-detail-description">
                            {description}
                        </p>

                        <div className="menu-detail-tags">
                            <div className="menu-detail-tag high-protein">Popular</div>
                            <div className="menu-detail-tag vegetarian">Fresh</div>
                        </div>
                    </div>

                    {/* Size Selection */}
                    {sizes.length > 0 && (
                        <>
                            <div className="menu-detail-section-title">{t('menu_detail.select_size')}</div>
                            <div className="size-selector-row">
                                {sizes.map((size) => (
                                    <div 
                                        key={size.name} 
                                        className={`size-option-card ion-activatable ${selectedSize === size.name ? 'selected' : ''}`}
                                        onClick={() => setSelectedSize(size.name)}
                                    >
                                        <span className="size-name">{size.name}</span>
                                        <span className="size-price">{size.price}</span>
                                        <IonRippleEffect />
                                    </div>
                                ))}
                            </div>
                        </>
                    )}

                    {/* Add-ons */}
                    {addons.length > 0 && (
                        <>
                            <div className="menu-detail-section-title">{t('menu_detail.addons')}</div>
                            <div className="addons-container">
                                {addons.map((addon, index) => (
                                    <div key={index} className="addon-item">
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                                            <IonCheckbox mode="ios" />
                                            <span className="addon-label">{addon.name}</span>
                                        </div>
                                        <span className="addon-price">{addon.price}</span>
                                    </div>
                                ))}
                            </div>
                        </>
                    )}

                    {/* Spice Level */}
                    {spiceLevels.length > 0 && (
                        <>
                            <div className="menu-detail-section-title">{t('menu_detail.spice_level')}</div>
                            <div className="spice-level-row">
                                {spiceLevels.map((level, index) => (
                                    <div 
                                        key={level} 
                                        className={`spice-option-card ion-activatable ${selectedSpice === level ? 'selected' : ''}`}
                                        onClick={() => setSelectedSpice(level)}
                                    >
                                        <span className="size-name">{level}</span>
                                        <div className="spice-icon-row">
                                            {renderSpiceIcons(index)}
                                        </div>
                                        <IonRippleEffect />
                                    </div>
                                ))}
                            </div>
                        </>
                    )}

                    {/* Special Instructions */}
                    <div className="menu-detail-section-title">{t('menu_detail.special_instructions')}</div>
                    <div className="instructions-input-wrapper">
                        <textarea 
                            className="custom-textarea" 
                            placeholder={t('menu_detail.special_inst_placeholder')}
                        ></textarea>
                        <div style={{ textAlign: 'right', fontSize: '12px', color: '#9ca3af', marginTop: '4px' }}>0/200</div>
                    </div>

                    {/* Frequently Ordered Together */}
                    {relatedItems.length > 0 && (
                        <>
                            <div className="menu-detail-section-title">{t('menu_detail.frequently_ordered')}</div>
                            <div className="frequent-items-swiper-container">
                                <Swiper
                                    spaceBetween={12}
                                    slidesPerView={2.2}
                                    className="frequent-items-swiper"
                                >
                                    {relatedItems.map((fItem) => (
                                        <SwiperSlide key={fItem.id}>
                                            <div className="frequent-item-card">
                                                <img src={fItem.image} alt={fItem.name} className="frequent-item-image" />
                                                <div className="frequent-item-info">
                                                    <div className="frequent-item-name">{fItem.name}</div>
                                                    <div className="frequent-item-bottom">
                                                        <div className="frequent-item-price">{fItem.price}</div>
                                                        <div className="add-btn ion-activatable" style={{ width: '24px', height: '24px', fontSize: '16px', display:'flex', justifyContent:'center', alignItems:'center' }}>
                                                            <Plus size={16} />
                                                            <IonRippleEffect />
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </SwiperSlide>
                                    ))}
                                </Swiper>
                            </div>
                        </>
                    )}
                </div>
            </IonContent>

            {/* Sticky Footer */}
            <div className="menu-detail-footer">
                <div className="quantity-stepper">
                    <div className="qty-btn ion-activatable" onClick={decreaseQty}>
                        <Minus size={20} />
                        <IonRippleEffect />
                    </div>
                    <div className="qty-value">{quantity}</div>
                    <div className="qty-btn ion-activatable" onClick={increaseQty}>
                        <Plus size={20} />
                        <IonRippleEffect />
                    </div>
                </div>

                <button className="add-to-cart-large-btn ion-activatable">
                    <ShoppingCart size={20} />
                    {t('menu_detail.add_to_cart')} - {item.price}
                    <IonRippleEffect />
                </button>
            </div>
        </IonModal>
    );
};

export default MenuDetailModal;
