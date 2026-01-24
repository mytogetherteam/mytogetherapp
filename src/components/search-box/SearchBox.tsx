import { MagnifyingGlass } from '@phosphor-icons/react';
import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import './SearchBox.css';

interface SearchBoxProps {
    className?: string;
}

const SearchBox: React.FC<SearchBoxProps> = ({ className }) => {
  const { t, i18n } = useTranslation();
  const [placeholderIndex, setPlaceholderIndex] = useState(0);
  const [fadeClass, setFadeClass] = useState('fade-in');

  const isMyanmar = i18n.language === 'mm';

  // Dynamic placeholders keyed by translation ID
  const placeholderKeys = [
    "search_placeholder_1",
    "search_placeholder_2",
    "search_placeholder_3",
    "search_placeholder_4",
    "search_placeholder_5"
  ];

  useEffect(() => {
    const interval = setInterval(() => {
      setFadeClass('fade-out');
      
      setTimeout(() => {
        setPlaceholderIndex((prev) => (prev + 1) % placeholderKeys.length);
        setFadeClass('fade-in');
      }, 500); // Matches CSS transition duration

    }, 3000); // Change every 3 seconds

    return () => clearInterval(interval);
  }, []);

  return (
    <div className={`search-box-container ${className || ''}`}>
        <MagnifyingGlass size={20} className="search-box-icon" />
        <span className={`search-box-placeholder ${fadeClass} ${isMyanmar ? 'lang-mm' : ''}`}>
            {t(placeholderKeys[placeholderIndex])}
        </span>
    </div>
  );
};

export default SearchBox;
