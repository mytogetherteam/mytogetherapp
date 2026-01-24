export interface MenuSize {
    name: string;
    price: string;
}

export interface MenuAddon {
    name: string;
    price: string;
}

export interface RelatedItem {
    id: number;
    name: string;
    price: string;
    image: string;
}

export interface MenuItem {
    id: number;
    name: string;
    price: string;
    category: string;
    image: string;
    isPopular: boolean;
    description?: string;
    sizes?: MenuSize[];
    addons?: MenuAddon[];
    spiceLevels?: string[];
    relatedItems?: RelatedItem[];
}
