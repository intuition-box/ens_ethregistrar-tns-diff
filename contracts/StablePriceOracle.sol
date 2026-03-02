//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "./IPriceOracle.sol";
import "./StringUtils.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev StablePriceOracle for TNS.
 * Adapted from ENS StablePriceOracle for TRUST token pricing.
 * Prices are in TRUST (native token) instead of USD.
 */
contract StablePriceOracle is IPriceOracle, Ownable {
    using StringUtils for *;

    // Rent prices in TRUST per year (in wei)
    uint256 public price1Letter;
    uint256 public price2Letter;
    uint256 public price3Letter;
    uint256 public price4Letter;
    uint256 public price5Letter;

    event RentPriceChanged(uint256[] prices);

    constructor(uint256[] memory _rentPrices) {
        price1Letter = _rentPrices[0];
        price2Letter = _rentPrices[1];
        price3Letter = _rentPrices[2];
        price4Letter = _rentPrices[3];
        price5Letter = _rentPrices[4];
    }

    function price(
        string calldata name,
        uint256 expires,
        uint256 duration
    ) external view override returns (Price memory) {
        uint256 len = name.strlen();
        uint256 basePrice;

        if (len >= 5) {
            basePrice = price5Letter;
        } else if (len == 4) {
            basePrice = price4Letter;
        } else if (len == 3) {
            basePrice = price3Letter;
        } else if (len == 2) {
            basePrice = price2Letter;
        } else {
            basePrice = price1Letter;
        }

        return
            Price({
                base: (basePrice * duration) / 365 days,
                premium: _premium(name, expires, duration)
            });
    }

    /**
     * @dev Returns the premium price for a name.
     * Can be overridden to add premium decay for recently expired names.
     */
    function _premium(
        string memory name,
        uint256 expires,
        uint256 duration
    ) internal view virtual returns (uint256) {
        return 0;
    }

    function setPrices(uint256[] memory _rentPrices) external onlyOwner {
        require(_rentPrices.length == 5, "Must provide 5 prices");
        price1Letter = _rentPrices[0];
        price2Letter = _rentPrices[1];
        price3Letter = _rentPrices[2];
        price4Letter = _rentPrices[3];
        price5Letter = _rentPrices[4];
        emit RentPriceChanged(_rentPrices);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual returns (bool) {
        return interfaceID == type(IPriceOracle).interfaceId;
    }
}
