// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LPTokenBaseTest} from "../../Base/LPTokenBaseTest.t.sol";

error OwnableUnauthorizedAccount(address account);
error OwnableInvalidOwner(address owner);

contract OwnershipTest is LPTokenBaseTest {
    function test_OwnershipTransfer() public {
        address newOwner = address(0x123);
        
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user));
        lpToken.transferOwnership(newOwner);
        
        // Owner can transfer ownership
        lpToken.transferOwnership(newOwner);
        assertEq(lpToken.owner(), newOwner);
    }

    function test_RenounceOwnership() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user));
        lpToken.renounceOwnership();
        
        // Owner can renounce ownership
        lpToken.renounceOwnership();
        assertEq(lpToken.owner(), address(0));
    }
}