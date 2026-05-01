// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./modules/PawnAppraisal.sol";
import "./modules/PawnLoans.sol";
import "./modules/PawnMarketplace.sol";
import "./modules/PawnLayaway.sol";
import "./modules/PawnFractional.sol";

/**
 * @title PawnProtocol
 * @dev Main Smart Contract weaving all logic facades: Appraisal, Loans, Marketplace, Layaway, and Fractionalization.
 */
contract PawnProtocol is PawnAppraisal, PawnLoans, PawnMarketplace, PawnLayaway, PawnFractional {
    
    /**
     * @dev Constructor
     * @param _paymentToken Base stablecoin used in the platform (e.g. USDC contract address)
     * @param _assetToken The original 721 format items contract (e.g. RWA NFTs representing physical properties)
     * @param _fractionToken The ERC1155 token contract used for fractional ownership representation
     */
    constructor(address _paymentToken, address _assetToken, address _fractionToken) {
        admin = msg.sender;
        oracle = msg.sender;
        paymentToken = IERC20(_paymentToken);
        assetToken = IERC721(_assetToken);
        fractionToken = IFractionToken(_fractionToken);
    }

    /**
     * @dev Update the platform fee percentage. Max 20% to protect users.
     * @param newFeeBps The new fee in basis points (e.g., 1000 = 10%)
     */
    function updatePlatformFee(uint256 newFeeBps) external onlyAdmin {
        require(newFeeBps <= 2000, "Fee too high"); // hard cap at 20% to prevent abuse
        platformFeePercentage = newFeeBps;
    }

    /**
     * @dev System authorities re-config mapping
     * @param _newAdmin Overarching administration rights
     * @param _newOracle Price feed estimation node address
     */
    function setRoles(address _newAdmin, address _newOracle) external onlyAdmin {
        admin = _newAdmin;
        oracle = _newOracle;
    }

    /**
     * @dev Allows admin to withdraw accumulated platform fees (USDC/Stablecoins) or mistakenly sent tokens.
     * @param tokenAddress The ERC20 token address to withdraw
     * @param target The address to receive the funds
     * @param amount The amount to withdraw
     */
    function withdrawFees(address tokenAddress, address target, uint256 amount) external onlyAdmin {
        IERC20(tokenAddress).transfer(target, amount);
    }

    /**
     * @dev Allows admin to rescue physical NFTs if stuck, or transfer liquidated goods out 
     * of the protocol if not selling through the on-chain marketplace.
     */
    function rescueAsset(address target, uint256 assetId) external onlyAdmin {
        // Prevent rescuing items that are currently active in loans, consignments, or layaways
        require(!pawns[assetId].isActive, "Asset locked in active pawn");
        require(!listings[assetId].isActive, "Asset locked in active listing");
        require(!layaways[assetId].isActive, "Asset locked in active layaway");
        require(!fractionalAssets[assetId].isActive, "Asset locked in active fractions");

        assetToken.transferFrom(address(this), target, assetId);
    }
}