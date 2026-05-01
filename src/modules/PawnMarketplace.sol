// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../PawnBase.sol";

abstract contract PawnMarketplace is PawnBase {
    /**
     * @dev Users list their NFT for sale or consignment.
     * @param price Listing price in stablecoins
     * @param isConsigned Flag: True if selling user's item, False if protocol is selling liquidated goods
     */
    function createListing(uint256 assetId, uint256 price, bool isConsigned) external nonReentrant {
        if(isConsigned) {
            assetToken.transferFrom(msg.sender, address(this), assetId);
            listings[assetId] = Listing(msg.sender, price, true, true);
        } else {
            if (msg.sender != admin) revert NotAuthorized();
            listings[assetId] = Listing(address(this), price, false, true);
        }
        emit ItemConsigned(assetId, msg.sender, price);
    }

    /**
     * @dev Cancel listing and retrieve back the asset
     */
    function cancelListing(uint256 assetId) external nonReentrant {
        Listing storage list = listings[assetId];
        if (!list.isActive) revert NotForSale();
        if (msg.sender != list.seller && msg.sender != admin) revert NotAuthorized();

        list.isActive = false;
        
        // Return asset logic only makes sense if it's a user consignment
        if(list.isConsignment) {
            assetToken.transferFrom(address(this), list.seller, assetId);
        }
    }

    /**
     * @dev Buy the item with a one-time full payment
     */
    function buyItem(uint256 assetId) external nonReentrant {
        Listing storage list = listings[assetId];
        if (!list.isActive) revert NotForSale();

        list.isActive = false;

        // Route payment distributions based on whether it is Consigned or Protocol's
        if (list.isConsignment) {
            // Apply platform fee commission
            uint256 fee = (list.price * platformFeePercentage) / MAX_BPS;
            uint256 netToSeller = list.price - fee;
            
            paymentToken.transferFrom(msg.sender, address(this), fee);
            paymentToken.transferFrom(msg.sender, list.seller, netToSeller);
        } else {
            paymentToken.transferFrom(msg.sender, address(this), list.price);
        }

        // Deliver the NFT RWA
        assetToken.transferFrom(address(this), msg.sender, assetId);
        emit ItemBought(assetId, msg.sender, list.price);
    }
}