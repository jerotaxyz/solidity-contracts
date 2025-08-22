// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Import contracts to be tested and their interfaces/libraries
import {Vault} from "../../src/vault/Vault.sol";
import {IVault} from "../../src/vault/interfaces/IVault.sol";
import {IFactory} from "../../src/vault/interfaces/IFactory.sol";
import {Errors} from "../../src/vault/libraries/Errors.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// --- Mock Contracts ---

/**
 * @title MockERC20
 * @dev A simple ERC20 token for testing purposes with a public mint function.
 */
contract MockERC20 is IERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/**
 * @title MockFactory
 * @dev A mock factory to simulate interactions needed by the Vault contract.
 */
contract MockFactory is IFactory {
    address public allowedToken;
    uint8 public feePercentage;
    address public feeWallet;

    constructor(address _allowedToken, uint8 _feePercentage, address _feeWallet) {
        allowedToken = _allowedToken;
        feePercentage = _feePercentage;
        feeWallet = _feeWallet;
    }

    function isTokenAllowed(address tokenAddress) external view returns (bool) {
        return tokenAddress == allowedToken;
    }

    function getCampaignFeePercentage() external view returns (uint8) {
        return feePercentage;
    }

    function getFeeWallet() external view returns (address) {
        return feeWallet;
    }

    // --- Unimplemented Functions ---
    function createCampaign() external pure returns (address) {}
    function addAllowedToken(address) external pure {}
    function removeAllowedToken(address) external pure {}
    function getAllowedTokens() external pure returns (address[] memory) {}
    function setRewardDistributor(address) external pure {}
    function getRewardDistributor() external pure returns (address) {}
    function getVaultAddress(uint256) external pure returns (address) {}
    function getVaultCount() external pure returns (uint256) {}
    function getAllVaults() external pure returns (address[] memory) {}
    function getFundedVaults() external pure returns (address[] memory) {}
    function setVaultImplementation(address) external pure {}
    function setCampaignFeePercentage(uint8) external pure {}
    function setFeeWallet(address) external pure {}
}

// --- Test Contract ---

contract VaultTest is Test {
    // Contracts
    Vault internal vaultImplementation;
    IVault internal vaultProxy;
    MockFactory internal mockFactory;
    MockERC20 internal rewardToken;
    MockERC20 internal anotherToken; // For rescue test

    // Actors
    address internal creator = makeAddr("creator");
    address internal distributor = makeAddr("distributor");
    address internal feeWallet = makeAddr("feeWallet");
    address internal recipient1 = makeAddr("recipient1");
    address internal recipient2 = makeAddr("recipient2");
    address internal randomUser = makeAddr("randomUser");

    // Constants
    uint256 internal constant FUND_AMOUNT = 1000 ether;
    uint8 internal constant FEE_PERCENTAGE = 5; // 5%

    function setUp() public {
        // Deploy reward token
        rewardToken = new MockERC20();

        // Deploy the mock factory
        mockFactory = new MockFactory(address(rewardToken), FEE_PERCENTAGE, feeWallet);

        // Deploy the vault implementation contract
        vaultImplementation = new Vault();

        // Deploy the vault proxy using Clones
        address proxyAddress = Clones.clone(address(vaultImplementation));
        vaultProxy = IVault(proxyAddress);

        // Initialize the vault proxy
        vaultProxy.initialize(address(mockFactory), distributor, creator);

        // Prepare the creator with funds and approve the vault
        rewardToken.mint(creator, FUND_AMOUNT);
        vm.startPrank(creator);
        rewardToken.approve(address(vaultProxy), FUND_AMOUNT);
        vm.stopPrank();
    }

    // --- Test `initialize` ---

    function testInitializeSuccess() public view {
        assertEq(vaultProxy.getCreator(), creator);
        assertEq(vaultProxy.getDistributor(), distributor);
        assertTrue(!vaultProxy.isFunded());
        assertTrue(!vaultProxy.isFinalized());
    }

    function testRevertIfInitializeWithZeroAddressFactory() public {
        address proxyAddress = Clones.clone(address(vaultImplementation));
        IVault newVault = IVault(proxyAddress);
        vm.expectRevert(Errors.ZeroAddress.selector);
        newVault.initialize(address(0), distributor, creator);
    }

    function testRevertIfInitializeIsCalledTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vaultProxy.initialize(address(mockFactory), distributor, creator);
    }

    // --- Test `fund` ---

    function testFundSuccess() public {
        vm.startPrank(creator);

        // Expect the VaultFunded event.
        // event VaultFunded(address indexed creator, address indexed tokenAddress, uint256 amount);
        // We check both indexed topics (creator, tokenAddress) and the data payload (amount).
        vm.expectEmit(true, true, false, true);
        emit IVault.VaultFunded(creator, address(rewardToken), FUND_AMOUNT);
        vaultProxy.fund(address(rewardToken), FUND_AMOUNT);

        vm.stopPrank();

        uint256 expectedFee = (FUND_AMOUNT * FEE_PERCENTAGE) / 100;
        uint256 expectedVaultAmount = FUND_AMOUNT - expectedFee;

        assertTrue(vaultProxy.isFunded());
        assertEq(vaultProxy.getTokenAddress(), address(rewardToken));
        assertEq(vaultProxy.getFundAmount(), expectedVaultAmount);
        assertEq(rewardToken.balanceOf(address(vaultProxy)), expectedVaultAmount);
        assertEq(rewardToken.balanceOf(feeWallet), expectedFee);
        assertEq(rewardToken.balanceOf(creator), 0);
    }

    function testRevertIfFundCalledByNonCreator() public {
        vm.startPrank(randomUser);
        vm.expectRevert(Errors.OnlyCreatorCanFund.selector);
        vaultProxy.fund(address(rewardToken), FUND_AMOUNT);
        vm.stopPrank();
    }

    function testRevertIfFundWhenAlreadyFunded() public {
        vm.prank(creator);
        vaultProxy.fund(address(rewardToken), FUND_AMOUNT);

        vm.prank(creator);
        vm.expectRevert(Errors.AlreadyFunded.selector);
        vaultProxy.fund(address(rewardToken), FUND_AMOUNT);
    }

    function testRevertIfFundWithZeroAmount() public {
        vm.prank(creator);
        vm.expectRevert(Errors.InvalidAmount.selector);
        vaultProxy.fund(address(rewardToken), 0);
    }

    function testRevertIfFundWithUnallowedToken() public {
        anotherToken = new MockERC20();
        vm.prank(creator);
        vm.expectRevert(Errors.TokenNotAllowed.selector);
        vaultProxy.fund(address(anotherToken), FUND_AMOUNT);
    }

    // --- Test `distributeRewards` ---

    function testDistributeRewardsSuccess() public {
        // Fund the vault first
        vm.prank(creator);
        vaultProxy.fund(address(rewardToken), FUND_AMOUNT);

        // Prepare rewards data
        IVault.Reward[] memory rewards = new IVault.Reward[](2);
        rewards[0] = IVault.Reward({recipient: recipient1, amount: 100 ether});
        rewards[1] = IVault.Reward({recipient: recipient2, amount: 300 ether});
        uint256 totalDistribution = 400 ether;

        // Distribute as the distributor
        vm.startPrank(distributor);
        // Expect the RewardsDistributed event.
        // event RewardsDistributed(address indexed distributor, Reward[] rewards, uint256 totalAmount);
        // We only check the indexed topic (distributor) because the `rewards` array is a dynamic
        // type that makes checking the full data payload unreliable. State changes are asserted below.
        vm.expectEmit(true, false, false, false);
        emit IVault.RewardsDistributed(distributor, rewards, totalDistribution);
        vaultProxy.distributeRewards(rewards);
        vm.stopPrank();

        // 4. Assert outcomes
        assertTrue(vaultProxy.isFinalized());
        assertEq(rewardToken.balanceOf(recipient1), 100 ether);
        assertEq(rewardToken.balanceOf(recipient2), 300 ether);
        assertEq(vaultProxy.getBalance(), vaultProxy.getFundAmount() - totalDistribution);
    }

    function testRevertIfDistributeRewardsCalledByNonDistributor() public {
        vm.prank(randomUser);
        IVault.Reward[] memory rewards = new IVault.Reward[](1);
        rewards[0] = IVault.Reward({recipient: recipient1, amount: 100 ether});
        vm.expectRevert(Errors.UnauthorizedDistributor.selector);
        vaultProxy.distributeRewards(rewards);
    }

    function testRevertIfDistributeRewardsWhenNotFunded() public {
        // Vault is not funded in this test
        vm.prank(distributor);
        IVault.Reward[] memory rewards = new IVault.Reward[](1);
        rewards[0] = IVault.Reward({recipient: recipient1, amount: 100 ether});
        vm.expectRevert(Errors.InsufficientFunds.selector);
        vaultProxy.distributeRewards(rewards);
    }

    function testRevertIfDistributeRewardsWithInsufficientFunds() public {
        vm.prank(creator);
        vaultProxy.fund(address(rewardToken), FUND_AMOUNT); // Vault has 950 ether

        vm.prank(distributor);
        IVault.Reward[] memory rewards = new IVault.Reward[](1);
        rewards[0] = IVault.Reward({recipient: recipient1, amount: 1000 ether}); // Trying to send more than available
        vm.expectRevert(Errors.InsufficientFunds.selector);
        vaultProxy.distributeRewards(rewards);
    }

    function testRevertIfDistributeRewardsWhenAlreadyFinalized() public {
        vm.prank(creator);
        vaultProxy.fund(address(rewardToken), FUND_AMOUNT);

        IVault.Reward[] memory rewards = new IVault.Reward[](1);
        rewards[0] = IVault.Reward({recipient: recipient1, amount: 1 ether});

        vm.prank(distributor);
        vaultProxy.distributeRewards(rewards); // First distribution, finalizes the vault

        vm.prank(distributor);
        vm.expectRevert(Errors.CampaignFinalized.selector);
        vaultProxy.distributeRewards(rewards); // Second attempt
    }

    // --- Test `rescueToken` ---

    function testRescueTokenSuccess() public {
        // Send some other token to the vault by mistake
        anotherToken = new MockERC20();
        anotherToken.mint(address(vaultProxy), 500 ether);
        assertEq(anotherToken.balanceOf(address(vaultProxy)), 500 ether);

        // Rescue as the distributor
        vm.startPrank(distributor);
        // Expect the TokenRescued event.
        // event TokenRescued(address indexed distributor, address indexed recipient, address indexed tokenAddress, uint256 amount);
        // We check all 3 indexed topics and the data payload (amount).
        vm.expectEmit(true, true, true, true);
        emit IVault.TokenRescued(distributor, recipient1, address(anotherToken), 500 ether);
        vaultProxy.rescueToken(recipient1, address(anotherToken), 500 ether);
        vm.stopPrank();

        // Assert outcomes
        assertEq(anotherToken.balanceOf(address(vaultProxy)), 0);
        assertEq(anotherToken.balanceOf(recipient1), 500 ether);
    }

    function testRevertIfRescueTokenCalledByNonDistributor() public {
        anotherToken = new MockERC20();
        anotherToken.mint(address(vaultProxy), 500 ether);

        vm.prank(randomUser);
        vm.expectRevert(Errors.UnauthorizedDistributor.selector);
        vaultProxy.rescueToken(recipient1, address(anotherToken), 500 ether);
    }
}
