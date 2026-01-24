import React, { useState } from 'react';
import { IonContent, IonHeader, IonPage, IonIcon, IonFooter, IonButton, IonSegment, IonSegmentButton, IonLabel } from '@ionic/react';
import { ArrowLeft, Heart, Star, MapPin, Clock, Phone, Globe, WifiHigh, Smiley, MapTrifold } from '@phosphor-icons/react';
import { useHistory } from 'react-router-dom';
import ShopMenu from './ShopMenu';
import './ShopDetail.css';

const ShopDetail: React.FC = () => {
  const history = useHistory();
  const [selectedSegment, setSelectedSegment] = useState<'overview' | 'menu' | 'reviews'>('overview');

  return (
    <IonPage className="shop-detail-page">
      <IonContent fullscreen>
        
        {/* Header Image Area */}
        <div className="shop-detail-header">
            <img src="https://loremflickr.com/600/400/food,burmese?random=1" alt="Shop Cover" className="shop-detail-header-img" />
            <div className="shop-detail-header-buttons">
                <div className="shop-header-btn" onClick={() => history.goBack()}>
                    <ArrowLeft size={24} />
                </div>
                <div className="shop-header-btn">
                    <Heart size={24} />
                </div>
            </div>
        </div>

        {/* Main Info Card */}
        <div className="shop-info-card">
            <div className="shop-title-row">
                <div className="shop-name">Sate Madura House</div>
                <div className="shop-rating-badge">
                    <Star size={14} weight="fill" />
                    <span>4.8</span>
                </div>
            </div>
            <div className="shop-cuisine">Asian</div>
            
            <div className="shop-meta-row">
                <div className="shop-meta-item">
                    <MapPin size={16} color="#EF4982" weight="fill" />
                    <span>0.8 km</span>
                </div>
                <div className="shop-meta-item">
                    <Clock size={16} color="#F59E0B" weight="fill" />
                    <span>15-25 min</span>
                </div>
                <div className="shop-open-status">
                    <div className="shop-open-dot"></div>
                    <span>Open now</span>
                </div>
            </div>
        </div>

        {/* Tabs / Segments */}
        <div className="shop-segments-container">
            <IonSegment 
                value={selectedSegment} 
                onIonChange={e => setSelectedSegment(e.detail.value as any)} 
                mode="ios" 
                scrollable={true}
            >
                <IonSegmentButton value="overview" className="shop-segment-btn">
                    <IonLabel>Overview</IonLabel>
                </IonSegmentButton>
                <IonSegmentButton value="menu" className="shop-segment-btn">
                    <IonLabel>Menu</IonLabel>
                </IonSegmentButton>
                <IonSegmentButton value="reviews" className="shop-segment-btn">
                    <IonLabel>Reviews</IonLabel>
                </IonSegmentButton>
            </IonSegment>
        </div>

        {selectedSegment === 'overview' && (
            <>
                {/* About / Description */}
                <div className="section-card" style={{ marginTop: '0' }}>
                    <div className="section-title">About</div>
                    <div className="shop-description">
                        Experience the authentic taste of Madura with our signature Sate. 
                        Grilled to perfection with secret spices passed down through generations. 
                        Perfect for family dining or a quick delicious meal.
                    </div>
                </div>

                {/* Contact & Location */}
                <div className="section-card">
                    <div className="section-title">Contact & Location</div>
                    
                    <div className="contact-item">
                        <div className="contact-icon-box">
                            <MapPin size={20} className="contact-icon" />
                        </div>
                        <div className="contact-details">
                            <span className="contact-label">Address</span>
                            <span className="contact-value">45 Food Court, Terminal 2</span>
                        </div>
                    </div>

                    <div className="contact-item">
                        <div className="contact-icon-box" style={{ background: '#FFF7E6' }}>
                            <Phone size={20} className="contact-icon orange" />
                        </div>
                        <div className="contact-details">
                            <span className="contact-label">Phone</span>
                            <span className="contact-value">+65 2345 6789</span>
                        </div>
                    </div>

                    <div className="contact-item">
                        <div className="contact-icon-box" style={{ background: '#EFF6FF' }}>
                            <Clock size={20} className="contact-icon blue" />
                        </div>
                        <div className="contact-details">
                            <span className="contact-label">Opening Hours</span>
                            <span className="contact-value">10:00 AM - 9:00 PM</span>
                        </div>
                    </div>
                </div>

                {/* Amenities */}
                <div className="section-card">
                    <div className="section-title">Amenities</div>
                    <div className="amenities-grid">
                        <div className="amenity-chip">
                            <WifiHigh size={18} className="amenity-icon" />
                            <span>Wi-Fi</span>
                        </div>
                        <div className="amenity-chip">
                            <Smiley size={18} className="amenity-icon" />
                            <span>High Chairs</span>
                        </div>
                    </div>
                </div>
            </>
        )}

        {selectedSegment === 'menu' && (
            <ShopMenu />
        )}
        
        {selectedSegment === 'reviews' && (
            <div style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                Reviews coming soon...
            </div>
        )}
        
        <div style={{ height: '20px' }}></div>

      </IonContent>

      <IonFooter className="ion-no-border">
        <div className="shop-footer">
            <IonButton expand="block" shape="round" className="view-map-btn">
                <span slot="start" style={{ display: 'flex', alignItems: 'center', marginRight: '8px' }}>
                    <MapTrifold size={20} />
                </span>
                View on Map
            </IonButton>
        </div>
      </IonFooter>
    </IonPage>
  );
};

export default ShopDetail;
