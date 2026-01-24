import { IonContent, IonHeader, IonPage, IonRefresher, IonRefresherContent, RefresherEventDetail, IonToolbar, IonButtons, IonButton, IonBadge } from '@ionic/react';
import React from 'react';
import { useTranslation } from 'react-i18next';
import { MagnifyingGlass, Bell } from '@phosphor-icons/react';
import { useHistory } from 'react-router-dom';

import QuickServices from '../../components/quick-services/QuickServices';
import PromotionCards from '../../components/promotion-cards/PromotionCards';
import TodayForYou from '../../components/today-for-you/TodayForYou';
import NearestRestaurants from '../../components/nearest-restaurants/NearestRestaurants';
import FamousPlaces from '../../components/famous-places/FamousPlaces';
import LostItems from '../../components/lost-items/LostItems';
import './Home.css';

const Home: React.FC = () => {
  const { t } = useTranslation();
  const history = useHistory();

  const handleRefresh = (event: CustomEvent<RefresherEventDetail>) => {
    setTimeout(() => {
        // Any data reload logic goes here
        event.detail.complete();
    }, 2000);
  };

  return (
    <IonPage className="home-page">
      <IonHeader className="ion-no-border">
        <IonToolbar className="home-toolbar">
          <div className="home-top-bar">
            {/* Left: Logo & Title */}
            <div className="home-logo-container">
               <img src="/assets/logo.png" alt="Logo" className="app-logo" />
               <h1 className="app-title">MyTogether</h1>
            </div>

            {/* Right: Actions */}
            <div className="home-actions">
              <IonButton className="action-btn" fill="clear">
                <MagnifyingGlass size={25}   />
              </IonButton>
              <IonButton className="action-btn" fill="clear" onClick={() => history.push('/tabs/notification')}>
                <Bell size={25} />
                <IonBadge color="danger" className="notif-badge">4</IonBadge>
              </IonButton>
              <div className="profile-btn">
                 <img src="https://i.pravatar.cc/150?img=12" alt="Profile" />
              </div>
            </div>
          </div>
        </IonToolbar>
      </IonHeader>
      
      <IonContent fullscreen>
        
        <IonRefresher slot="fixed" onIonRefresh={handleRefresh} mode='md'>
            <IonRefresherContent></IonRefresherContent>
        </IonRefresher>


        <div>
          {/* Quick Services Section */}
           <QuickServices />
        </div>

        {/* Promotion Cards Section */}
        <PromotionCards />

        {/* Today For You Section */}
        <TodayForYou />

        {/* Nearest Restaurant Section */}
        <NearestRestaurants />

        {/* Lost Item Near You Section */}
        <LostItems />

        {/* Famous Places Section */}
        <FamousPlaces />

        {/* <ExploreContainer /> */}
      </IonContent>
    </IonPage>
  );
};


export default Home;
