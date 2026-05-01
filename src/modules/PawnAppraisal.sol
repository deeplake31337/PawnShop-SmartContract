// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../PawnBase.sol";

abstract contract PawnAppraisal is PawnBase {
    /**
     * @dev Oracle Bot / Admin calls this function periodically to push estimated market value
     * @param assetId The ID of the real world physical NFT
     * @param estimatedValue The new estimated valuation in stablecoin decimals
     * @param ltvBps Recommended maximum Loan-to-Value (e.g., 6000 bps = 60%)
     * @param interestBps Custom interest rate applied for this specific asset class (e.g. 500 = 5%)
     */
    function updateAppraisal(uint256 assetId, uint256 estimatedValue, uint256 ltvBps, uint256 interestBps) external onlyOracle {
        appraisals[assetId] = Appraisal({
            value: estimatedValue,
            timestamp: block.timestamp,
            isValid: true, // Marking asset as fully authenticated and appraised
            recommendedLTV: ltvBps,
            interestRateBps: interestBps
        });

        emit AppraisalUpdated(assetId, estimatedValue, block.timestamp, ltvBps, interestBps);
    }
}