// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";

contract MockPriorityToken {
    address public immutable admin;
    address public minter;
    mapping(address => uint256) public balanceOf;

    event MinterSet(address indexed minter);
    event PriorityTokenMinted(address indexed to, uint256 amount);
    event PriorityTokenConsumed(address indexed from, uint256 amount);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert AVADataTypes.NotAdmin(msg.sender);
        _;
    }

    modifier onlyMinter() {
        if (msg.sender != minter) revert AVADataTypes.NotAuthorised(msg.sender, AVADataTypes.Action.ExecuteValueSettlement);
        _;
    }

    function setMinter(address minter_) external onlyAdmin {
        if (minter_ == address(0)) revert AVADataTypes.EmptyValue();
        minter = minter_;
        emit MinterSet(minter_);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        if (to == address(0) || amount == 0) revert AVADataTypes.EmptyValue();
        balanceOf[to] += amount;
        emit PriorityTokenMinted(to, amount);
    }

    function consumeFrom(address from, uint256 amount) external onlyMinter {
        if (from == address(0) || amount == 0) revert AVADataTypes.EmptyValue();
        if (balanceOf[from] < amount) revert AVADataTypes.InvalidState(amount);
        balanceOf[from] -= amount;
        emit PriorityTokenConsumed(from, amount);
    }
}
