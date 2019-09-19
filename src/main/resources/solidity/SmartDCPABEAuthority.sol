pragma solidity ^0.5.1;
import "./SmartDCPABEUtility.sol";
import "./SmartDCPABEUsers.sol";
import "./Collection.sol";

contract SmartDCPABEAuthority is Collection {

    struct Certifier {
        address addr;
        bytes32 name;
        bytes32 email;
        uint64 numPublicKeys;
    }

    enum KeyRequestStatus {
        PENDING,
        OK,
        REJECTED
    }

    struct KeyRequest {
        KeyRequestStatus status;
        uint64 timestamp;
        uint64 responseTimestamp;
        bytes32[] attrNames;
    }

    // FIX: add constructor as stated on solidity documentation: https://solidity.readthedocs.io/en/develop/contracts.html#arguments-for-base-constructors

    address[] public certifierAddresses;
    mapping (address => Certifier) certifiers;
    mapping (address => address[]) attributeRequesters;
    mapping (address => mapping (address => uint64[])) pendingRequests;
    mapping (address => mapping (address => KeyRequest[])) requests;
    SmartDCPABEUtility util;
    SmartDCPABEUsers user;
    address contractKeys;

    constructor(address root) Collection(root) public {}

    function setContractDependencies(ContractType contractType, address addr) public {
        require(msg.sender == owner, "Operation not allowed. Must be the done by the owner of the contract.");
        if (contractType == ContractType.UTILITY) {
            util = SmartDCPABEUtility(addr);
        } else if (contractType == ContractType.USERS) {
            user = SmartDCPABEUsers(addr);
        } else if (contractType == ContractType.KEYS) {
            contractKeys = addr;
        }
    }

    function incrementPublicKeyCount(address addr) public {
        require(msg.sender == contractKeys, "Operation not allowed.");
        certifiers[addr].numPublicKeys++;
    }

    function isCertifier(address addr) public view returns (bool) {
        return certifiers[addr].name != bytes32(0);
    }

    function addCertifier(address addr, string memory name, string memory email) public {
        certifierAddresses.push(addr);
        certifiers[addr] = Certifier(addr, util.stringToBytes32(name), util.stringToBytes32(email), 0);
    }

    /**
     * attrNames are bytes32 instead of string because I don't tested if web3j works well
     * with dynamic array of dynamic types string/bytes
     */
    function addRequest(address authority, address requester, uint64 timestamp, bytes32[] memory attrNames) public {
        assert(user.isUser(requester));
        assert(isCertifier(authority));
        // cria uma lista de espera para aquele endereço
        uint64 pendingIndex = uint64(requests[authority][requester].length);
        requests[authority][requester].push(KeyRequest(KeyRequestStatus.PENDING, timestamp, 0, attrNames));
        pendingRequests[authority][requester].push(pendingIndex);
        attributeRequesters[authority].push(requester);
    }

    function processRequest(address authority, uint64 requesterIndex, uint64 pendingIndex, KeyRequestStatus newStatus) public {
        address requester = attributeRequesters[authority][requesterIndex];
        require(pendingRequests[authority][requester].length >= 1, "No pending requests for this authority.");
        uint64 index = pendingRequests[authority][requester][pendingIndex];
        requests[authority][requester][index].status = newStatus;
        if (pendingRequests[authority][requester].length == 1) {
            pendingRequests[authority][requester].pop();
            address lastRequester = attributeRequesters[authority][attributeRequesters[authority].length - 1];
            attributeRequesters[authority].length--;
            if (pendingIndex != attributeRequesters[authority].length) {
                attributeRequesters[authority][pendingIndex] = lastRequester;
            }
        } else {
            uint64 lastIndex = pendingRequests[authority][requester][pendingRequests[authority][requester].length - 1];
            pendingRequests[authority][requester].length--;
            if (pendingIndex != pendingRequests[authority][requester][pendingRequests[authority][requester].length - 1]) {
                pendingRequests[authority][requester][pendingIndex] = lastIndex;
            }
        }
    }

    function getPendingListSize(address authority, address requester) public view returns (uint256) {
        return pendingRequests[authority][requester].length;
    }

    function getPendingRequesterListSize(address authority) public view returns (uint256) {
        return attributeRequesters[authority].length;
    }

    function getPendingRequesterAddress(address authority, uint64 requesterIndex) public view returns (address) {
        return attributeRequesters[authority][requesterIndex];
    }

    function getRequestStatus(address authority, address requester, uint64 index) public view returns (KeyRequestStatus status) {
        return requests[authority][requester][index].status;
    }

    function getPendingRequest
    (
        address authority,
        address requester,
        uint64 index
    )
        public
        view
        returns
    (
        KeyRequestStatus status,
        uint64 timestamp,
        uint64 responseTimestamp,
        bytes32[] memory attrNames
    )
    {
        return getRequest(authority, requester, pendingRequests[authority][requester][index]);
    }

    function getRequest
    (
        address authority,
        address requester,
        uint64 index
    )
        public
        view
        returns
    (
        KeyRequestStatus status,
        uint64 timestamp,
        uint64 responseTimestamp,
        bytes32[] memory attrNames
    )
    {
        KeyRequest memory kr = requests[authority][requester][index];
        return (
            kr.status,
            kr.timestamp,
            kr.responseTimestamp,
            kr.attrNames
            );
    }

    function getCertifier
    (
        address addr
    )
        public
        view
        returns
    (
        address addr_,
        string memory name,
        string memory email,
        uint64 numPublicKeys
    )
    {
        Certifier storage c = certifiers[addr];
        return (c.addr, util.bytes32ToString(c.name), util.bytes32ToString(c.email), c.numPublicKeys);
    }
}