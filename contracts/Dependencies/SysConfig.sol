// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "./OwnableUpgradeable.sol";
import "./CheckContract.sol";
import "./LiquityMath.sol";
import "./Initializable.sol";
import "../Interfaces/ICollTokenPriceFeed.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/ICollTokenDefaultPool.sol";
import "../Interfaces/ITroveManager.sol";
import "../Interfaces/ICollSurplusPool.sol";
import "../Interfaces/IActivePool.sol";

contract SysConfig is OwnableUpgradeable, CheckContract, Initializable {
    using SafeMath for uint;
    uint constant public CCR = 1500000000000000000; // 150%
    struct ConfigData {
        uint mcr;
        uint ccr;
        uint gasCompensation;
        uint minNetDebt;
        address troveManager;
        address sortedTroves;
        address surplusPool;
        address stabilityPool;
        address defaultPool;
        address activePool;
        bool enabled;
    }

    mapping (address => ConfigData) public tokenConfigData;
    mapping (address => bool) public troveManagerPool;
    ITroveManager public nativeTokenTroveManager;

    ICollTokenPriceFeed public collTokenPriceFeed;
    IPriceFeed public nativeTokenPriceFeed;

    constructor() public {
        _disableInitializers();
    }

    function initialize() initializer external {
        __Ownable_init();
    }

    function checkCollToken(address _collToken) external view {
        require(isNativeToken(_collToken) || tokenConfigData[_collToken].enabled, "Invalid collToken");
    }

    function returnFromPool(address _gasPoolAddress, address _liquidator, uint _LUSD) external {
        require(troveManagerPool[msg.sender], "Not valid trove manager");
        nativeTokenTroveManager.returnFromPool(_gasPoolAddress, _liquidator, _LUSD);
    }

    function burnLUSD(address _account, uint _amount) external {
        require(troveManagerPool[msg.sender], "Not valid trove manager");
        nativeTokenTroveManager.burnLUSD(_account, _amount);
    }

    function fetchPrice(address _collToken) external returns (uint) {
        if (isNativeToken(_collToken)) {
            return nativeTokenPriceFeed.fetchPrice();
        } else {
            return collTokenPriceFeed.fetchPrice(_collToken);
        }
    }

    function updateConfig(address _collToken, ConfigData memory _tokenConfigData) external onlyOwner {
       tokenConfigData[_collToken] = _tokenConfigData;
       troveManagerPool[_tokenConfigData.troveManager] = true;
    }

    function configData(address _collToken) view external returns (ConfigData memory) {
        return tokenConfigData[_collToken];
    }

    function updateCollTokenPriceFeed(ICollTokenPriceFeed _collTokenPriceFeed, IPriceFeed _nativeTokenPriceFeed) external onlyOwner {
        collTokenPriceFeed = _collTokenPriceFeed;
        nativeTokenPriceFeed = _nativeTokenPriceFeed;
    }

    function getCollTokenPriceFeed() view external returns (ICollTokenPriceFeed) {
        return collTokenPriceFeed;
    }

    function getCollTokenCCR(address _collToken, uint _defaultValue) view external returns (uint) {
        if (isNativeToken(_collToken)) {
            return _defaultValue;
        }
        return tokenConfigData[_collToken].ccr;
    }

    function getCollTokenMCR(address _collToken, uint _defaultValue) view external returns (uint) {
        if (isNativeToken(_collToken)) {
            return _defaultValue;
        }
        return tokenConfigData[_collToken].mcr;
    }

    function getCollTokenSurplusPool(address _collToken) view external returns (ICollSurplusPool) {
        return ICollSurplusPool(tokenConfigData[_collToken].surplusPool);
    }

    function getCollTokenDefaultPool(address _collToken) view external returns (address) {
        return tokenConfigData[_collToken].defaultPool;
    }

    function getCollTokenTroveManagerAddress(address _collToken) view external returns (address) {
        return tokenConfigData[_collToken].troveManager;
    }

    function getCollTokenSortedTrovesAddress(address _collToken) view external returns (address) {
        return tokenConfigData[_collToken].sortedTroves;
    }

    function getCollTokenActivePoolAddress(address _collToken) view external returns (address) {
        return tokenConfigData[_collToken].activePool;
    }

    function getCollTokenStabilityPoolAddress(address _collToken) view external returns (address) {
        return tokenConfigData[_collToken].stabilityPool;
    }

    function getEntireSystemColl(address _collToken) public view returns (uint entireSystemColl) {
        address activePoolAddress = tokenConfigData[_collToken].activePool;
        address defaultPoolAddress = tokenConfigData[_collToken].defaultPool;
        uint activeColl = IActivePool(activePoolAddress).getETH();
        uint liquidatedColl = ICollTokenDefaultPool(defaultPoolAddress).getETH();


        return activeColl.add(liquidatedColl);
    }

    function getEntireSystemDebt(address _collToken) public view returns (uint entireSystemDebt) {
        address activePoolAddress = tokenConfigData[_collToken].activePool;
        address defaultPoolAddress = tokenConfigData[_collToken].defaultPool;
        uint activeDebt = IActivePool(activePoolAddress).getLUSDDebt();
        uint closedDebt = ICollTokenDefaultPool(defaultPoolAddress).getLUSDDebt();

        return activeDebt.add(closedDebt);
    }

    function getTCR(address _collToken, uint _price) public view returns (uint TCR) {
        uint entireSystemColl = getEntireSystemColl(_collToken);
        uint entireSystemDebt = getEntireSystemDebt(_collToken);

        TCR = LiquityMath._computeCR(entireSystemColl, entireSystemDebt, _price);

        return TCR;
    }

    function checkRecoveryMode(address _collToken, uint _price) external view returns (bool) {

        uint TCR = getTCR(_collToken, _price);

        return TCR < CCR;
    }

}