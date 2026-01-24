import React from 'react';
import { useTranslation } from 'react-i18next';
import './LanguageSwitcher.css';

const LanguageSwitcher: React.FC = () => {
    const { i18n } = useTranslation();

    const changeLanguage = (lng: string) => {
        i18n.changeLanguage(lng);
    };

    return (
        <div className="language-switcher">
            <button 
                className={`lang-btn ${i18n.language === 'en' ? 'active' : ''}`}
                onClick={() => changeLanguage('en')}
            >
                EN
            </button>
            <div className="lang-divider"></div>
            <button 
                className={`lang-btn ${i18n.language === 'mm' ? 'active' : ''}`}
                onClick={() => changeLanguage('mm')}
            >
                MM
            </button>
        </div>
    );
};

export default LanguageSwitcher;
