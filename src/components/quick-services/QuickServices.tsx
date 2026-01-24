import { IonCol, IonGrid, IonRow } from '@ionic/react';
import React from 'react';
import { useTranslation } from 'react-i18next';
import InlineSvg from '../inline-svg/InlineSvg';
import './QuickServices.css';

interface Service {
  name: string;
  image?: string;
  icon?: any;
}

const QuickServices: React.FC = () => {
  const { t } = useTranslation();

  const services: Service[] = [
    { name: t('quick_services_food'), image: '/assets/services/food.svg' },
    { name: t('quick_services_lost_found'), image: '/assets/services/lost-found.svg' },
    { name: t('quick_services_exchange'), image: '/assets/services/exchange.svg' },
    { name: t('quick_services_visa'), image: '/assets/services/visa.svg' },
    { name: t('quick_services_places'), image: '/assets/services/places.svg' },
    { name: t('quick_services_store'), image: '/assets/services/store.svg' },
  ];
  return (
    <div className="quick-services-container">
      <h3 className="category-title">{t('quick_services_category')}</h3>
      <IonGrid className="quick-services-grid">
        <IonRow>
          {services.map((service, index) => (
            <IonCol size="4" key={index}>
              <div className="service-card">
                <div className="service-icon-wrapper">
                   {service.image ? (
                       <InlineSvg src={service.image} className="service-image" />
                   ) : (
                       <div style={{width: 64, height: 64, background: '#eee', borderRadius: '50%'}}></div>
                   )}
                </div>
                <div className="service-label">{service.name}</div>
              </div>
            </IonCol>
          ))}
        </IonRow>
      </IonGrid>
    </div>
  );
};

export default QuickServices;
