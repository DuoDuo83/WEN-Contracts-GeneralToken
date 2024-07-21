// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./OwnableUpgradeable.sol";
import "./CheckContract.sol";
import "./LiquityMath.sol";
import "./Initializable.sol";
import "./LiquityBase.sol";
import "../Interfaces/ICollTokenPriceFeed.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/ICollTokenDefaultPool.sol";
import "../Interfaces/ITroveManager.sol";
import "../Interfaces/ICollSurplusPool.sol";
import "../Interfaces/IActivePool.sol";

contract SysConfig is OwnableUpgradeable, CheckContract, Initializable {
    using SafeMath for uint;
    struct ConfigData {
        uint mcr;
        uint ccr;
        uint lpr; // liquidation protocol fee ratio, decimals 2
        address troveManager;
        address sortedTroves;
        address surplusPool;
        address stabilityPool;
        address defaultPool;
        address activePool;
        bool enabled;
    }

    mapping (address => ConfigData) public tokenConfigData; // collToken => ConfigData
    mapping (address => bool) public troveManagerPool; // collTokenTroveManager => bool
    ITroveManager public nativeTokenTroveManager;

    ICollTokenPriceFeed public collTokenPriceFeed;
    IPriceFeed public nativeTokenPriceFeed;
    address[] public collTokens;

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

    function updateConfig(address _collToken, uint mcr, uint ccr) external onlyOwner {
        require(mcr > 0, "!mcr");
        require(ccr > 0, "!mcr");
        tokenConfigData[_collToken].mcr = mcr;
        tokenConfigData[_collToken].ccr = ccr;
        if (tokenConfigData[_collToken].troveManager != address(0x0) && !tokenConfigData[_collToken].enabled) {
            tokenConfigData[_collToken].enabled = true;
        }
    }

    function updateLpr(address _collToken, uint _lpr) external onlyOwner {
        require (_lpr < 100, "!lpr");
        tokenConfigData[_collToken].lpr = _lpr;
    }

    function setAddresses(address _collToken,
                          address _troveManager,
                          address _sortedTroves,
                          address _surplusPool,
                          address _stabilityPool,
                          address _defaultPool,
                          address _activePool,
                          address _nativeTroveManager,
                          address _nativeTokenPriceFeed,
                          address _collTokenPriceFeed
    ) external onlyOwner {
        checkContract(_troveManager);
        checkContract(_sortedTroves);
        checkContract(_surplusPool);
        checkContract(_stabilityPool);
        checkContract(_defaultPool);
        checkContract(_activePool);
        checkContract(_nativeTroveManager);
        checkContract(_nativeTokenPriceFeed);
        checkContract(_collTokenPriceFeed);

        tokenConfigData[_collToken].troveManager = _troveManager;
        tokenConfigData[_collToken].sortedTroves = _sortedTroves;
        tokenConfigData[_collToken].surplusPool = _surplusPool;
        tokenConfigData[_collToken].stabilityPool = _stabilityPool;
        tokenConfigData[_collToken].defaultPool = _defaultPool;
        tokenConfigData[_collToken].activePool = _activePool;

        if (tokenConfigData[_collToken].mcr > 0 && !tokenConfigData[_collToken].enabled) {
            tokenConfigData[_collToken].enabled = true;
        }
        troveManagerPool[_troveManager] = true;
        nativeTokenTroveManager = ITroveManager(_nativeTroveManager);
        nativeTokenPriceFeed = IPriceFeed(_nativeTokenPriceFeed);
        collTokenPriceFeed = ICollTokenPriceFeed(_collTokenPriceFeed);
        collTokens.push(_collToken);
    }

    function updateCollTokenPriceFeed(ICollTokenPriceFeed _collTokenPriceFeed, IPriceFeed _nativeTokenPriceFeed) external onlyOwner {
        collTokenPriceFeed = _collTokenPriceFeed;
        nativeTokenPriceFeed = _nativeTokenPriceFeed;
    }

    function getCollTokenPriceFeed() view external returns (ICollTokenPriceFeed) {
        return collTokenPriceFeed;
    }

    function getCollTokenLpf(address _collToken, uint _totalColl) view external returns (uint) {
        uint lpr = tokenConfigData[_collToken].lpr;
        uint lpf = _totalColl.mul(lpr).div(100);
        return lpf;
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

        entireSystemColl = activeColl.add(liquidatedColl);
    }

    function getEntireSystemDebt(address _collToken) public view returns (uint entireSystemDebt) {
        address activePoolAddress = tokenConfigData[_collToken].activePool;
        address defaultPoolAddress = tokenConfigData[_collToken].defaultPool;
        uint activeDebt = IActivePool(activePoolAddress).getLUSDDebt();
        uint closedDebt = ICollTokenDefaultPool(defaultPoolAddress).getLUSDDebt();

        entireSystemDebt = activeDebt.add(closedDebt);
    }

    function getEntireSystemDebt() external view returns (uint entireSystemDebt) {
        uint totalDebt = LiquityBase(address(nativeTokenTroveManager)).getEntireSystemDebt();
        for (uint i = 0; i < collTokens.length; i++) {
            totalDebt += getEntireSystemDebt(collTokens[i]);
        }
        entireSystemDebt = totalDebt;
    }

    function getTCR(address _collToken, uint _price) public view returns (uint TCR) {
        uint entireSystemColl = getEntireSystemColl(_collToken);
        uint entireSystemDebt = getEntireSystemDebt(_collToken);

        TCR = LiquityMath._computeCR(entireSystemColl, entireSystemDebt, _price);

        return TCR;
    }

    function checkRecoveryMode(address _collToken, uint _price) external view returns (bool) {

        uint TCR = getTCR(_collToken, _price);

        return TCR < tokenConfigData[_collToken].ccr;
    }

}