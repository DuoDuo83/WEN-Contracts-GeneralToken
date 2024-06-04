// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";
import "./CheckContract.sol";
import "./LiquityMath.sol";
import "../Interfaces/ICollTokenPriceFeed.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/ICollTokenDefaultPool.sol";
import "../Interfaces/ITroveManager.sol";
import "../Interfaces/ICollSurplusPool.sol";
import "../Interfaces/IActivePool.sol";

contract SysConfig is Ownable, CheckContract {
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
    }

    mapping (address => ConfigData) public tokenConfigData;
    mapping (address => bool) public troveManagerPool;
    ITroveManager public nativeTokenTroveManager;

    ICollTokenPriceFeed private collTokenPriceFeed;
    IPriceFeed private nativeTokenPriceFeed;

    ICollTokenDefaultPool private collTokenDefaultPool;
    IActivePool private activePool;

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
    }

    function configData(address _collToken) view external returns (ConfigData memory) {
        return tokenConfigData[_collToken];
    }

    function updateCollTokenPriceFeed(ICollTokenPriceFeed _collTokenPriceFeed) external onlyOwner {
        collTokenPriceFeed = _collTokenPriceFeed;
    }

    function getCollTokenPriceFeed() view external returns (ICollTokenPriceFeed) {
        return collTokenPriceFeed;
    }

    function getCollTokenCCR(address _collToken) view external returns (uint) {
        return tokenConfigData[_collToken].ccr;
    }

    function getCollTokenMCR(address _collToken) view external returns (uint) {
        return tokenConfigData[_collToken].mcr;
    }

    function getCollTokenSurplusPool(address _collToken) view external returns (ICollSurplusPool) {
        return ICollSurplusPool(tokenConfigData[_collToken].surplusPool);
    }

    function updateCollTokenDefaultPool(ICollTokenDefaultPool _collTokenDefaultPool) external onlyOwner {
        collTokenDefaultPool = _collTokenDefaultPool;
    }

    function getCollTokenDefaultPool() view external returns (ICollTokenDefaultPool) {
        return collTokenDefaultPool;
    }

    function getCollTokenTroveManagerAddress(address _collToken) view external returns (address) {
        return tokenConfigData[_collToken].troveManager;
    }

    function getCollTokenSortedTrovesAddress(address _collToken) view external returns (address) {
        return tokenConfigData[_collToken].sortedTroves;
    }

    function getEntireSystemColl(address _collToken) public view returns (uint entireSystemColl) {
        uint activeColl = activePool.getTokenCollateral(_collToken);
        uint liquidatedColl = collTokenDefaultPool.getTokenCollateral(_collToken);

        return activeColl.add(liquidatedColl);
    }

    function getEntireSystemDebt(address _collToken) public view returns (uint entireSystemDebt) {
        uint activeDebt = activePool.getTokenStableDebt(_collToken);
        uint closedDebt = collTokenDefaultPool.getTokenStableDebt(_collToken);

        return activeDebt.add(closedDebt);
    }

    function _getTCR(address _collToken, uint _price) public view returns (uint TCR) {
        uint entireSystemColl = getEntireSystemColl(_collToken);
        uint entireSystemDebt = getEntireSystemDebt(_collToken);

        TCR = LiquityMath._computeCR(entireSystemColl, entireSystemDebt, _price);

        return TCR;
    }

    function _checkRecoveryMode(address _collToken, uint _price) external view returns (bool) {

        uint TCR = _getTCR(_collToken, _price);

        return TCR < CCR;
    }

}