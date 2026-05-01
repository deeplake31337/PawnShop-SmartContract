// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC1155.sol";

interface IFractionToken is IERC1155 {
    /**
     * @dev Mints amount of token id to address to
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external;
}