import { create } from "zustand";
import { devtools, persist } from "zustand/middleware";
import { NFT } from "~~/types/NFT";

/**
 * Store shape definition
 */
interface NFTSlice {
  nfts: NFT[];
  selectedNft: NFT | null;
  isLoading: boolean;
  error: string | null;

  setNFTs: (nfts: NFT[]) => void;
  setSelectedNft: (nft: NFT | null) => void;
  setError: (error: string | null) => void;
  setLoading: (isLoading: boolean) => void;
}

/**
 * Create Zustand store with NFT slice
 */
const useNFTStore = create<NFTSlice>()(
  devtools(
    persist(
      set => ({
        // State
        nfts: [],
        selectedNft: null,
        isLoading: false,
        error: null,

        // Set selected NFT
        setNFTs: nfts => set({ nfts }),
        setSelectedNft: nft => set({ selectedNft: nft }),
        setError: error => set({ error }),
        setLoading: isLoading => set({ isLoading }),
      }),
      {
        name: "nft-store", // Key for persisting state
      },
    ),
  ),
);

export default useNFTStore;
