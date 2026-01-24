import { IonLabel, IonRouterOutlet, IonTabBar, IonTabButton, IonTabs } from '@ionic/react';
import { House, ForkKnife, Newspaper, ListHeart } from '@phosphor-icons/react';
import { Redirect, Route, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import Food from '../food/Food';
import Home from '../home/Home';
import News from '../news/News';
import Notification from '../notification/Notification';
import Together from '../together/Together';
import Favourite from '../favourite/Favourite';
import './MainTabs.css';

const MainTabs: React.FC = () => {
  const location = useLocation();
  const currentPath = location.pathname;
  const { t } = useTranslation();

  return (
    <IonTabs>
      <IonRouterOutlet>
        <Route exact path="/tabs/home">
          <Home />
        </Route>
        <Route exact path="/tabs/food">
          <Food />
        </Route>
        <Route exact path="/tabs/together">
          <Together />
        </Route>
        <Route exact path="/tabs/news">
          <News />
        </Route>
        <Route exact path="/tabs/notification">
          <Notification />
        </Route>
        <Route exact path="/tabs/favourite">
          <Favourite />
        </Route>
        <Route exact path="/tabs">
          <Redirect to="/tabs/home" />
        </Route>
      </IonRouterOutlet>

      <IonTabBar slot="bottom">
        <IonTabButton tab="home" href="/tabs/home">
          <House size={24} weight={currentPath === '/tabs/home' ? 'fill' : 'regular'} />
          <IonLabel>{t('tab_home')}</IonLabel>
        </IonTabButton>

        <IonTabButton tab="food" href="/tabs/food">
          <ForkKnife size={24} weight={currentPath === '/tabs/food' ? 'fill' : 'regular'} />
          <IonLabel>{t('tab_food')}</IonLabel>
        </IonTabButton>

        
        <IonTabButton tab="favourite" href="/tabs/favourite">
          <ListHeart size={24} weight={currentPath === '/tabs/favourite' ? 'fill' : 'regular'} />
          <IonLabel>{t('tab_favourite')}</IonLabel>
        </IonTabButton>

        {/* <IonTabButton tab="together" href="/tabs/together">
          <IonIcon aria-hidden="true" icon={currentPath === '/tabs/together' ? people : peopleOutline} />
          <IonLabel>{t('tab_together')}</IonLabel>
        </IonTabButton> */}

        <IonTabButton tab="news" href="/tabs/news">
          <Newspaper size={24} weight={currentPath === '/tabs/news' ? 'fill' : 'regular'} />
          <IonLabel>{t('tab_news')}</IonLabel>
        </IonTabButton>

        {/* <IonTabButton tab="notification" href="/tabs/notification">
          <IonIcon aria-hidden="true" icon={currentPath === '/tabs/notification' ? notifications : notificationsOutline} />
          <IonLabel>{t('tab_notification')}</IonLabel>
        </IonTabButton> */}
      </IonTabBar>
    </IonTabs>
  );
};

export default MainTabs;

