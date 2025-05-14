🧱 Solidity Language Best Practices
✅ General Code Structure
Version locking: Use a specific compiler version (e.g., ^0.8.29) to prevent unexpected behavior due to version upgrades.

Use NatSpec comments (/// and /** */) for public and external functions to support automatic documentation and better auditability.

Group related functions and variables together for readability.

Avoid deep nesting; use early returns to improve clarity and reduce gas costs.

🧮 Gas Optimization
Use immutable and constant for variables that never change after deployment.

Short-circuit conditionals to prevent unnecessary computation.

Minimize storage writes: Writing to storage is expensive; use memory or calldata when possible.

Use custom errors over require("message") to save gas.

Pack storage manually by placing smaller types next to each other (e.g., uint128, uint128 in one slot).

Use unchecked blocks for arithmetic operations when overflow/underflow checks are not needed.

🔒 Security Best Practices
Check-Effects-Interactions pattern to prevent reentrancy.

Use OpenZeppelin's ReentrancyGuard when necessary.

Always validate input parameters (require()).

Use access control modifiers like onlyOwner or RBAC patterns.

Avoid external calls in constructors, especially with upgradeable contracts.

Don’t rely on tx.origin for authorization.

Fallback and receive functions should be implemented carefully with minimal logic.

🧪 Foundry Best Practices
Test Organization
Use t/ for tests and src/ for production code.

Follow the pattern: ContractName.t.sol for test files.

Test Style
Use setUp() hooks to initialize reusable state.

Use cheatcodes like vm.prank(), vm.warp(), vm.roll(), vm.expectRevert(), etc., to simulate complex test conditions.

Use forge snapshotting (vm.snapshot(), vm.revertTo()) for performance in large test suites.

Invariant and Fuzz Testing
Use forge invariant with Foundry's Test contract for invariant testing.

Annotate fuzz functions with function testFuzz(uint256 x) public – Foundry will automatically generate inputs.

🛠️ Optimization Tips
Solidity
Prefer calldata over memory in external functions.

Replace require(condition, "string") with revert CustomError().

Foundry
Enable optimizer in foundry.toml:

toml
Copy
Edit
optimizer = true
optimizer_runs = 200
Use --gas-report to find expensive calls.

🔁 Code Snippet Hygiene
Reusable Libraries
Write utility functions in libraries (library AddressUtils, SafeTransferLib).

Example:

solidity
Copy
Edit
library SafeTransferLib {
    function safeTransferETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH_TRANSFER_FAILED");
    }
}
Modifiers for Access Control
solidity
Copy
Edit
modifier onlyOwner() {
    require(msg.sender == owner, "NotOwner");
    _;
}
Custom Errors
solidity
Copy
Edit
error NotOwner();
🗂️ Sample foundry.toml for Best Config
toml
Copy
Edit
[profile.default]
src = 'src'
out = 'out'
libs = ['lib']
test = 'test'
cache = true
optimizer = true
optimizer_runs = 200
ffi = true
fs_permissions = [{ access = "read", path = "./"}]