// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// --- Interface IPropertyDataConsensus ---
interface IPropertyDataConsensus {
    // --- Events ---
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
    event ConsensusUpdated(
        bytes32 indexed propertyHash,
        bytes32 indexed dataGroupHash,
        bytes32 oldDataHash,
        bytes32 newDataHash,
        address[] newOracles
    );
    event MinimumConsensusUpdated(uint256 oldValue, uint256 newValue);

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

    // --- Functions ---
    function minimumConsensus() external view returns (uint256);

    /**
     * @notice Updates the minimum number of consensus votes required.
     * @dev Can only be called by an account with ORACLE_MANAGER_ROLE.
     * Emits a {MinimumConsensusUpdated} event.
     * @param newMinimumConsensus The new minimum consensus value (must be >= 3).
     */
    function updateMinimumConsensus(uint256 newMinimumConsensus) external;

    function submitData(bytes32 propertyHash, bytes32 dataGroupHash, bytes32 dataHash) external;

    function submitBatchData(DataItem[] calldata items) external;

    function getCurrentFieldDataHash(bytes32 propertyHash, bytes32 dataGroupHash) external view returns (bytes32);

    function getSubmitterCountForDataHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash
    ) external view returns (uint256 count);

    function getConsensusHistory(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    ) external view returns (IPropertyDataConsensus.DataVersion[] memory);

    function getParticipantsForConsensusDataHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash
    ) external view returns (address[] memory);

    function getCurrentConsensusParticipants(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    ) external view returns (address[] memory);

    function hasUserSubmittedDataHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash,
        address submitter
    ) external view returns (bool);

    /**
     * @notice Set the vMahout token address
     * @param _vMahout The address of the vMahout token
     */
    function setVMahout(address _vMahout) external;
}

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}

/**
 * @title PropertyDataConsensus
 * @notice Permissionless consensus system for property data with UUPS upgradeability
 */
contract PropertyDataConsensus is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IPropertyDataConsensus {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Minimum number of different addresses required for consensus
    uint256 public override minimumConsensus;

    mapping(bytes32 => mapping(bytes32 => EnumerableSet.AddressSet)) private _submissionData;
    mapping(bytes32 => bytes32) private _currentConsensusDataHash;
    mapping(bytes32 => IPropertyDataConsensus.DataVersion[]) private _consensusLog;
    IERC20Mintable public vMahout;
    mapping(bytes32 => uint256) public _consensusRequired;
    bytes32 public constant LEXICON_ORACLE_MANAGER_ROLE = keccak256("LEXICON_ORACLE_MANAGER_ROLE");

    // Custom Errors
    error AlreadySubmittedThisDataHash(address submitter, bytes32 propertyHashFieldHash, bytes32 dataHash);
    error DataHashAlreadyConsensus(bytes32 propertyHashFieldHash, bytes32 dataHash);
    error NoConsensusReachedForDataHash(bytes32 propertyHashFieldHash, bytes32 dataHash);
    error NoConsensusHistory(bytes32 propertyHashFieldHash);

    error InvalidMinimumConsensus(uint256 value);
    error EmptyBatchSubmission();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _getPropertyHashFieldHash(bytes32 propertyHash, bytes32 dataGroupHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(propertyHash, dataGroupHash));
    }

    /**
     * @notice Initialize the contract
     * @param _minimumConsensus Minimum number of addresses required for consensus
     * @param initialAdmin Address that will be granted DEFAULT_ADMIN_ROLE and ORACLE_MANAGER_ROLE.
     */
    function initialize(uint256 _minimumConsensus, address initialAdmin) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        minimumConsensus = _minimumConsensus < 3 ? 3 : _minimumConsensus;

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function updateMinimumConsensus(uint256 newMinimumConsensus) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMinimumConsensus < 3) {
            revert InvalidMinimumConsensus(newMinimumConsensus);
        }
        uint256 oldValue = minimumConsensus;
        minimumConsensus = newMinimumConsensus;
        emit MinimumConsensusUpdated(oldValue, newMinimumConsensus);
    }

    function submitData(bytes32 propertyHash, bytes32 dataGroupHash, bytes32 dataHash) public override {
        _submitDataInternal(propertyHash, dataGroupHash, dataHash);
    }

    function submitBatchData(DataItem[] calldata items) public override {
        uint256 length = items.length;
        if (length == 0) {
            revert EmptyBatchSubmission();
        }
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                _submitDataInternal(items[i].propertyHash, items[i].dataGroupHash, items[i].dataHash);
            }
        }
    }

    function _submitDataInternal(bytes32 propertyHash, bytes32 dataGroupHash, bytes32 dataHash) internal {
        address submitter = msg.sender;
        bytes32 propertyHashFieldHash = _getPropertyHashFieldHash(propertyHash, dataGroupHash);
        if (_currentConsensusDataHash[propertyHashFieldHash] == dataHash) {
            revert DataHashAlreadyConsensus(propertyHashFieldHash, dataHash);
        }
        EnumerableSet.AddressSet storage submittersForDataHash = _submissionData[propertyHashFieldHash][dataHash];
        submittersForDataHash.add(submitter);
        emit DataSubmitted(propertyHash, dataGroupHash, submitter, dataHash);
        uint256 requiredConsensus = _consensusRequired[dataGroupHash];
        if (requiredConsensus == 0) {
            requiredConsensus = minimumConsensus;
        }
        if (submittersForDataHash.length() >= requiredConsensus) {
            address[] memory oracles = submittersForDataHash.values();
            IPropertyDataConsensus.DataVersion memory newVersion = IPropertyDataConsensus.DataVersion({
                dataHash: dataHash,
                oracles: oracles,
                timestamp: block.timestamp
            });
            bytes32 oldDataHash = _currentConsensusDataHash[propertyHashFieldHash];
            _currentConsensusDataHash[propertyHashFieldHash] = dataHash;
            _consensusLog[propertyHashFieldHash].push(newVersion);
            if (address(vMahout) != address(0)) {
                for (uint256 i = 0; i < oracles.length; i++) {
                    vMahout.mint(oracles[i], 0.016 ether);
                }
            }
            if (oldDataHash != bytes32(0)) {
                emit ConsensusUpdated(propertyHash, dataGroupHash, oldDataHash, dataHash, oracles);
            } else {
                emit ConsensusReached(propertyHash, dataGroupHash, dataHash, oracles);
            }
        }
    }

    function getCurrentFieldDataHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    ) public view override returns (bytes32) {
        bytes32 propertyHashFieldHash = _getPropertyHashFieldHash(propertyHash, dataGroupHash);
        return _currentConsensusDataHash[propertyHashFieldHash];
    }

    function getSubmitterCountForDataHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash
    ) public view override returns (uint256 count) {
        bytes32 propertyHashFieldHash = _getPropertyHashFieldHash(propertyHash, dataGroupHash);
        return _submissionData[propertyHashFieldHash][dataHash].length();
    }

    function getConsensusHistory(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    ) public view override returns (IPropertyDataConsensus.DataVersion[] memory) {
        bytes32 propertyHashFieldHash = _getPropertyHashFieldHash(propertyHash, dataGroupHash);
        return _consensusLog[propertyHashFieldHash];
    }

    function getParticipantsForConsensusDataHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash
    ) public view override returns (address[] memory) {
        bytes32 propertyHashFieldHash = _getPropertyHashFieldHash(propertyHash, dataGroupHash);
        IPropertyDataConsensus.DataVersion[] storage versions = _consensusLog[propertyHashFieldHash];
        for (uint256 i = versions.length; i > 0; i--) {
            if (versions[i - 1].dataHash == dataHash) {
                return versions[i - 1].oracles;
            }
        }
        revert NoConsensusReachedForDataHash(propertyHashFieldHash, dataHash);
    }

    function getCurrentConsensusParticipants(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    ) public view override returns (address[] memory) {
        bytes32 propertyHashFieldHash = _getPropertyHashFieldHash(propertyHash, dataGroupHash);
        bytes32 currentDataHash = _currentConsensusDataHash[propertyHashFieldHash];
        if (currentDataHash == bytes32(0)) {
            return new address[](0);
        }
        return _submissionData[propertyHashFieldHash][currentDataHash].values();
    }

    function hasUserSubmittedDataHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash,
        address submitter
    ) public view override returns (bool) {
        bytes32 propertyHashFieldHash = _getPropertyHashFieldHash(propertyHash, dataGroupHash);
        return _submissionData[propertyHashFieldHash][dataHash].contains(submitter);
    }

    function setConsensusRequired(
        bytes32 dataGroupHash,
        uint256 requiredConsensus
    ) external onlyRole(LEXICON_ORACLE_MANAGER_ROLE) {
        if (requiredConsensus < 3) {
            revert InvalidMinimumConsensus(requiredConsensus);
        }
        _consensusRequired[dataGroupHash] = requiredConsensus;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Sets the vMahout token address used for minting rewards to oracles.
     * @dev Can only be called by an account with DEFAULT_ADMIN_ROLE.
     * @param _vMahout The address of the vMahout token contract.
     */
    function setVMahout(address _vMahout) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        vMahout = IERC20Mintable(_vMahout);
    }
}
