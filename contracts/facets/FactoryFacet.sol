// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {SonikDrop} from "./SonikDropFacet.sol";
import {Errors, Events} from "../libraries/Utils.sol";

contract FactoryFacet {
    //  when a person interacts with the factory, he would options like
    // 1. Adding an NFT requirement
    // 2. Adding a time lock

    function _createSonikDrop(
        address _tokenAddress,
        bytes32 _merkleRoot,
        address _nftAddress,
        uint256 _claimTime,
        uint256 _noOfClaimers
    ) private returns (LibDiamond.SonikDropObj memory) {
        if (msg.sender == address(0)) {
            revert Errors.ZeroAddressDetected();
        }
        if (_noOfClaimers == 0) {
            revert Errors.ZeroValueDetected();
        }

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        SonikDrop newSonik_ = new SonikDrop();

        uint256 _id = ds.cloneCount;

        LibDiamond.SonikDropObj memory _newSonikObj = LibDiamond.SonikDropObj({
            id: _id,
            tokenAddress: _tokenAddress,
            nftAddress: _nftAddress,
            contractAddress: address(newSonik_),
            owner: msg.sender,
            merkleRoot: _merkleRoot,
            claimTime: _claimTime,
            totalNoOfClaimers: _noOfClaimers,
            isNftRequired: _nftAddress != address(0),
            isTimeLocked: _claimTime != 0,
            airdropEndTime: block.timestamp + _claimTime,
            totalAmountSpent: 0,
            totalNoOfClaimed: 0
        });
        ds.ownerToSonikDropCloneContracts[msg.sender].push(address(newSonik_));
        ds.sonikContractToObj[address(newSonik_)] = _newSonikObj;
        ds.allSonikDropClones.push(address(newSonik_));
        ++ds.cloneCount;

        emit Events.SonikCloneCreated(
            msg.sender,
            block.timestamp,
            address(newSonik_)
        );

        return _newSonikObj;
    }

    function createSonikDrop(
        address _tokenAddress,
        bytes32 _merkleRoot,
        address _nftAddress,
        uint256 _noOfClaimers
    ) external returns (LibDiamond.SonikDropObj memory) {
        return
            _createSonikDrop(
                _tokenAddress,
                _merkleRoot,
                _nftAddress,
                0,
                _noOfClaimers
            );
    }

    function createSonikDrop(
        address _tokenAddress,
        bytes32 _merkleRoot,
        uint256 _noOfClaimers
    ) external returns (LibDiamond.SonikDropObj memory) {
        return
            _createSonikDrop(
                _tokenAddress,
                _merkleRoot,
                address(0),
                0,
                _noOfClaimers
            );
    }

    function getOwnerSonikDropClones(
        address _owner
    ) external view returns (LibDiamond.SonikDropObj[] memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address[] memory cloneContractAddresses = ds
            .ownerToSonikDropCloneContracts[_owner];

        LibDiamond.SonikDropObj[]
            memory sonikDropObjs = new LibDiamond.SonikDropObj[](
                cloneContractAddresses.length
            );
        for (uint i = 0; i < cloneContractAddresses.length; i++) {
            sonikDropObjs[i] = ds.sonikContractToObj[cloneContractAddresses[i]];
        }
        return sonikDropObjs;
    }

    function getAllSonikDropClones()
        external
        view
        returns (address[] memory)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.allSonikDropClones;
    }

    function readSonikClone(
        address _sonikAddress
    ) external view returns (LibDiamond.SonikDropObj memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.sonikContractToObj[_sonikAddress];
    }
}
