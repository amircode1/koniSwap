// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {LPToken} from "../../../src/LPToken.sol";
import {LPTokenBaseTest} from "../../Base/LPTokenBaseTest.t.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

error OwnableUnauthorizedAccount(address account);

contract LPTokenFuzzTest is LPTokenBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_ApprovalScenarios(
        uint256 initialBalance,
        uint256[3] memory allowances,
        uint256[3] memory transferAmounts
    ) public {
        address[3] memory spenders = [
            makeAddr("spender1"),
            makeAddr("spender2"),
            makeAddr("spender3")
        ];

        // Mint initial tokens to user, bounded to avoid overflow
        initialBalance = bound(initialBalance, 1e18, 1e27);
        lpToken.mint(user, initialBalance);

        // Set up initial allowances
        vm.startPrank(user);
        for (uint256 i = 0; i < 3; i++) {
            allowances[i] = bound(allowances[i], 0, initialBalance);
            lpToken.approve(spenders[i], allowances[i]);
        }
        vm.stopPrank();

        // Test transfers from each spender
        for (uint256 i = 0; i < 3; i++) {
            transferAmounts[i] = bound(transferAmounts[i], 0, initialBalance);

            vm.startPrank(spenders[i]);
            
            if (transferAmounts[i] <= allowances[i]) {
                if (transferAmounts[i] <= lpToken.balanceOf(user)) {
                    // Should succeed
                    lpToken.transferFrom(user, spenders[i], transferAmounts[i]);
                    assertEq(lpToken.balanceOf(spenders[i]), transferAmounts[i]);
                    assertEq(lpToken.allowance(user, spenders[i]), allowances[i] - transferAmounts[i]);
                } else {
                    // Should fail with insufficient balance
                    vm.expectRevert(abi.encodeWithSelector(
                        IERC20Errors.ERC20InsufficientBalance.selector,
                        user,
                        lpToken.balanceOf(user),
                        transferAmounts[i]
                    ));
                    lpToken.transferFrom(user, spenders[i], transferAmounts[i]);
                }
            } else {
                // Should fail with insufficient allowance
                vm.expectRevert(abi.encodeWithSelector(
                    IERC20Errors.ERC20InsufficientAllowance.selector,
                    spenders[i],
                    allowances[i],
                    transferAmounts[i]
                ));
                lpToken.transferFrom(user, spenders[i], transferAmounts[i]);
            }
            
            vm.stopPrank();
        }
    }

    function testFuzz_MultipleTransfers(
        uint256[5] memory amounts,
        address[5] memory recipients
    ) public {
        uint256 totalAmount = 0;
        
        // Generate bounded amounts and valid recipients
        for (uint256 i = 0; i < 5; i++) {
            amounts[i] = bound(amounts[i], 1e18, 10e18);
            recipients[i] = address(uint160(uint256(keccak256(abi.encodePacked(i, block.timestamp)))));
            require(recipients[i] != address(0), "Invalid recipient");
            totalAmount += amounts[i];
        }
        
        // Mint initial balance to user
        lpToken.mint(user, totalAmount);
        
        vm.startPrank(user);
        
        // Perform transfers
        for (uint256 i = 0; i < 5; i++) {
            lpToken.transfer(recipients[i], amounts[i]);
            assertEq(lpToken.balanceOf(recipients[i]), amounts[i]);
        }
        
        vm.stopPrank();
        
        assertEq(lpToken.balanceOf(user), 0);
    }

    function testFuzz_TransferApprovalLimits(
        uint256 balance,
        uint256 allowance,
        uint256 transferAmount
    ) public {
        // Bound inputs to reasonable values
        balance = bound(balance, 1e18, 100e18);
        allowance = bound(allowance, 0, balance);
        transferAmount = bound(transferAmount, allowance + 1, balance + 1);
        
        // Setup
        lpToken.mint(user, balance);
        
        vm.prank(user);
        lpToken.approve(spender, allowance);
        
        // Attempt transfer exceeding allowance
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientAllowance.selector,
            spender,
            allowance,
            transferAmount
        ));
        lpToken.transferFrom(user, spender, transferAmount);
    }

    function testFuzz_ChainedTransfers(
        uint256 amount,
        address[5] memory recipients
    ) public {
        amount = bound(amount, 1e18, 10e18);
        
        // Filter out zero addresses and duplicates
        for (uint256 i = 0; i < 5; i++) {
            recipients[i] = address(uint160(uint256(keccak256(abi.encodePacked(i, block.timestamp)))));
            require(recipients[i] != address(0), "Invalid recipient");
        }
        
        // Initial setup
        lpToken.mint(recipients[0], amount);
        
        // Chain of transfers
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(recipients[i]);
            lpToken.transfer(recipients[i + 1], amount);
            assertEq(lpToken.balanceOf(recipients[i]), 0);
            assertEq(lpToken.balanceOf(recipients[i + 1]), amount);
        }
    }

    function testFuzz_MintBurnCombinations(
        uint256[5] memory mintAmounts,
        uint256[5] memory burnAmounts
    ) public {
        uint256 totalMinted = 0;
        
        // Perform mints
        for (uint256 i = 0; i < 5; i++) {
            mintAmounts[i] = bound(mintAmounts[i], 1e18, 10e18);
            lpToken.mint(user, mintAmounts[i]);
            totalMinted += mintAmounts[i];
        }
        
        uint256 totalBurned = 0;
        // Perform burns within available balance
        for (uint256 i = 0; i < 5; i++) {
            uint256 remainingBalance = totalMinted - totalBurned;
            if (remainingBalance > 0) {
                burnAmounts[i] = bound(burnAmounts[i], 0, remainingBalance);
                lpToken.burn(user, burnAmounts[i]);
                totalBurned += burnAmounts[i];
            }
        }
        
        assertEq(lpToken.balanceOf(user), totalMinted - totalBurned);
    }
}