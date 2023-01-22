// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract ZeroXPad is ERC20, ERC20Capped, ERC20Burnable, Ownable {
    using SafeMath for uint256;

    uint256 public buyFee_ = 300;
    uint256 public sellFee_ = 300;
    bool public tradingEnabled_ = false;

    bool public protectionEnabled_ = true;
    uint256 public protectionModifier_ = 7;

    address public immutable treasury_;
    mapping(address => bool) public isExcludedFromFees_;

    address public pancakePair_ = address(0);

    event BuyFeeChanged(uint256 buyFee);
    event SellFeeChanged(uint256 sellFee);
    event ProtectionModifierChanged(uint256 protectionModifier);
    event TradingEnabled();
    event ProtectionDisabled();

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 maxSupply,
        uint256 initialMint,
        address treasury
    ) ERC20Capped(maxSupply) ERC20(tokenName, tokenSymbol) {
        require(
            treasury != address(0),
            "0xPad: treasury address can not be a null address"
        );

        treasury_ = treasury;
        if (initialMint > 0) _mint(msg.sender, initialMint);

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        pancakePair_ = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
                address(this),
                _uniswapV2Router.WETH()
            );
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    function setBuyFee(uint256 buyFee) public onlyOwner {
        require(
            buyFee > 0 && buyFee < 300,
            "0xPad: buy fee must be between 0 and 300"
        );
        buyFee_ = buyFee;

        emit BuyFeeChanged(buyFee);
    }

    function setSellFee(uint256 sellFee) public onlyOwner {
        require(
            sellFee > 0 && sellFee < 300,
            "0xPad: buy fee must be between 0 and 300"
        );
        sellFee_ = sellFee;

        emit SellFeeChanged(sellFee);
    }

    function setProtectionModifier(uint256 protectionModifier)
        public
        onlyOwner
    {
        require(
            protectionModifier > 0 && protectionModifier <= 7,
            "0xPad: protection modifier must be greater than 0 and less than 7"
        );
        protectionModifier_ = protectionModifier;

        emit ProtectionModifierChanged(protectionModifier);
    }

    function enableTrading() public onlyOwner {
        require(!tradingEnabled_, "0xPad: trading is already enabled");
        tradingEnabled_ = true;

        emit TradingEnabled();
    }

    function disableProtection() public onlyOwner {
        require(
            protectionEnabled_,
            "0xPad: sell protection is already disabled"
        );
        protectionEnabled_ = false;

        emit ProtectionDisabled();
    }

    function excludeFromFees(address holder) public onlyOwner {
        require(
            holder != address(0),
            "0xPad: holder can not be a null address"
        );
        isExcludedFromFees_[msg.sender] = true;
    }

    function includeInFees(address holder) public onlyOwner {
        require(
            holder != address(0),
            "0xPad: holder can not be a null address"
        );
        isExcludedFromFees_[msg.sender] = false;
    }

    function setPancakePair(address pair) public onlyOwner {
        require(pair != address(0), "0xPad: pair can not be a null address");
        pancakePair_ = pair;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(tradingEnabled_, "0xPad: trading is currently disabled");

        if (isExcludedFromFees_[from] || isExcludedFromFees_[to]) {
            super._transfer(from, to, amount);
        } else if (from == pancakePair_) {
            uint256 fees = amount.mul(buyFee_).div(10000);
            uint256 rest = amount - fees;

            super._transfer(from, treasury_, fees);
            super._transfer(from, to, rest);
        } else if (to == pancakePair_) {
            uint256 fees = 0;
            if (protectionEnabled_) {
                uint256 penaltyPercentage = sellFee_.add(
                    sellFee_.mul(protectionModifier_)
                );

                fees = amount.mul(penaltyPercentage).div(10000);
            } else {
                fees = amount.mul(sellFee_).div(10000);
            }

            uint256 rest = amount - fees;
            super._transfer(from, treasury_, fees);
            super._transfer(from, to, rest);
        } else {
            super._transfer(from, to, amount);
        }
    }

    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        super._mint(account, amount);
    }
}
