// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import {AirdropFactoryFacet} from "../contracts/facets/erc20facets/FactoryFacet.sol";
import {SonikDrop} from "../contracts/facets/erc20facets/SonikDropFacet.sol";
import "../contracts/Diamond.sol";

import "./helpers/DiamondUtils.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    AirdropFactoryFacet factoryF;
    SonikDrop sonikDropF;

    address owner = makeAddr("youngancient");

    function setUp() public {
        //deploy facets
        

        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();

        factoryF = new AirdropFactoryFacet();
        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

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

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();


        //interact with factory
        address[] memory addresses = AirdropFactoryFacet(address(diamond)).getAllSonikDropClones();
        assertEq(addresses.length, 0 );

        // create sonik token drop without NFT
        address _tokenAddress = address(0x01);
        bytes32 _merkleRoot = 0x29c08bc8bf7d3a0ed4b1dd16063389608cf9dec220f1584e32d317c2041e1fa4;
        uint256 _noOfClaimers = 100;
        uint256 _totalOutputTokens = 1000;
    }

    function testCreateSonikDrop() public {
        //call createSonikDrop
        // factoryF.createSonikDrop();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
