// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockERC1155
 * @dev Phiên bản giả lập siêu nhỏ gọn của ERC1155 để chạy test
 */
contract MockERC1155 {
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    function mint(address to, uint256 id, uint256 amount, bytes memory) external {
        balanceOf[to][id] += amount;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory) external {
        require(balanceOf[from][id] >= amount, "Insufficient balance");
        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;
    }
}
