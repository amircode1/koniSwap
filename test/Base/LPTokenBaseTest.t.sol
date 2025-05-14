// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {LPToken} from "../../src/LPToken.sol";

abstract contract LPTokenBaseTest is Test {
    // ============ Storage ============
    LPToken public lpToken;
    address public owner;
    address public user;
    address public spender;

    // ============ Events ============
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Setup ============
    function setUp() public virtual {
        owner = address(this);
        user = makeAddr("user");
        spender = makeAddr("spender");
        lpToken = new LPToken("LP Token", "LP");

        // Fund test addresses
        vm.deal(user, 100 ether);
        vm.deal(spender, 100 ether);
    }

    // ============ Helpers ============
    function _mintTokens(address to, uint256 amount) internal {
        lpToken.mint(to, amount);
    }

    function _approveTokens(address from, address to, uint256 amount) internal {
        vm.prank(from);
        lpToken.approve(to, amount);
    }
}