// SPDX-License-Identifier: AGPL-3.0
// Feel free to change the license, but this is what we use

// Feel free to change this version of Solidity. We support >=0.6.0 <0.7.0;
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// These are the core Yearn libraries
import {
    BaseStrategy,
    StrategyParams
} from "@yearnvaults/contracts/BaseStrategy.sol";
import {
    SafeERC20,
    SafeMath,
    IERC20,
    Address
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

// Import interfaces for many popular DeFi projects, or add your own!
import "../interfaces/ITokenSwap.sol";
import "../interfaces/IPProtocol.sol";

contract Strategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    ITokenSwap public tokenSwap;
    IPProtocol public pProtocol;
    IERC20 public rewardsToken;

    constructor(address _vault, address _tokenSwap, address _pProtocol, address _rewardsToken) public BaseStrategy(_vault) {
        tokenSwap = ITokenSwap(_tokenSwap);
        pProtocol = IPProtocol(_pProtocol);
        rewardsToken = IERC20(_rewardsToken);

        // You can set these parameters on deployment to whatever you want
        // maxReportDelay = 6300;
        // profitFactor = 100;
        // debtThreshold = 0;
    }

    // ******** OVERRIDE THESE METHODS FROM BASE CONTRACT ************

    function name() external view override returns (string memory) {
        return "StrategyPProtocolDai";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        // estimate rewards swapped to want
        uint256 earnedTokens = pProtocol.earned(address(this));
        uint256 earnedInWantEstimate = tokenSwap.estimateSwap(earnedTokens);

        // want staked in protocol
        uint256 stakedWant = pProtocol.getBalance(address(this));

        // current want balance of strategy 
        uint256 want = want.balanceOf(address(this));

        return earnedInWantEstimate + stakedWant + want;
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        // get rewards and swap to want tokens
        pProtocol.getReward();
        tokenSwap.swapPRewTokenToDai(rewardsToken.balanceOf(address(this)));

        if (want.balanceOf(address(this)) < _debtOutstanding) {
            uint256 wantBalance = pProtocol.getBalance(address(this));
            pProtocol.withdraw(wantBalance);
        }
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        // get rewards and swap to want tokens
        pProtocol.getReward();
        tokenSwap.swapPRewTokenToDai(rewardsToken.balanceOf(address(this)));

        pProtocol.stake(_debtOutstanding + want.balanceOf(address(this)));
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        // get rewards and swap to want tokens
        pProtocol.getReward();
        tokenSwap.swapPRewTokenToDai(rewardsToken.balanceOf(address(this)));

        uint256 availableWant = want.balanceOf(address(this));

        // check if enough funds to liquidate, else withdraw from protocol
        if (availableWant < _amountNeeded) {
            uint256 stakedWantBalance = pProtocol.getBalance(address(this));
            // withdraw the difference or all want from protocol
            if (availableWant + stakedWantBalance > _amountNeeded) {
                pProtocol.withdraw(availableWant + stakedWantBalance - _amountNeeded);
            } else {
                pProtocol.withdraw(stakedWantBalance);
            }
        }

        uint256 totalAssets = want.balanceOf(address(this));
        if (_amountNeeded > totalAssets) {
            _liquidatedAmount = totalAssets;
            _loss = _amountNeeded.sub(totalAssets);
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    function liquidateAllPositions() internal override returns (uint256) {
        // withdraw want tokens from protocol
        uint256 wantBalance = pProtocol.getBalance(address(this));
        pProtocol.withdraw(wantBalance);

        // withdraw reward tokens from protocol and swap to want tokens
        pProtocol.getReward();
        tokenSwap.swapPRewTokenToDai(rewardsToken.balanceOf(address(this)));

        return want.balanceOf(address(this));
    }

    // NOTE: Can override `tendTrigger` and `harvestTrigger` if necessary

    function prepareMigration(address _newStrategy) internal override {
        liquidateAllPositions();
    }

    // Override this to add all tokens/tokenized positions this contract manages
    // on a *persistent* basis (e.g. not just for swapping back to want ephemerally)
    // NOTE: Do *not* include `want`, already included in `sweep` below
    //
    // Example:
    //
    //    function protectedTokens() internal override view returns (address[] memory) {
    //      address[] memory protected = new address[](3);
    //      protected[0] = tokenA;
    //      protected[1] = tokenB;
    //      protected[2] = tokenC;
    //      return protected;
    //    }
    function protectedTokens()
        internal
        view
        override
        returns (address[] memory)
    {}

    /**
     * @notice
     *  Provide an accurate conversion from `_amtInWei` (denominated in wei)
     *  to `want` (using the native decimal characteristics of `want`).
     * @dev
     *  Care must be taken when working with decimals to assure that the conversion
     *  is compatible. As an example:
     *
     *      given 1e17 wei (0.1 ETH) as input, and want is USDC (6 decimals),
     *      with USDC/ETH = 1800, this should give back 1800000000 (180 USDC)
     *
     * @param _amtInWei The amount (in wei/1e-18 ETH) to convert to `want`
     * @return The amount in `want` of `_amtInEth` converted to `want`
     **/
    function ethToWant(uint256 _amtInWei)
        public
        view
        virtual
        override
        returns (uint256)
    {
        // TODO create an accurate price oracle
        return _amtInWei;
    }
}
