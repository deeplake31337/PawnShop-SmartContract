// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../PawnBase.sol";

/**
 * @title PawnFractional
 * @dev Tokenization & Asset Fractionalization Module: 
 * Allows a high-value physical asset (e.g. Rolex/Wine) to be split into multiple smaller shares, 
 * lowering the barrier for entry investments.
 */
abstract contract PawnFractional is PawnBase {

    /**
     * @dev Fractionalize an item (e.g. 100 shares split).
     * @param assetId Target physical asset/NFT ID
     * @param totalShares Number of divisions (e.g. 100 means each piece is 1/100th)
     * @param targetPrice Total selling price expected (determines pricePerShare).
     */
    function fractionalizeItem(uint256 assetId, uint256 totalShares, uint256 targetPrice) external onlyAdmin nonReentrant {
        require(totalShares > 0, "Shares must be > 0");
        require(targetPrice > 0, "Price must be > 0");
        require(targetPrice % totalShares == 0, "Target price must be divisible by total shares");

        PawnLoan storage loan = pawns[assetId];
        require(loan.isActive, "No active pawn loan for this asset");
        
        bool isOverdue = block.timestamp > loan.startTime + loan.duration;
        bool isVoluntaryCheapSell = targetPrice < appraisals[assetId].value;
        require(isOverdue || isVoluntaryCheapSell, "Can only fractionalize if overdue or voluntary cheap sell");

        // Take custody of the real-world-asset
        assetToken.transferFrom(msg.sender, address(this), assetId);

        uint256 pricePerShare = targetPrice / totalShares;

        // Mint new fraction tokens to the protocol itself to be sold
        fractionToken.mint(address(this), assetId, totalShares, "");

        fractionalAssets[assetId] = FractionalAsset({
            originalOwner: msg.sender,
            totalShares: totalShares,
            availableShares: totalShares, // none bought initially
            pricePerShare: pricePerShare,
            isActive: true
        });

        emit AssetFractionalized(assetId, msg.sender, totalShares, pricePerShare);
    }

    /**
     * @dev Users buy chunks of the asset instead of purchasing the entire expensive item
     * @param assetId The fractionalized NFT
     * @param sharesToBuy e.g., Buying 5 fractions simultaneously
     */
    function buyFractions(uint256 assetId, uint256 sharesToBuy) external nonReentrant {
        FractionalAsset storage frac = fractionalAssets[assetId];
        require(frac.isActive, "Not active or not fractionalized");
        require(sharesToBuy > 0, "Must buy at least 1 share");

        if (frac.availableShares < sharesToBuy) revert NotEnoughFractions();

        uint256 totalCost = sharesToBuy * frac.pricePerShare;

        // Deduct from the remaining token pieces pool
        frac.availableShares -= sharesToBuy;
        // Register token portions to the buyer's balance using ERC1155
        fractionToken.safeTransferFrom(address(this), msg.sender, assetId, sharesToBuy, "");

        // Platform fee deduction logic per transaction
        uint256 fee = (totalCost * platformFeePercentage) / MAX_BPS;
        uint256 netToOwner = totalCost - fee;

        // Collect funds (taking out our platform fees in transition routing to owner's wallet)
        paymentToken.transferFrom(msg.sender, address(this), fee); 
        paymentToken.transferFrom(msg.sender, frac.originalOwner, netToOwner);

        emit FractionsBought(assetId, msg.sender, sharesToBuy, totalCost);

        // Mark the fractionalization process closed if successfully 100% crowdfunded
        if (frac.availableShares == 0) {
            frac.isActive = false;
        }
    }

    /**
     * @dev Fetch how many pieces a single user holds of an asset
     */
    function getFractionsOf(uint256 assetId, address user) external view returns (uint256) {
        return fractionToken.balanceOf(user, assetId);
    }
}