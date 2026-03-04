pragma solidity ^0.5.0;

import "./PriceOracle.sol";
import "./BaseRegistrar.sol";
import "./StringUtils.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
 * @dev A registrar controller for registering and renewing names at fixed cost.
 */
contract TNSRegistrarController is Ownable {
    using StringUtils for *;

    uint constant public MIN_COMMITMENT_AGE = 60;
    uint constant public MAX_COMMITMENT_AGE = 48 hours;
    uint constant public MIN_REGISTRATION_DURATION = 28 days;

    BaseRegistrar base;
    PriceOracle prices;
    address payable public treasury;

    mapping(bytes32=>uint) public commitments;

    event NameRegistered(string name, address indexed owner, uint cost, uint expires);
    event NameRenewed(string name, uint cost, uint expires);
    event NewPriceOracle(address indexed oracle);
    event NewTreasury(address indexed treasury);

    constructor(BaseRegistrar _base, PriceOracle _prices, address payable _treasury) public {
        base = _base;
        prices = _prices;
        treasury = _treasury;
    }

    function rentPrice(string memory name, uint duration) view public returns(uint) {
        bytes32 hash = keccak256(bytes(name));
        return prices.price(name, base.nameExpires(uint256(hash)), duration);
    }

    function valid(string memory name) public view returns(bool) {
        return name.strlen() >= 3;
    }

    function available(string memory name) public view returns(bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && base.available(uint256(label));
    }

    function makeCommitment(string memory name, bytes32 secret) pure public returns(bytes32) {
        bytes32 label = keccak256(bytes(name));
        return keccak256(abi.encodePacked(label, secret));
    }

    function commit(bytes32 commitment) public {
        require(commitments[commitment] + MAX_COMMITMENT_AGE < now);
        commitments[commitment] = now;
    }

    function register(string calldata name, address owner, uint duration, bytes32 secret) external payable {
        // Require a valid commitment
        bytes32 commitment = makeCommitment(name, secret);
        require(commitments[commitment] + MIN_COMMITMENT_AGE <= now);

        // If the commitment is too old, or the name is registered, stop
        if(commitments[commitment] + MAX_COMMITMENT_AGE < now || !available(name))  {
            (bool refundSuccess,) = msg.sender.call.value(msg.value)("");
            require(refundSuccess);
            return;
        }
        delete(commitments[commitment]);

        uint cost = rentPrice(name, duration);
        require(duration >= MIN_REGISTRATION_DURATION);
        require(msg.value >= cost);

        bytes32 label = keccak256(bytes(name));
        uint expires = base.register(uint256(label), owner, duration);
        emit NameRegistered(name, owner, cost, expires);

        (bool treasurySuccess,) = treasury.call.value(cost)("");
        require(treasurySuccess);
        if(msg.value > cost) {
            (bool senderSuccess,) = msg.sender.call.value(msg.value - cost)("");
            require(senderSuccess);
        }
    }

    function renew(string calldata name, uint duration) external payable {
        uint cost = rentPrice(name, duration);
        require(msg.value >= cost);

        bytes32 label = keccak256(bytes(name));
        uint expires = base.renew(uint256(label), duration);

        (bool treasurySuccess,) = treasury.call.value(cost)("");
        require(treasurySuccess);
        if(msg.value > cost) {
            (bool senderSuccess,) = msg.sender.call.value(msg.value - cost)("");
            require(senderSuccess);
        }

        emit NameRenewed(name, cost, expires);
    }

    function setPriceOracle(PriceOracle _prices) public onlyOwner {
        prices = _prices;
        emit NewPriceOracle(address(prices));
    }

    function setTreasury(address payable _treasury) public onlyOwner {
        treasury = _treasury;
        emit NewTreasury(_treasury);
    }

    function withdraw() public onlyOwner {
        (bool success,) = treasury.call.value(address(this).balance)("");
        require(success);
    }
}
