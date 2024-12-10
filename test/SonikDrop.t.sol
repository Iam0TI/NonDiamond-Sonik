// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {SonikDrop} from "../contracts/facets/erc20facets/SonikDrop.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {GetProof} from "./helpers/GetProof.sol";

contract TestERC20 is ERC20 {
    constructor() ERC20("Test token", "TT") {
        _mint(msg.sender, 100000e18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract SonikDropTest is GetProof {
    SonikDrop sonikDrop;
    TestERC20 testToken;
    address user1;
    uint256 keyUser1;
    address user2;
    uint256 keyUser2;
    address badUser;
    uint256 keybadUser;
    address owner;
    bytes32 merkleRoot = 0x95d6e8d85e932a1fb33f70a0b15e42ab823ffc4e34a7e53c602529c2478cd823;
    bytes32 hash = keccak256("claimed sonik droppppppppppp");

    function setUp() public {
        owner = address(this);
        testToken = new TestERC20();
        sonikDrop = new SonikDrop(owner, address(testToken), merkleRoot, address(0), 0, 10);
        testToken.transfer(address(sonikDrop), 25 ether);
        (user1, keyUser1) = makeAddrAndKey("user1");
        (user2, keyUser2) = makeAddrAndKey("user2");
        (badUser, keybadUser) = makeAddrAndKey("badUser");
    }

    function test_ClaimAirdrop() public {
        bytes32[] memory proof = getProof(user1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(keyUser1, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        emit log_address(msg.sender);
        vm.prank(user1);
        sonikDrop.claimAirdrop(10e18, proof, hash, signature);
        assertEq(testToken.balanceOf(user1), 10e18);
    }

    function test_ClaimAirdrop_DuplicateClaim() external {
        bytes32[] memory proof = getProof(user1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(keyUser1, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // First claim
        vm.prank(user1);
        sonikDrop.claimAirdrop(10e18, proof, hash, signature);

        // Attempt to claim again
        vm.expectRevert(abi.encodeWithSignature("InvalidClaim()"));
        vm.prank(user1);
        sonikDrop.claimAirdrop(10e18, proof, hash, signature);
    }

    function test_ClaimAirdrop_InvalidProof() external {
        // Generating an invalid proof for user2
        bytes32[] memory invalidProof = new bytes32[](0);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(keyUser2, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSignature("InvalidClaim()"));
        vm.prank(user2);
        sonikDrop.claimAirdrop(10e18, invalidProof, hash, signature);
    }

    function test_ClaimAirdrop_InsufficientFunds() external {
        test_ClaimAirdrop();

        // Attempt to claim more than the available balance
        vm.expectRevert(abi.encodeWithSignature("InsufficientContractBalance()"));
        vm.prank(user2);
        bytes32[] memory proof = getProof(user2);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(keyUser2, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        sonikDrop.claimAirdrop(20e18, proof, hash, signature);
    }

    function test_ClaimAirdrop_TimeLock() external {
        // Set a claim time to test time-lock functionality
        vm.prank(owner);
        sonikDrop.updateClaimTime(10);

        bytes32[] memory proof = getProof(user2);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(keyUser2, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Fast forward time to simulate claim after time-lock
        vm.warp(block.timestamp + 1232);
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSignature("AirdropClaimEnded()"));
        sonikDrop.claimAirdrop(20e18, proof, hash, signature);
    }
}
