// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/ReentrancyGuard.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IFractionToken.sol";

/**
 * @title PawnBase
 * @dev Contains all State variables, Structs, Modifiers, Events, and Errors of the system.
 */
abstract contract PawnBase is ReentrancyGuard {
    IERC20 public paymentToken;
    IERC721 public assetToken;
    IFractionToken public fractionToken;
    
    address public admin;
    address public oracle;

    uint256 public platformFeePercentage = 1000; // Default fee 10% (1000/10000 bps)
    uint256 public constant MAX_BPS = 10000;

    struct Appraisal {
        uint256 value;
        uint256 timestamp;
        bool isValid;
        uint256 recommendedLTV; // Loan-to-Value in basis points (e.g., 6000 bps = 60%)
        uint256 interestRateBps; // Admin-defined interest rate for this specific asset
    }

    struct PawnLoan {
        address borrower;
        uint256 loanAmount;
        uint256 interestRate;
        uint256 startTime;
        uint256 duration;
        bool isActive;
    }

    struct Listing {
        address seller;
        uint256 price;
        bool isConsignment; // Consignment: Protocol takes a fee. False: Direct protocol sale.
        bool isActive;
    }

    struct FractionListing {
        address seller;
        uint256 assetId;
        uint256 amount;
        uint256 pricePerShare;
        bool isActive;
    }

    struct Layaway {
        address buyer;
        uint256 totalPrice;
        uint256 amountPaid;
        uint256 lastPaymentTime;
        uint256 deadline;
        uint256 monthsDuration;     // 3, 6, 9, or 12 months
        uint256 installmentAmount;  // Fixed amount to pay per month
        bool isActive;
        uint256 penaltyAccumulated; // trackers late payment penalties
    }

    struct FractionalAsset {
        address originalOwner;
        uint256 totalShares;      // Total number of shares to split into (e.g., 100)
        uint256 availableShares;  // Remaining shares available for purchase
        uint256 pricePerShare;    // Target price per single share
        bool isActive;
    }

    // Mappings storing core protocol data
    mapping(uint256 => Appraisal) public appraisals;
    mapping(uint256 => PawnLoan) public pawns;
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Layaway) public layaways;
    mapping(uint256 => FractionalAsset) public fractionalAssets;
    
    uint256 public nextFractionListingId;
    mapping(uint256 => FractionListing) public fractionListings;

    // user => number of shares owned for a specific asset
    mapping(uint256 => mapping(address => uint256)) public fractionBalances; 

    // Custom Errors
    error NotAuthorized();
    error NotAppraisedOrInvalid();
    error StaleAppraisal();
    error LoanNotActive();
    error LoanNotMature();
    error NotForSale();
    error LayawayExpired();
    error NotEnoughFractions();
    error InvalidMonthsDuration();

    // Events
    event PenaltyApplied(uint256 indexed assetId, uint256 penaltyAmount);
    event AppraisalUpdated(uint256 indexed assetId, uint256 newValue, uint256 timestamp, uint256 adminLTV, uint256 interestRateBps);
    event LoanCreated(uint256 indexed assetId, address borrower, uint256 amount, uint256 duration);
    event LoanRepaid(uint256 indexed assetId, address borrower, uint256 totalRepaid);
    event FractionListed(uint256 indexed listingId, uint256 indexed assetId, address seller, uint256 amount, uint256 pricePerShare);
    event FractionListingCancelled(uint256 indexed listingId);
    event FractionBoughtFromListing(uint256 indexed listingId, uint256 indexed assetId, address buyer, uint256 amountBought, uint256 totalCost);
    event LoanLiquidated(uint256 indexed assetId);
    event ItemConsigned(uint256 indexed assetId, address seller, uint256 price);
    event ItemBought(uint256 indexed assetId, address buyer, uint256 price);
    event LayawayStarted(uint256 indexed assetId, address buyer, uint256 initialPayment);
    event LayawayInstallmentPaid(uint256 indexed assetId, uint256 amount);
    event LayawayCompleted(uint256 indexed assetId, address buyer);
    event LayawayForfeited(uint256 indexed assetId);
    event AssetFractionalized(uint256 indexed assetId, address owner, uint256 totalShares, uint256 pricePerShare);
    event FractionsBought(uint256 indexed assetId, address buyer, uint256 shares, uint256 totalCost);

    // Modifiers
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAuthorized();
        _;
    }

    modifier onlyOracle() {
        if (msg.sender != oracle && msg.sender != admin) revert NotAuthorized();
        _;
    }
}