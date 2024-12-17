// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../test/helpers/DiamondUtils.sol";

import {AirdropFactoryFacet} from "../contracts/facets/erc20facets/FactoryFacet.sol";
import {PoapFactoryFacet} from "../contracts/facets/erc721facets/PoapFactoryFacet.sol";

import "forge-std/Script.sol";

contract DiamondDeployer is Script, DiamondUtils, IDiamondCut {
    // Facets
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupeFacet;
    OwnershipFacet ownershipFacet;
    AirdropFactoryFacet airdropFactoryFacet;
    PoapFactoryFacet poapFactoryFacet;

    // Diamond
    Diamond diamond;

    // Unique salts for deterministic deployment
    bytes32 constant SALT_DIAMOND_CUT = keccak256("SonikDrop_DiamondCutFacet");
    bytes32 constant SALT_DIAMOND = keccak256("SonikDrop_Diamond");
    bytes32 constant SALT_LOUPE = keccak256("SonikDrop_DiamondLoupeFacet");
    bytes32 constant SALT_OWNERSHIP = keccak256("SonikDrop_OwnershipFacet");
    bytes32 constant SALT_AIRDROP = keccak256("SonikDrop_AirdropFactoryFacet");
    bytes32 constant SALT_POAP = keccak256("SonikDrop_PoapFactoryFacet");

    function run() external {
        vm.startBroadcast();

        // Deploy facets
        deployFacets();

        // Deploy diamond
        deployDiamond();

        // Upgrade diamond with facets
        upgradeDiamond();

        // Verify deployment
        verifyDiamond();

        vm.stopBroadcast();
    }

    function deployFacets() internal {
        dCutFacet = new DiamondCutFacet{salt: SALT_DIAMOND_CUT}();
        console.log("DiamondCutFacet deployed at:", address(dCutFacet));

        dLoupeFacet = new DiamondLoupeFacet{salt: SALT_LOUPE}();
        console.log("DiamondLoupeFacet deployed at:", address(dLoupeFacet));

        ownershipFacet = new OwnershipFacet{salt: SALT_OWNERSHIP}();
        console.log("OwnershipFacet deployed at:", address(ownershipFacet));

        airdropFactoryFacet = new AirdropFactoryFacet{salt: SALT_AIRDROP}();
        console.log("AirdropFactoryFacet deployed at:", address(airdropFactoryFacet));

        poapFactoryFacet = new PoapFactoryFacet{salt: SALT_POAP}();
        console.log("PoapFactoryFacet deployed at:", address(poapFactoryFacet));
    }

    function deployDiamond() internal {
        diamond = new Diamond{salt: SALT_DIAMOND}(msg.sender, address(dCutFacet));
        console.log("Diamond deployed at:", address(diamond));
    }

    function upgradeDiamond() internal {
        // Create the FacetCut array for the diamond upgrade

        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = FacetCut({
            facetAddress: address(dLoupeFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });

        cut[1] = FacetCut({
            facetAddress: address(ownershipFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });

        cut[2] = FacetCut({
            facetAddress: address(airdropFactoryFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("AirdropFactoryFacet")
        });

        cut[3] = FacetCut({
            facetAddress: address(poapFactoryFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("PoapFactoryFacet")
        });

        // Upgrade the diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");
        console.log("Diamond successfully upgraded with facets.");
    }

    function verifyDiamond() internal view {
        // Verify facets were added to the diamond
        address[] memory facetAddresses = DiamondLoupeFacet(address(diamond)).facetAddresses();
        console.log("Facets in the Diamond:");
        for (uint256 i = 0; i < facetAddresses.length; i++) {
            console.log("Facet", i, "address:", facetAddresses[i]);
        }
    }

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}
