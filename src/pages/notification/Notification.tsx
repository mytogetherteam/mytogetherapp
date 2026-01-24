import { IonContent, IonHeader, IonPage, IonTitle, IonToolbar } from '@ionic/react';
import React from 'react';
import LanguageSwitcher from '../../components/language-switcher/LanguageSwitcher';
import './Notification.css';

const Notification: React.FC = () => {
  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonTitle>Notification</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent fullscreen>
        <IonHeader collapse="condense">
          <IonToolbar>
            <IonTitle size="large">Notification</IonTitle>
          </IonToolbar>
        </IonHeader>
        <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', height: '100%' }}>
          <h2>Notification Page</h2>
          <div style={{ marginTop: '20px' }}>
            <LanguageSwitcher />
          </div>
        </div>
      </IonContent>
    </IonPage>
  );
};

export default Notification;
