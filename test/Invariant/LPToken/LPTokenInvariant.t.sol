// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {LPToken} from "../../../src/LPToken.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

error OwnableUnauthorizedAccount(address account);

contract LPTokenHandler is Test {
    LPToken public lpToken;
    address[] public actors;
    mapping(address => uint256) public balances;
    uint256 public totalMinted;
    uint256 public totalBurned;
    address[] public tokenRecipients;
    mapping(address => bool) public hasReceivedTokens;

    constructor(LPToken _lpToken) {
        lpToken = _lpToken;
    }

    function addTokenRecipient(address recipient) public {
        if (!hasReceivedTokens[recipient]) {
            tokenRecipients.push(recipient);
            hasReceivedTokens[recipient] = true;
        }
    }

    function getTokenRecipientsLength() external view returns (uint256) {
        return tokenRecipients.length;
    }

    function mint(address to, uint256 amount) external {
        // Skip invalid addresses
        if (to == address(0)) return;
        
        amount = bound(amount, 0, 1e20);
        console2.log("Bound result", amount);
        
        // Try to mint tokens
        try lpToken.mint(to, amount) {
            // Update local tracking
            balances[to] += amount;
            totalMinted += amount;

            // Track unique token recipients
            if (!hasReceivedTokens[to]) {
                tokenRecipients.push(to);
                hasReceivedTokens[to] = true;
            }
        } catch {}
    }

    function burn(address from, uint256 amount) external {
        // Skip invalid addresses
        if (from == address(0)) return;
        
        // Ensure we don't try to burn more than the current balance
        uint256 currentBalance = lpToken.balanceOf(from);
        amount = bound(amount, 0, currentBalance);
        
        // Only attempt burn if there's a balance to burn
        if (currentBalance >= amount) {
            try lpToken.burn(from, amount) {
                // Update local tracking
                balances[from] -= amount;
                totalBurned += amount;
            } catch {}
        }
    }

    function transfer(address from, address to, uint256 amount) external {
        if (to == address(0)) return;
        amount = bound(amount, 0, balances[from]);
        if (balances[from] >= amount) {
            try lpToken.transfer(to, amount) {
                balances[from] -= amount;
                balances[to] += amount;

                // Track unique token recipients
                if (!hasReceivedTokens[to]) {
                    tokenRecipients.push(to);
                    hasReceivedTokens[to] = true;
                }
            } catch {}
        }
    }

    function approve(address owner, address spender, uint256 amount) external {
        if (spender == address(0)) return;
        amount = bound(amount, 0, type(uint256).max);
        vm.prank(owner);
        try lpToken.approve(spender, amount) {} catch {}
    }

    function transferFrom(address from, address to, address spender, uint256 amount) external {
        if (to == address(0) || from == address(0)) return;
        amount = bound(amount, 0, balances[from]);
        if (lpToken.allowance(from, spender) >= amount && balances[from] >= amount) {
            vm.prank(spender);
            try lpToken.transferFrom(from, to, amount) {
                balances[from] -= amount;
                balances[to] += amount;
                
                // Track unique token recipients
                if (!hasReceivedTokens[to]) {
                    tokenRecipients.push(to);
                    hasReceivedTokens[to] = true;
                }
            } catch {}
        }
    }

    // Additional helper functions
    function getBalance(address account) external view returns (uint256) {
        return balances[account];
    }

    function getTotalSupply() external view returns (uint256) {
        return totalMinted - totalBurned;
    }
}

contract LPTokenInvariantTest is StdInvariant, Test {
    LPToken public lpToken;
    LPTokenHandler public handler;
    address[] public actors;

    function setUp() public {
        // Create new LP token
        lpToken = new LPToken("LP Token", "LP");
        handler = new LPTokenHandler(lpToken);

        // Create test actors with deterministic addresses
        actors.push(address(this));
        for (uint256 i = 0; i < 4; i++) {
            address actor = makeAddr(string(abi.encodePacked("actor", i)));
            actors.push(actor);
            // Register actor as potential token recipient
            handler.addTokenRecipient(actor);
        }

        // Register handler and this contract as potential recipients
        handler.addTokenRecipient(address(handler));
        handler.addTokenRecipient(address(this));

        // Set up handler as target for invariant testing
        targetContract(address(handler));

        // Give mint/burn permissions to handler
        lpToken.transferOwnership(address(handler));

        // Approve handler for all actors
        for (uint256 i = 0; i < actors.length; i++) {
            vm.prank(actors[i]);
            lpToken.approve(address(handler), type(uint256).max);
        }
    }

    function invariant_totalSupply() public view {
        uint256 totalSupply = lpToken.totalSupply();
        uint256 actualBalance = 0;

        // Add balances of all tracked token recipients
        uint256 recipientsLength = handler.getTokenRecipientsLength();
        for (uint256 i = 0; i < recipientsLength; i++) {
            address recipient = handler.tokenRecipients(i);
            if (recipient != address(0)) {
                uint256 balance = lpToken.balanceOf(recipient);
                if (balance > 0) {
                    actualBalance += balance;
                }
            }
        }

        // Add balances from actors as they might have received tokens
        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            if (!handler.hasReceivedTokens(actor) && actor != address(0)) {
                uint256 balance = lpToken.balanceOf(actor);
                if (balance > 0) {
                    actualBalance += balance;
                }
            }
        }

        // Add handler's own balance
        uint256 handlerBalance = lpToken.balanceOf(address(handler));
        if (handlerBalance > 0) {
            actualBalance += handlerBalance;
        }

        // Assert the total supply matches sum of all balances
        assertEq(totalSupply, actualBalance, "Total supply must equal sum of all balances");
        
        // Verify that minted - burned matches total supply
        assertEq(handler.totalMinted() - handler.totalBurned(), totalSupply, "Minted - burned must equal total supply");
    }

    function invariant_nonzeroAddressOperations() public {
        assertEq(lpToken.balanceOf(address(0)), 0, "Zero address should have no balance");
        
        vm.startPrank(actors[0]);
        
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        lpToken.transfer(address(0), 1);
        
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        lpToken.approve(address(0), 1);
        
        vm.stopPrank();
    }

    function invariant_ownershipOperations() public {
        // Test that non-owner cannot mint
        vm.startPrank(actors[0]);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, actors[0]));
        lpToken.mint(actors[0], 1);

        // Test that non-owner cannot burn
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, actors[0]));
        lpToken.burn(actors[0], 1);
        vm.stopPrank();
    }
}