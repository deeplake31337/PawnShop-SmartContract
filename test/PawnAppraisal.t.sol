// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseSetup.t.sol";

contract PawnAppraisalTest is BaseSetup {

    function test_UpdateAppraisal() public {
        uint256 estimatedValue = 10_000 * 10**18;
        uint256 ltvBps = 6000;                    
        uint256 interestBps = 500;                

        vm.prank(oracle);
        protocol.updateAppraisal(ASSET_ID, estimatedValue, ltvBps, interestBps);

        (uint256 val, , bool isValid, uint256 ltv, uint256 interest) = protocol.appraisals(ASSET_ID);
        
        assertEq(val, estimatedValue, "Estimated value not saved correctly");
        assertTrue(isValid, "Appraisal should be valid");
        assertEq(ltv, ltvBps, "LTV not saved correctly");
        assertEq(interest, interestBps, "Interest not saved correctly");
    }
}