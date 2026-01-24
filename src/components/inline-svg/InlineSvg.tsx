import React, { useEffect, useState } from 'react';

interface InlineSvgProps {
  src: string;
  className?: string;
  style?: React.CSSProperties;
}

const InlineSvg: React.FC<InlineSvgProps> = ({ src, className, style }) => {
  const [svgContent, setSvgContent] = useState<string | null>(null);

  useEffect(() => {
    const fetchSvg = async () => {
      try {
        const response = await fetch(src);
        const text = await response.text();
        // Basic check to see if it looks like an SVG
        if (text.trim().startsWith('<svg') || text.includes('<svg')) {
             setSvgContent(text);
        } else {
             console.error('File content is not a valid SVG:', src); 
             // Fallback or handle error if needed
        }
      } catch (error) {
        console.error('Error loading SVG:', error);
      }
    };

    if (src) {
      fetchSvg();
    }
  }, [src]);

  if (!svgContent) {
    // Optional: render placeholder or nothing while loading
    return null;
  }

  return (
    <div
      className={`inline-svg-container ${className || ''}`}
      style={{ display: 'flex', ...style }}
      dangerouslySetInnerHTML={{ __html: svgContent }}
    />
  );
};

export default InlineSvg;
