// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "./helpers/DiamondUtils.sol";

import {AirdropFactoryFacet} from "../contracts/facets/erc20facets/FactoryFacet.sol";
import {PoapFactoryFacet} from "../contracts/facets/erc721facets/PoapFactoryFacet.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    error Create2EmptyBytecode();
    error Create2FailedDeployment();
    //contract types of facets to be deployed

    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    AirdropFactoryFacet factoryF;
    PoapFactoryFacet poapFactoryF;

    function setUp() public {
        //deploy facets

        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        poapFactoryF = new PoapFactoryFacet();
        factoryF = new AirdropFactoryFacet();
        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(factoryF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AirdropFactoryFacet")
            })
        );
        cut[3] = (
            FacetCut({
                facetAddress: address(factoryF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("PoapFactoryFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testDiamond() public {}

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}
