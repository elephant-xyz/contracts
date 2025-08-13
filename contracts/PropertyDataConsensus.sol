// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Initializable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EnumerableSet } from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { VMahout } from "./VMahout.sol";

/**
 * @title PropertyDataConsensus
 * @notice Permissionless consensus system for property data with UUPS upgradeability
 */
contract PropertyDataConsensus is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    event DataSubmitted(
        bytes32 indexed propertyHash,
        bytes32 indexed dataGroupHash,
        address indexed submitter,
        bytes32 dataHash
    );
    event ConsensusReached(
        bytes32 indexed propertyHash,
        bytes32 indexed dataGroupHash,
        bytes32 dataHash,
        address[] oracles
    );
    event MinimumConsensusUpdated(uint256 oldValue, uint256 newValue);
    event DataGroupConsensusUpdated(
        bytes32 indexed dataGroupHash, uint256 oldValue, uint256 newValue
    );

    // --- Structs ---
    struct DataVersion {
        bytes32 dataHash;
        address[] oracles;
        uint256 timestamp;
    }

    struct DataItem {
        bytes32 propertyHash;
        bytes32 dataGroupHash;
        bytes32 dataHash;
    }
    // Minimum number of different addresses required for consensus

    uint256 public minimumConsensus;

    mapping(bytes32 => mapping(bytes32 => EnumerableSet.AddressSet)) private
        _submissionData;
    mapping(bytes32 => bytes32) private _currentConsensusDataHash;
    mapping(bytes32 => DataVersion[]) private _consensusLog;
    VMahout public vMahout;
    mapping(bytes32 => uint256) public consensusRequired;
    bytes32 public constant LEXICON_ORACLE_MANAGER_ROLE =
        keccak256("LEXICON_ORACLE_MANAGER_ROLE");

    // Custom Errors
    error AlreadySubmittedThisDataHash(
        address submitter, bytes32 propertyHashFieldHash, bytes32 dataHash
    );
    error DataHashAlreadyConsensus(
        bytes32 propertyHashFieldHash, bytes32 dataHash
    );
    error NoConsensusReachedForDataHash(
        bytes32 propertyHashFieldHash, bytes32 dataHash
    );
    error NoConsensusHistory(bytes32 propertyHashFieldHash);

    error InvalidMinimumConsensus(uint256 value);
    error EmptyBatchSubmission();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _getPropertyHashFieldHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(propertyHash, dataGroupHash));
    }

    /**
     * @notice Initialize the contract
     * @param _minimumConsensus Minimum number of addresses required for consensus
     * @param initialAdmin Address that will be granted DEFAULT_ADMIN_ROLE and ORACLE_MANAGER_ROLE.
     */
    function initialize(
        uint256 _minimumConsensus,
        address initialAdmin
    )
        external
        initializer
    {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        minimumConsensus = _minimumConsensus < 3 ? 3 : _minimumConsensus;

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function updateMinimumConsensus(uint256 newMinimumConsensus)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newMinimumConsensus < 3) {
            revert InvalidMinimumConsensus(newMinimumConsensus);
        }
        uint256 oldValue = minimumConsensus;
        minimumConsensus = newMinimumConsensus;
        emit MinimumConsensusUpdated(oldValue, newMinimumConsensus);
    }

    function submitData(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash
    )
        public
    {
        _submitDataInternal(propertyHash, dataGroupHash, dataHash);
        if (address(vMahout) != address(0)) {
            vMahout.mint(msg.sender, 0.016 ether);
        }
    }

    function submitBatchData(DataItem[] calldata items) public {
        uint256 length = items.length;
        if (length == 0) {
            revert EmptyBatchSubmission();
        }
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                _submitDataInternal(
                    items[i].propertyHash,
                    items[i].dataGroupHash,
                    items[i].dataHash
                );
            }
        }
        if (address(vMahout) != address(0)) {
            vMahout.mint(msg.sender, 0.016 ether * length);
        }
    }

    function _submitDataInternal(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash
    )
        internal
    {
        address submitter = msg.sender;
        bytes32 propertyHashFieldHash =
            _getPropertyHashFieldHash(propertyHash, dataGroupHash);
        if (_currentConsensusDataHash[propertyHashFieldHash] == dataHash) {
            revert DataHashAlreadyConsensus(propertyHashFieldHash, dataHash);
        }
        emit DataSubmitted(propertyHash, dataGroupHash, submitter, dataHash);

        address[] memory oracles = new address[](1);
        oracles[0] = submitter;
        _currentConsensusDataHash[propertyHashFieldHash] = dataHash;

        emit ConsensusReached(propertyHash, dataGroupHash, dataHash, oracles);
    }

    function getCurrentFieldDataHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    )
        public
        view
        returns (bytes32)
    {
        bytes32 propertyHashFieldHash =
            _getPropertyHashFieldHash(propertyHash, dataGroupHash);
        return _currentConsensusDataHash[propertyHashFieldHash];
    }

    function setConsensusRequired(
        bytes32 dataGroupHash,
        uint256 requiredConsensus
    )
        external
        onlyRole(LEXICON_ORACLE_MANAGER_ROLE)
    {
        uint256 oldValue = consensusRequired[dataGroupHash];
        consensusRequired[dataGroupHash] = requiredConsensus;
        emit DataGroupConsensusUpdated(
            dataGroupHash, oldValue, requiredConsensus
        );
    }

    /**
     * @notice Gets the consensus threshold for a specific data group
     * @dev Returns the custom threshold if set, otherwise returns the global minimum consensus
     * @param dataGroupHash The hash of the data group
     * @return The required consensus threshold
     */
    function _getConsensusRequired(bytes32 dataGroupHash)
        internal
        view
        returns (uint256)
    {
        uint256 required = consensusRequired[dataGroupHash];
        return required == 0 ? minimumConsensus : required;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    { }

    /**
     * @notice Sets the vMahout token address used for minting rewards to oracles.
     * @dev Can only be called by an account with DEFAULT_ADMIN_ROLE.
     * @param _vMahout The address of the vMahout token contract.
     */
    function setVMahout(address _vMahout)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        vMahout = VMahout(_vMahout);
    }
}
