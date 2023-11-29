// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* @title Decentralized Stable Coin
 * @author Fred
 * @dev This contract is a decentralized stable coin engine system for DSC
 */
contract DSCEngine {
    error DSCEngine__MustMoreThanZero();
    error DSCEngine__NotAllowCollateral();
    error DSCEngine__DepositFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthfactorBreak();
    error DSCEngine__NotEnoughBalance();
    error DSCEngine__BurnFailed();
    error DSCEngine__RedeemFailed();
    error DSCEngine__AddNotEnough();

    address[] private s_collateralAddresses;
    DecentralizedStableCoin private immutable i_DSCAddress;

    uint256 private constant COLLATERAL_RATIO = 200;
    uint256 private constant MINIMUM_COLLATERAL_RATIO = 150;
    uint256 private constant ADDITIONAL_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    mapping(address => address) private s_priceFeeds;
    mapping(address user => mapping(address collateralAddress => uint256 amount))
        private s_collateralAmounts;
    mapping(address user => uint256) private s_DSCAmounts;

    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__MustMoreThanZero();
        }
        _;
    }

    modifier isAllowedCollateral(address _collateralAddress) {
        bool isAllowed = false;
        for (uint256 i = 0; i < s_collateralAddresses.length; i++) {
            if (s_collateralAddresses[i] == _collateralAddress) {
                isAllowed = true;
                break;
            }
        }
        if (!isAllowed) {
            revert DSCEngine__NotAllowCollateral();
        }
        _;
    }

    constructor(
        address[] memory _collateralAddress,
        address[] memory _priceFeeds,
        DecentralizedStableCoin _DSCAddress
    ) {
        s_collateralAddresses = _collateralAddress;
        i_DSCAddress = _DSCAddress;
        for (uint256 i = 0; i < _collateralAddress.length; i++) {
            s_priceFeeds[_collateralAddress[i]] = _priceFeeds[i];
        }
    }

    function depositCollateralAndMintDSC(
        address _collateralAddress,
        uint256 _amount
    )
        public
        payable
        moreThanZero(_amount)
        isAllowedCollateral(_collateralAddress)
        returns (bool)
    {
        IERC20 collateral = IERC20(_collateralAddress);
        bool DepositSuccess = collateral.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!DepositSuccess) {
            revert DSCEngine__DepositFailed();
        }
        s_collateralAmounts[msg.sender][_collateralAddress] += _amount;
        uint256 DSCAmount = _calculateDSCAmount(_collateralAddress, _amount);
        bool MintSuccess = i_DSCAddress.mint(msg.sender, DSCAmount);
        if (!MintSuccess) {
            revert DSCEngine__MintFailed();
        }
        s_DSCAmounts[msg.sender] += DSCAmount;
        return true;
    }

    function redeemCollateralForDSC(
        address _collateralAddress,
        uint256 _collateralAmount,
        uint256 _DSCAmount
    ) public returns (bool) {
        IERC20 collateral = IERC20(_collateralAddress);
        _burnDSC(_DSCAmount);
        s_collateralAmounts[msg.sender][
            _collateralAddress
        ] -= _collateralAmount;
        bool success = collateral.transfer(msg.sender, _collateralAmount);
        if (!success) {
            revert DSCEngine__RedeemFailed();
        }
        revertIfHealthFactorBreak(msg.sender);
        return true;
    }

    function liquidateCollateral(
        address user,
        address _collateralAddress,
        uint256 _amount
    ) public payable {
        if (_liquidateRequire(user)) {
            uint256 totalCollateralValuePre = 0; //18
            uint256 totalDSCAmount = s_DSCAmounts[user];

            //@dev calculate total collateral value
            for (uint256 i = 0; i < s_collateralAddresses.length; i++) {
                uint256 collateralUserAmount = s_collateralAmounts[user][
                    s_collateralAddresses[i]
                ];
                uint256 collateralPrice = _getPriceFeed(
                    s_collateralAddresses[i]
                );
                totalCollateralValuePre +=
                    collateralUserAmount *
                    collateralPrice *
                    ADDITIONAL_PRECISION;
            }

            //@dev calculate total collateral value after add
            if (
                totalCollateralValuePre +
                    _getAddValue(_collateralAddress, _amount) <
                (totalDSCAmount * PRECISION * COLLATERAL_RATIO) / 1e2
            ) {
                revert DSCEngine__AddNotEnough();
            }

            //transfer the collateral to the liquidator
            bool suceess = IERC20(_collateralAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            );
            if (!suceess) {
                revert DSCEngine__DepositFailed();
            }

            // update the collateral amount of the msg.sender and the previous user
            for (uint256 i = 0; i < s_collateralAddresses.length; i++) {
                uint256 collateralUserAmount = s_collateralAmounts[user][
                    s_collateralAddresses[i]
                ];
                collateralUserAmount = 0;
                s_collateralAmounts[msg.sender][
                    s_collateralAddresses[i]
                ] = collateralUserAmount;
            }
            s_collateralAmounts[msg.sender][_collateralAddress] += _amount;
        }
    }

    function _getAddValue(
        address _collateralAddress,
        uint256 _amount
    ) internal view returns (uint value) {
        uint256 collateralPrice = _getPriceFeed(_collateralAddress) *
            ADDITIONAL_PRECISION;
        value = _amount * collateralPrice;
    }

    function getHealthFactor(address user) public view returns (uint256) {
        uint256 totalCollateralValue = 0;
        uint256 totalDSCValue = 0;
        for (uint256 i = 0; i < s_collateralAddresses.length; i++) {
            uint256 collateralPrice = _getPriceFeed(s_collateralAddresses[i]);
            totalCollateralValue += (s_collateralAmounts[user][
                s_collateralAddresses[i]
            ] *
                collateralPrice *
                ADDITIONAL_PRECISION);
        }
        totalDSCValue = s_DSCAmounts[user] * PRECISION;
        return ((1e2 * totalCollateralValue) / totalDSCValue);
    }

    function _calculateDSCAmount(
        address _collateralAddress,
        uint256 _amount
    ) internal view returns (uint256 DSCAmount) {
        uint256 collateralPrice = _getPriceFeed(_collateralAddress) *
            ADDITIONAL_PRECISION;
        DSCAmount =
            (_amount * collateralPrice) /
            PRECISION /
            COLLATERAL_RATIO /
            1e2;
    }

    function _getPriceFeed(
        address _collateralAddress
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_collateralAddress]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function _burnDSC(uint256 _amount) internal returns (bool) {
        uint256 balance = i_DSCAddress.balanceOf(msg.sender);
        if (balance < _amount) {
            revert DSCEngine__NotEnoughBalance();
        }
        bool success = i_DSCAddress.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!success) {
            revert DSCEngine__BurnFailed();
        }
        i_DSCAddress.burn(_amount);
        s_DSCAmounts[msg.sender] = balance - _amount;
        return true;
    }

    function _liquidateRequire(
        address user
    ) internal view returns (bool result) {
        result = false;
        if (getHealthFactor(user) <= MINIMUM_COLLATERAL_RATIO) {
            result = true;
        }
    }

    function revertIfHealthFactorBreak(address user) internal view {
        if (getHealthFactor(user) <= MINIMUM_COLLATERAL_RATIO) {
            revert DSCEngine__HealthfactorBreak();
        }
    }
}

//疑问：revertIfHealthFactorBreak函数的作用以及如果在其他函数最后的时候调用，会不会影响区块链状态，还是整个函数revert，因为reentrancy的问题
