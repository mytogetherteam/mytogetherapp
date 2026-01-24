import React from 'react';
import SearchBox from '../search-box/SearchBox';
import './TopToolbar.css';

const TopToolbar: React.FC = () => {

  return (
    <div className="toolbar-container">
      {/* Brand Section */}
      <div className="brand-section">
        <img src="/assets/logo.png" alt="My Together Logo" className="brand-logo" />
      </div>

      {/* Search Section */}
      <div className="search-section">
        <SearchBox />
      </div>

      {/* Avatar Section */}
      <div className="avatar-section">
        <div className="user-avatar">
            {/* Placeholder for cartoon avatar from reference */}
            <img src="https://i.pravatar.cc/150?img=12" alt="User" /> 
        </div>
      </div>
    </div>
  );
};


export default TopToolbar;

