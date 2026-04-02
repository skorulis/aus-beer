export type VesselType = "bottle" | "can";

export interface PriceEntry {
  price: number;
  quantity: number;
  memberOffer: boolean;
}

export interface CanonicalProduct {
  brewery: string;
  name: string;
  vesselType: VesselType | null;
  sizeMl: number | null;
  prices: PriceEntry[];
}

export interface ScrapeOutput {
  source: string;
  scrapedAt: string;
  products: CanonicalProduct[];
}
