// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../PawnBase.sol";

abstract contract PawnLoans is PawnBase {
    /**
     * @dev Creates a loan backed by the physical/RWA NFT. Ensures the appraisal is not outdated.
     * @param assetId The ID of the NFT collateral
     * @param durationDays Number of days the loan is active for
     * @param requestedAmount The stablecoin amount the borrower is requesting
     */
    function createPawnLoan(uint256 assetId, uint256 durationDays, uint256 requestedAmount) external nonReentrant {
        Appraisal memory app = appraisals[assetId];
        
        if (!app.isValid) revert NotAppraisedOrInvalid();
        
        // Prevent using outdated market price (e.g. older than 30 days)
        if (block.timestamp - app.timestamp > 30 days) revert StaleAppraisal();

        uint256 maxLoan = (app.value * app.recommendedLTV) / MAX_BPS;
        require(requestedAmount <= maxLoan, "Exceeds max LTV");

        // Use the custom interest rate defined by the Admin/Oracle during appraisal
        uint256 interestRateBps = app.interestRateBps; 

        // Lock the NFT into the smart contract
        assetToken.transferFrom(msg.sender, address(this), assetId);

        pawns[assetId] = PawnLoan({
            borrower: msg.sender,
            loanAmount: requestedAmount,
            interestRate: interestRateBps,
            startTime: block.timestamp,
            duration: durationDays * 1 days,
            isActive: true
        });

        // Deduct an upfront origination fee from the requested amount
        uint256 originationFee = (requestedAmount * platformFeePercentage) / MAX_BPS;
        uint256 netDisbursed = requestedAmount - originationFee;

        // Disburse the net funds to the borrower (Fee remains inside the protocol)
        paymentToken.transfer(msg.sender, netDisbursed);

        emit LoanCreated(assetId, msg.sender, requestedAmount, durationDays);
    }

    /**
     * @dev Borrower repays the full principal + interest to get their NFT back
     */
    function repayPawn(uint256 assetId) external nonReentrant {
        PawnLoan storage loan = pawns[assetId];
        if (!loan.isActive) revert LoanNotActive();
        if (msg.sender != loan.borrower) revert NotAuthorized();

        // Adding simple interest calculation depending on the tiers defined above
        uint256 interest = (loan.loanAmount * loan.interestRate) / MAX_BPS;
        uint256 totalRepay = loan.loanAmount + interest;

        loan.isActive = false;
        
        // Take stablecoins from the user and unlock the physical NFT back to them
        paymentToken.transferFrom(msg.sender, address(this), totalRepay);
        assetToken.transferFrom(address(this), msg.sender, assetId);

        emit LoanRepaid(assetId, msg.sender, totalRepay);
    }

    /**
     * @dev Liquidates the loan if overdue. The protocol keeps the NFT.
     */
    function liquidatePawn(uint256 assetId) external onlyAdmin {
        PawnLoan storage loan = pawns[assetId];
        if (!loan.isActive) revert LoanNotActive();
        
        // Verify that the loan is actually overdue
        if (block.timestamp <= loan.startTime + loan.duration) revert LoanNotMature();

        loan.isActive = false;
        // The NFT is officially retained by the protocol, which then can be put onto the marketplace
        emit LoanLiquidated(assetId);
    }
}