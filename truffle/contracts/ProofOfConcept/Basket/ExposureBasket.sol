// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "../../Util/Strings.sol";
import "../../Util/Context.sol";
import "../../Util/IERC20.sol";
import "../../Uniswap/IPair.sol";
import "../../Uniswap/IUniswapV2Router01.sol";
import "../../Util/ERC20.sol";
import "../../Util/Ownable.sol";
import "./IExposureManager.sol";

/**
  *  @title Exposure Basket
  *  @author Exposure
  *  @notice Main point of interaction for an individual Exposure Market Basket
  *   - Users can:
  *    # Mint basket tokens/shares in exchange for underlying assets
  *    # Redeem basket tokens/shares in exchange for underlying assets
  *    # Buy underlying assets in exchange for USDC during rebalances
  *    # Sell underlying assets in exchange for USDC during rebalances
  *    # Call rebalance steps
  *  @dev All admin functions are callable by the DAO and limited by Ownable
  *  @dev Exposure basket shares are represented as ERC20 tokens
*/
contract ExposureBasket is ERC20, Ownable {

    /**
     * @dev tokenPortions is the amount of tokens one basket share represents.
     */
    mapping(uint256 => mapping(address => uint256)) private tokenPortions;

    /**
     * @dev tokenMarketCaps stores each tokens market cap for determining its weight.
     */
    mapping(uint256 => mapping(address => uint256)) private tokenMarketCaps;

    /**
     * @dev tokenPrices stores the token price to determine the amount
     * of tokens to buy and sell during a rebalance..
     */
    mapping(uint256 => mapping(address => uint256)) private tokenPrices;

    /**
     * @dev tokenBuyAmount is the target amount of tokens to buy during a rebalance.
     */
    mapping(uint256 => mapping(address => uint256)) private tokenBuyAmount;

    /**
     * @dev tokenSellAmount is the number of tokens the basket will sell for USDC during a rebalance.
     */
    mapping(uint256 => mapping(address => uint256)) private tokenSellAmount;

    /**
     * @dev tokenWeights stores the percentage of capital the basket allocated to each token.
     */
    mapping(uint256 => mapping(address => uint256)) private tokenWeights;

    /**
     * @dev bypassTrade allows a token trades to be skipped during a rebalance.
     */
    mapping(uint256 => mapping(address => bool)) private bypassTrade;

    /**
     * @dev tokens is a list of all the tokens in the basket.
     */
    mapping(uint256 => address[]) private tokens;

    /**
     * @dev rebalanceTimeStamp stores the next time a rebalance can occur.
     */
    mapping(uint256 => uint256) public rebalanceTimeStamp;

    /**
     * @dev tokenFixedWeight is an optional set percentage of the total basket a token
     * should represent. eg 2e17 = 20% of the basket.
     */
    mapping(address => uint256) public tokenFixedWeight;

    /**
     * @dev buyAndSellFromFee is the fee charged to users for trading tokens
     * directly with the basket during rebalances.
     */
    uint256 public buyAndSellFromFee;

    /**
     * @dev epoch is the number of rebalances that have occurred
     */
    uint256 public epoch;

    /**
     * @dev basketCap is the max number of basket shares that can be minted
     */
    uint256 public basketCap;

    /**
     * @dev rebalanceStep is the current step during a rebalance. If 0 the basket
     * is not currently rebalancing.
     */
    uint256 public rebalanceStep;

    /**
     * @dev The exposureManager is the middleman that talks to contracts holding
     * underlying assets and tells it to buy, sell, or transfer.
     */
    address private exposureManager;

    /**
     * @dev XPSRAddress is the XPSR governance token contract address.
     */
    address private XPSRAddress;

    mapping(address => mapping(uint256 => bool)) private hasBeenAdded;
    mapping(uint256 => address[]) private finalTokens;
    mapping(uint256 => address[]) private tokensToBuy;

    mapping(uint256 => uint256) private index;
    mapping(uint256 => uint256) private weightIndex;
    mapping(uint256 => uint256) private fixedWeight;
    mapping(uint256 => uint256) private epochPayout;
    mapping(uint256 => uint256) private feeTiers;
    mapping(address => uint256) private userFeeTier;
    mapping(uint256 => uint256) private rebalancePayoutAmounts;
    mapping(uint256 => uint256) private epochUSDBalance;

    mapping(address => bool) private tokensToRemove;
    mapping(address => bool) private canBeDirectlyTraded;

    uint256 private expenseRatio;
    uint256 private indexDivisor;
    uint256 private maxSlippage;
    uint256 private rebalanceTimer;
    uint256 public XPSRRequirement;

    address private usdc;
    address private feeContract;

    bool private isLive;

    event BasketShareExchange(address indexed from, address[] _tokens, uint256[] amounts, uint256[] fees);
    event ExpenseRatioPay(uint256 indexed amount, uint256 indexed percentage, address indexed user, address);

    /**
     * @dev Constructor.
     * @param _name The name of the ERC20 token
     * @param _symbol The symbol of the ERC20 token
     * @param _usdc The token address of USDC
     * @param _owner The admin of the basket granted access to ownerOnly functions
     * @param _XPSRAddress The contract address of the Exposure token
     * @param _exposureAssetManager The contract address of the ExposureAssetManager contract for the basket
     * @dev The ExposureAssetManager contract is the middleman for moving tokens in the basket
     * for buy, sell, mint, and redeem. Each underlying asset also has its own ExposureAsset contract
     */
    constructor (
        string memory _name,
        string memory _symbol,
        address _usdc,
        address _owner,
        address _XPSRAddress,
        address _exposureAssetManager
    )
    ERC20(_name, _symbol)
    {
        // The default 0.3% fee for mint and redeem
        feeTiers[0] = 30;

        // 0 fee for owner;
        feeTiers[2] = 0;
        userFeeTier[msg.sender] = 2;

        // The maximum number of shares that can be created
        basketCap = 100000000 * 1e18;

        // The maximum slippage amount when trading underlying assets during rebalance
        maxSlippage = 150;

        XPSRAddress = _XPSRAddress;
        XPSRRequirement = 0;

        // The fee for using functions buyFromExposure and sellToExposure
        buyAndSellFromFee = 10;

        // 1% annualized fee deducted during rebalances
        expenseRatio = 100;

        exposureManager = _exposureAssetManager;
        feeContract = msg.sender;

        usdc = _usdc;

        // Minimum time before another rebalance can occur
        rebalanceTimer = 0 hours;

        // Aggregate market caps / indexDivisor = index price
        indexDivisor = 100000000 * 1e18;

        // Percentage of the current expenseRatio payout for calling each rebalanceStep function
        rebalancePayoutAmounts[0] = 5;
        rebalancePayoutAmounts[1] = 0;
        rebalancePayoutAmounts[2] = 0;
        rebalancePayoutAmounts[3] = 20;
        rebalancePayoutAmounts[4] = 5;
        rebalancePayoutAmounts[5] = 25;
        rebalancePayoutAmounts[6] = 5;
        rebalancePayoutAmounts[7] = 20;
        rebalancePayoutAmounts[8] = 15;
        rebalancePayoutAmounts[9] = 5;
        rebalancePayoutAmounts[10] = 5;
    }

    /**
     * @notice Mints basket tokens in exchange for underlying asset. Fees are deducted via
     * basket shares. The amount is determined by `feeTiers` and `userFeeTier`.
     *
     * @param amount The number of basket tokens to mint.
     * @param to The receiver of the minted tokens.
     *
     * @dev Emits a {Transfer} event for each token.
     * @dev Emits a {BasketShareExchange} event.
     *
     * Requirements:
     *
     * - `isLive` must be true (the basket has been initialized).
     * - `rebalanceStep` must be 0 or 6.
     * - `from` must have a balance of at least `amount`.
     * - `totalSupply()` must be less than or equal to `basketCap` after minting new shares.
     * - User must approve XPSR Tokens (`XPSRAddress`) for the `XPSRRequirement`.
     */
    function mint(uint256 amount, address to) external {
        require(isLive);
        require(rebalanceStep == 0 || rebalanceStep > 6);
        require(totalSupply() + amount <= basketCap);

        if (XPSRRequirement > 0)
            IERC20(XPSRAddress).transferFrom(msg.sender, address(this), XPSRRequirement);

        uint256[] memory _amounts = new uint256[](tokens[epoch].length);
        uint256[] memory _fees = new uint256[](tokens[epoch].length);
        uint256 _fee;
        uint256 tokenAmount;
        for (uint256 i = 0; i < tokens[epoch].length; i++) {
            tokenAmount = (tokenPortions[epoch][tokens[epoch][i]] * (amount)) / 1e18;
            _fee = fee(tokenAmount, feeTiers[userFeeTier[msg.sender]]);

            IERC20(tokens[epoch][i]).transferFrom(msg.sender, address(this), tokenAmount);
            IERC20(tokens[epoch][i]).transfer(
                (IExposureManager(exposureManager).exposureAssetAddresses(tokens[epoch][i])),
                tokenAmount
            );

            _amounts[i] = tokenAmount;
            _fees[i] = _fee;
        }

        emit BasketShareExchange(to, tokens[epoch], _amounts, _fees);

        _fee = fee(amount, feeTiers[userFeeTier[msg.sender]]);
        amount -= _fee;
        _mint(to, amount);
        if (_fee > 0)
            _mint(feeContract, _fee);
    }

    /**
     * @notice Redeems basket tokens in exchange for underlying asset. Fees are deducted via
     * basket shares. The amount is determined by `feeTiers` and `userFeeTier`.
     *
     * @param amount The number of basket tokens to mint.
     * @param to The receiver of the minted tokens.
     *
     * @dev Emits a {Transfer} event for each token.
     * @dev Emits a {BasketShareExchange} event.
     *
     * @dev if the basket gets stuck in a rebalance owners of basket shares can redeem their tokens
     * based on the previous portions of each token as a failsafe
     *
     * Requirements:
     *
     * - `isLive` must be true (the basket has been initialized).
     * - `rebalanceStep` must be 0 or 7 or `basketCap` must be set to 0.
     * - `from` must have a balance of at least `amount`.
     * - `totalSupply()` must be less than or equal to `basketCap` after minting new shares.
     * - User must approve XPSR Tokens (`XPSRAddress`) for the `XPSRRequirement`.
     */
    function burn(uint256 amount, address to) external {
        require(isLive);
        require(rebalanceStep == 0 || rebalanceStep > 7 || basketCap == 0);
        if (XPSRRequirement > 0) {
            IERC20(XPSRAddress).transferFrom(msg.sender, address(this), XPSRRequirement);
        }

        uint256 _epoch = epoch;
        if (basketCap == 0) {
            if (rebalanceStep < 7 && epoch > 0) {
                _epoch = epoch - 1;
            }
        }

        uint256[] memory _amounts = new uint256[](tokens[_epoch].length);
        uint256[] memory _fees = new uint256[](tokens[_epoch].length);

        uint256 _shareFee = fee(amount, feeTiers[userFeeTier[msg.sender]]);
        uint256 newAmount = amount - _shareFee;
        _burn(to, newAmount);
        if (_shareFee > 0) {
            transferFrom(msg.sender, address(this), _shareFee);
            transfer(feeContract, _shareFee);
        }

        for (uint8 i = 0; i < tokens[_epoch].length; i++) {
            uint256 tokenAmount = (tokenPortions[_epoch][tokens[_epoch][i]] * (newAmount)) / 1e18;
            IExposureManager(exposureManager).authorizedTransfer(tokens[_epoch][i], to, tokenAmount);
            _amounts[i] = tokenAmount;
        }
        _fees[0] = _shareFee;
        emit BasketShareExchange(to, tokens[_epoch], _amounts, _fees);
    }

    /**
     * @notice Begins the next rebalance.
     * @dev `rebalanceTimeStamp[epoch]` is the minimum timestamp before the next rebalance can happen.
     * `rebalanceTimer` determines the time increment for `rebalanceTimeStamp[epoch]. If the basket is
     * initializing, the increment will start from the current block timestamp, otherwise it will start from
     * `rebalanceTimeStamp[epoch].
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 0.
     * - `block.timestamp` must be greater than `rebalanceTimeStamp` set during the last rebalance.
     */
    function startRebalance() external {
        require(rebalanceStep == 0, "Rebalance Step is not 0.");
        if (!isLive) {
            rebalanceStep = 1;
            return;
        }
        require(block.timestamp >= rebalanceTimeStamp[epoch], "rebalanceTimeStamp");

        if (epoch == 0) {
            rebalanceTimeStamp[epoch + 1] = block.timestamp + rebalanceTimer;
        } else {
            rebalanceTimeStamp[epoch + 1] = rebalanceTimeStamp[epoch] + rebalanceTimer;
            epochPayout[epoch + 1] = (block.timestamp - rebalanceTimeStamp[epoch]) * 1e18 / ((365 days)) * expenseRatio / 10000;
        }

        rebalanceStep = 3;
        epoch++;

        payoutExpenseRatio(epochPayout[epoch + 1] * rebalancePayoutAmounts[rebalanceStep] / 100);
    }

    /**
     * @notice Sets the tokens for the next rebalance.
     * @dev Can only be called before a rebalance or during `rebalanceStep` 1. The only time
     * `rebalanceStep` is equal to 1 is when the basket is initializing.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function addTokens(
        address[] memory _tokens,
        address[][] memory _tokenPairs,
        address[][] memory pairTypes,
        address[][] memory oracles,
        address[][] memory routers
    ) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            addToken(_tokens[i], _tokenPairs[i], pairTypes[i], oracles[i], routers[i]);
        }

        if (rebalanceStep == 1)
            rebalanceStep = 3;
    }

    /**
     * @notice Adds a token to the basket at the next rebalance.
     * @dev Can only be called before a rebalance or during `rebalanceStep` 1. The only time
     * `rebalanceStep` is equal to 1 is when the basket is initializing. If the `hasBeenAdded[_token][_epoch]
     * is true, it will return to prevent duplicate tokens in the basket.
     *
     * @dev if a token has been set to be removed from the basket but was is an argument in addToken, it
     * remove it from the queue to be removed.
     *
     * @dev Creates a new ExposureAsset contract through the `exposureAssetManager` contract.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     * - `rebalanceStep` must be 1 or 0.
     */
    function addToken(
        address _token,
        address[] memory
        _tokenPairs,
        address[] memory pairTypes,
        address[] memory oracles,
        address[] memory routers
    ) public onlyOwner {
        require(rebalanceStep == 0 || rebalanceStep == 1, "Rebalance Step is not 0.");

        if (hasBeenAdded[_token][epoch])
            return;

        tokens[epoch].push(_token);
        tokensToRemove[_token] = false;
        hasBeenAdded[_token][epoch] = true;
        canBeDirectlyTraded[_token] = true;

        IExposureManager(exposureManager).batchNewAssetManager(_token, _tokenPairs, pairTypes, oracles, routers);
    }

    /**
     * @notice Removes an array of token from the basket during the next rebalance.
     * @dev Can be undone by calling `addToken`.
     *
     * @dev If the token had a fixed weight in the basket, that weight gets set to 0.
     *
     * Requirements:
     *
     * - Caller must be the owner.
     * - `rebalanceStep` must 0.
     */
    function removeTokens(address[] memory _tokens) external onlyOwner {
        require(rebalanceStep == 0, "Rebalance Step is not 0.");

        for (uint256 i = 0; i < _tokens.length; i++) {
            tokenSellAmount[epoch + 1][_tokens[i]] = IExposureManager(exposureManager).getBalance(_tokens[i]);
            tokensToRemove[_tokens[i]] = true;
            tokenFixedWeight[_tokens[i]] = 0;
        }
    }

    /**
     * @notice Sets the marketcap and price of each token in the basket for calculating weights
     * @dev if addTokens wasn't called prior to the current rebalance, all of the previous
     * tokens are copied over to the next epoch.
     *
     * Requirements:
     *
     * - `rebalanceStep` must 3.
     */
    function updateTokenMarketCap() external {
        require(rebalanceStep == 3, "Rebalance Step is not 3.");

        if (tokens[epoch].length == 0 && epoch > 0) {
            for (uint256 i = 0; i < tokens[epoch - 1].length; i++) {
                hasBeenAdded[tokens[epoch - 1][i]][epoch] = true;
                tokens[epoch].push(tokens[epoch - 1][i]);
            }
        }

        for (uint256 i = 0; i < tokens[epoch].length; i++) {
            tokenMarketCaps[epoch][tokens[epoch][i]] = IExposureManager(exposureManager).getMarketCap(tokens[epoch][i]);
            updateTokenPrice(tokens[epoch][i]);
        }


        ///////////

        uint256 indexForWeight = 0;
        uint256 _fixedWeight = 0;
        for (uint256 i = 0; i < tokens[epoch].length; i++) {
            if (tokensToRemove[tokens[epoch][i]] || tokenFixedWeight[tokens[epoch][i]] == 0)
                continue;

            _fixedWeight += tokenFixedWeight[tokens[epoch][i]];
        }

        for (uint256 i = 0; i < tokens[epoch].length; i++) {
            if (tokensToRemove[tokens[epoch][i]] || tokenFixedWeight[tokens[epoch][i]] != 0)
                continue;

            indexForWeight += tokenMarketCaps[epoch][tokens[epoch][i]];
        }

        weightIndex[epoch] = indexForWeight;
        fixedWeight[epoch] = _fixedWeight;

        rebalanceStep = 5;
        payoutExpenseRatio(epochPayout[epoch] * rebalancePayoutAmounts[rebalanceStep] / 100);
    }

    function updateTokenPortions() public {
        require(rebalanceStep == 5, "Rebalance Step is not 5.");

        for (uint i = 0; i < tokens[epoch].length; i++) {
            if (tokensToRemove[tokens[epoch][i]]) {
                continue;
            }

            uint256 startIndex = weightIndex[epoch];
            uint256 indexForWeight = weightIndex[epoch];
            address _token = tokens[epoch][i];

            updateTokenPrice(_token);

            if (epoch > 0) {
                uint256 nav_index = 0;
                uint256 token_price_usd;
                for (uint256 i = 0; i < tokens[epoch - 1].length; i++) {
                    token_price_usd = tokenPrices[epoch - 1][tokens[epoch - 1][i]];
                    nav_index += (((token_price_usd) * (tokenPortions[epoch - 1][tokens[epoch - 1][i]])) * indexDivisor / 1e36);
                }

                startIndex = nav_index;
            }

            uint256 indexDivised = ((startIndex * 1e18) / indexDivisor);
            uint256 indexPortionForFixed = indexDivised * fixedWeight[epoch] / 1e18;
            uint256 indexPortionForMCAP = indexDivised - indexPortionForFixed;
            uint256 tokenWeight = ((tokenMarketCaps[epoch][_token] * 1e18) / indexForWeight);
            uint256 tokenPortion = (((((indexPortionForMCAP) * tokenWeight))) / (tokenPrices[epoch][_token]));

            if (tokenFixedWeight[tokens[epoch][i]] != 0) {
                tokenWeight = (tokenFixedWeight[tokens[epoch][i]] * 1e18) / fixedWeight[epoch];
                tokenPortion = (((((indexPortionForFixed) * tokenWeight))) / (tokenPrices[epoch][_token]));
            }

            tokenPortions[epoch][_token] = tokenPortion;
            tokenWeights[epoch][_token] = tokenWeight;

            if (epoch > 0) {
                if (tokenPortions[epoch - 1][_token] <= tokenPortions[epoch][_token])
                {
                    uint256 amount = (tokenPortions[epoch][_token] - tokenPortions[epoch - 1][_token]);
                    uint256 total_amount = (amount * totalSupply()) / 1e18;
                    tokensToBuy[epoch].push(_token);
                    tokenBuyAmount[epoch][_token] = total_amount - ((total_amount * maxSlippage) / 10000);
                }
            }
            payoutExpenseRatio(epochPayout[epoch] * rebalancePayoutAmounts[rebalanceStep] / 100);
        }
        rebalanceStep = 6;
    }

    /**
     * @notice Extension of `updateTokenPortions`.
     * @dev If `rebalanceStep` is 0 there are now shares and `isLive` is false.
     * The basket will skip the next 2 steps which trade underlying assets in the basket.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 6.
     */
    function updateRemainingPortions() external {
        require(rebalanceStep == 6, "Rebalance Step is not 6.");

        if (!isLive) {
            rebalanceStep = 9;
            return;
        }

        uint256 amountToBuy;
        uint256 extraPortionToSell;
        for (uint256 i = 0; i < tokensToBuy[epoch].length; i++) {
            amountToBuy = tokenBuyAmount[epoch][tokensToBuy[epoch][i]];

            for (uint256 j = 0; j < tokens[epoch].length; j++) {
                if (tokenFixedWeight[tokens[epoch][i]] != 0)
                    continue;

                updateTokenPrice(tokens[epoch][j]);
                extraPortionToSell = ((((amountToBuy) * tokenWeights[epoch][tokens[epoch][j]]) * (tokenPrices[epoch][tokensToBuy[epoch][i]])) / 1e18) / tokenPrices[epoch][tokens[epoch][j]];
                extraPortionToSell = extraPortionToSell - ((extraPortionToSell * 5) / 10000);

                if (tokensToBuy[epoch][i] == tokens[epoch][j]) {
                    tokenBuyAmount[epoch][tokensToBuy[epoch][i]] = amountToBuy - extraPortionToSell;
                } else if (IExposureManager(exposureManager).getBalance(tokens[epoch][j]) > extraPortionToSell) {
                    tokenSellAmount[epoch][tokens[epoch][j]] += extraPortionToSell;
                }
            }
        }
        rebalanceStep = 7;
        payoutExpenseRatio(epochPayout[epoch] * rebalancePayoutAmounts[rebalanceStep] / 100);
    }

    /**
     * @notice Allows users to buy tokens from the basket at the price that was
     * stored in `updateTokenMarketCap()`. Users are free to arbitrage the price difference between an exchange
     * and the basket while also paying a low 0.1% fee to transact with the basket. The user must approve USDC.
     * @dev The basket will never buy tokens before it has already sold all of the tokens in `tokenSellAmount[epoch][_token]`.
     *
     * @param amount The number of tokens to buy.
     * @param _token The token address of the token the caller wants to buy.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 7.
     * - `canBeDirectlyTraded[_token]` must be set to true.
     */
    function buyFromExposure(uint256 amount, address _token) external {
        require(rebalanceStep == 7, "Rebalance Step is not 7.");
        require(canBeDirectlyTraded[_token], "ExposureBasket: Token unauthorized");

        uint256 percentageBuying = amount * 1e18 / tokenSellAmount[epoch][_token];
        require(percentageBuying + IExposureManager(exposureManager).getAmountSold(_token, epoch) <= 1e18);

        IERC20(usdc).transferFrom(msg.sender, address(this), amount * tokenPrices[epoch][_token] / 1e18);
        IERC20(usdc).transfer(exposureManager, amount * tokenPrices[epoch][_token] / 1e18);

        uint256 _fee = fee(amount, buyAndSellFromFee);
        if (_fee != 0) {
            IExposureManager(exposureManager).authorizedTransfer(_token, msg.sender, amount - _fee);
            IExposureManager(exposureManager).authorizedTransfer(_token, feeContract, _fee);
        } else {
            IExposureManager(exposureManager).authorizedTransfer(_token, msg.sender, amount);
        }

        IExposureManager(exposureManager).increaseAmountTraded(1, epoch, _token, percentageBuying);
    }

    /**
     * @notice Allows users to sell tokens to the basket at the price that was
     * stored in `updateTokenMarketCap()`. Users are free to arbitrage the price difference between an exchange
     * and the basket while also paying a low 0.1% fee to transact with the basket. The user will receive USDC.
     * @dev The basket will never buy tokens before it has already sold all of the tokens in `tokenSellAmount[epoch][_token]`.
     *
     * @param amount The number of tokens to buy.
     * @param _token The token address of the token the caller wants to buy.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 7.
     * - `canBeDirectlyTraded[_token]` must be set to true.
     */
    function sellToExposure(uint256 amount, address _token) external {
        require(rebalanceStep == 8, "Rebalance Step is not 8.");
        require(canBeDirectlyTraded[_token], "ExposureBasket: Token unauthorized");

        uint256 percentageBuying = amount * 1e18 / tokenBuyAmount[epoch][_token];
        require(percentageBuying + IExposureManager(exposureManager).getAmountBought(_token, epoch) <= 1e18);

        IERC20(_token).transferFrom(msg.sender, address(this), amount);
        IERC20(_token).transfer(IExposureManager(exposureManager).exposureAssetAddresses(_token), amount);

        uint256 _fee = fee(amount * tokenPrices[epoch][_token] / 1e18, buyAndSellFromFee);
        if (_fee != 0) {
            IExposureManager(exposureManager).getUSDC((amount * tokenPrices[epoch][_token] / 1e18) - _fee, msg.sender);
            IExposureManager(exposureManager).getUSDC(_fee, feeContract);
        } else {
            IExposureManager(exposureManager).getUSDC((amount * tokenPrices[epoch][_token] / 1e18), msg.sender);
        }

        IExposureManager(exposureManager).increaseAmountTraded(0, epoch, _token, percentageBuying);
    }

    /**
     * @notice `owner()` can sell off a percentage of `tokenSellAmount[epoch][_token]` through the
     * ExposureAssetManager contract.
     * @dev The basket will never buy tokens before it has already sold all of the tokens in `tokenSellAmount[epoch][_token]`.
     *
     * @param percentage The percentage of tokenSellAmount[epoch][_token], the ExposureAssetManager should sell.
     * @param _token The token address of the token the caller wants to buy.
     *
     * @dev If `tokenSellAmount[epoch][_token]` is < 1000 the basket will skip the trade
     * due to the size being too small.
     * Requirements:
     *
     * - `rebalanceStep` must be 7.
     * - The caller must be the owner.
     */
    function rebaseLiquidateIndividual(uint256 percentage, address _token) external onlyOwner {
        require(rebalanceStep == 7, "Rebalance Step is not 7.");

        if (tokenSellAmount[epoch][_token] >= 1000)
            tokenPortions[epoch][_token] = IExposureManager(exposureManager).liquidate(_token, percentage, tokenSellAmount[epoch][_token], maxSlippage, epoch);
    }

    /**
     * @notice `owner()` can buy a percentage of the tokens it needs based off its weight and the
     * total USDC received during `rebaseLiquidate`, `rebaseLiquidateIndividual`, and `buyFromExposure`.
     * @dev The basket will never buy tokens before it has already sold all of the tokens in `tokenSellAmount[epoch][_token]`.
     *
     * @param percentage The percentage of calculated buy amount the ExposureAssetManager should buy.
     * @param _token The token address of the token the caller wants to buy.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 8.
     * - The caller must be the owner.
     */
    function rebaseBuyIndividual(uint256 percentage, address _token) external onlyOwner {
        require(rebalanceStep == 8, "Rebalance Step is not 8.");

        uint256 total_weight = 0;
        for (uint256 i = 0; i < tokensToBuy[epoch].length; i++) {
            total_weight += tokenWeights[epoch][tokensToBuy[epoch][i]];
        }

        if (tokenBuyAmount[epoch][_token] >= 1000 && !(tokensToRemove[_token]))
            tokenPortions[epoch][_token] = IExposureManager(exposureManager).purchase(
                _token,
                percentage,
                tokenWeights[epoch][_token],
                total_weight,
                epochUSDBalance[epoch],
                maxSlippage,
                epoch
            );
    }

    /**
     * @notice `owner()` can sell off a the remaining percentage of each `tokenSellAmount[epoch][_token]`
     * through the ExposureAssetManager contract.
     * @dev The basket will never buy tokens before it has already sold all of the tokens
     * in `tokenSellAmount[epoch][_token]` unless a token has bypassTrade[epoch][tokens[epoch][i]] set to true.
     *
     * @dev If `tokenSellAmount[epoch][_token]` is < 1000 the basket will skip the trade
     * due to the size being too small.
     * Requirements:
     *
     * - `rebalanceStep` must be 7.
     * - The caller must be the owner.
     */
    function rebaseLiquidate() external onlyOwner {
        require(rebalanceStep == 7, "Rebalance Step is not 7.");
        for (uint256 i = 0; i < tokens[epoch].length; i++) {
            if (tokenSellAmount[epoch][tokens[epoch][i]] >= 1000 && !bypassTrade[epoch][tokens[epoch][i]]) {
                tokenPortions[epoch][tokens[epoch][i]] = IExposureManager(exposureManager).liquidate(
                    tokens[epoch][i], 1e18,
                    tokenSellAmount[epoch][tokens[epoch][i]],
                    maxSlippage,
                    epoch
                );
            }
        }

        epochUSDBalance[epoch] = IERC20(usdc).balanceOf(exposureManager);

        rebalanceStep = 8;
        payoutExpenseRatio(epochPayout[epoch] * rebalancePayoutAmounts[rebalanceStep] / 100);
    }

    /**
     * @notice `owner()` can buy  the remaining percentage of each token with
     * the remaining USDC balance in the ExposureAssetManager.
     *
     * @dev If `tokenBuyAmount[epoch][tokens[epoch][i]]` is < 1000 the basket will skip the trade
     * due to the size being too small.
     * Requirements:
     *
     * - `rebalanceStep` must be 8.
     * - The caller must be the owner.
     */
    function rebaseBuy() external onlyOwner {
        require(rebalanceStep == 8, "Rebalance Step is not 8.");

        uint256 total_weight = 0;
        for (uint256 i = 0; i < tokensToBuy[epoch].length; i++) {
            total_weight += tokenWeights[epoch][tokensToBuy[epoch][i]];
        }

        for (uint256 i = 0; i < tokens[epoch].length; i++) {
            if (tokenBuyAmount[epoch][tokens[epoch][i]] >= 1000
                && (!bypassTrade[epoch][tokens[epoch][i]] || !tokensToRemove[tokens[epoch][i]])) {
                tokenPortions[epoch][tokens[epoch][i]] = IExposureManager(exposureManager).purchase(
                    tokens[epoch][i],
                    1e18,
                    tokenWeights[epoch][tokens[epoch][i]],
                    total_weight,
                    epochUSDBalance[epoch],
                    maxSlippage,
                    epoch
                );
            }
        }

        rebalanceStep = 9;
        payoutExpenseRatio(epochPayout[epoch] * rebalancePayoutAmounts[rebalanceStep] / 100);
    }

    /**
        * @notice Allows users to increment `rebalanceStep` if 99.9% of tokenSellAmount[epoch] was traded
        * for all required tokens.
        *
        * Requirements:
        *
        * - `rebalanceStep` must be 7.
        */
    function finishLiquidate() external {
        require(rebalanceStep == 7, "Rebalance Step is not 7.");

        for (uint256 i = 0; i < tokens[epoch].length; i++) {
            if (tokenSellAmount[epoch][tokens[epoch][i]] >= 1000 && !bypassTrade[epoch][tokens[epoch][i]]) {
                if (IExposureManager(exposureManager).getAmountSold(tokens[epoch][i], epoch) > 999 * 1e15)
                    return;
            }
        }
        rebalanceStep = 8;
    }

    /**
     * @notice Allows users to increment `rebalanceStep` if the USDC balance is less than 10.
     *
     * Requirements:
     *
     * - `rebalanceStep` must be 8.
     */
    function finishBuy() external {
        require(rebalanceStep == 8, "Rebalance Step is not 8.");

        if (IERC20(usdc).balanceOf(exposureManager) <= 10 * (10 ** (IERC20Metadata(usdc).decimals()))) {
            rebalanceStep = 9;
            return;
        }
    }

    /**
     * @notice Sets the index price of the new epoch.
     * @dev resets tokensToRemove
     *
     * @dev sets `tokens` for the new epoch.
     * Requirements:
     *
     * - `rebalanceStep` must be 9.
     */
    function finalizeIndexPrice() external {
        require(rebalanceStep == 9, "Rebalance Step is not 9.");

        uint256 indexSum = 0;
        for (uint256 i = 0; i < tokens[epoch].length; i++) {
            if (totalSupply() > 0 && tokensToRemove[tokens[epoch][i]]) {
                tokensToRemove[tokens[epoch][i]] = false;
                continue;
            }
            finalTokens[epoch].push(tokens[epoch][i]);
        }

        tokens[epoch] = finalTokens[epoch];

        uint256 tokenPrice;
        uint256 tokenPortion;
        uint256 tokenMCAPPortion;
        for (uint256 i = 0; i < tokens[epoch].length; i++) {
            tokenPrice = tokenPrices[epoch][tokens[epoch][i]];
            tokenPortion = tokenPortions[epoch][tokens[epoch][i]];

            if (tokenPrice > tokenPortion) {
                tokenMCAPPortion = tokenPortion * (tokenPrice / 1e18);
            } else {
                tokenMCAPPortion = tokenPrice * (tokenPortion / 1e18);
            }
            indexSum += tokenMCAPPortion;
        }

        index[epoch] = (indexSum * indexDivisor) / 1e18;
        rebalanceStep = 10;
        payoutExpenseRatio(epochPayout[epoch] * rebalancePayoutAmounts[rebalanceStep] / 100);

        if (!isLive) {
            isLive = true;
        }
        rebalanceStep = 0;
    }

    /**
     * @notice Sets the fixed weight of a basket token.
     * @dev if `_weight` is 0 then the weight will be based on market cap.
     *
     * @dev percentage is based on 1e18.
     * Requirements:
     *
     * - Caller must be the owner.
     * - The total fixed weight must be less than 1e18.
     * - The number of fixed weight tokens must be less than the total number of tokens.
     */
    function setFixedTokenWeight(address _token, uint256 _weight) external onlyOwner {
        require(_weight <= 1e18);

        uint256 _fixedWeight = 0;
        uint256 _numberOfFixedWeightTokens = 0;
        for (uint256 i = 0; i < tokens[epoch].length; i++) {
            if (tokensToRemove[tokens[epoch][i]] || tokenFixedWeight[tokens[epoch][i]] == 0)
                continue;
            _numberOfFixedWeightTokens++;
            _fixedWeight += tokenFixedWeight[tokens[epoch][i]];
        }
        require(_fixedWeight <= 1e18);
        require(_numberOfFixedWeightTokens < tokens[epoch].length);
        tokenFixedWeight[_token] = _weight;
    }

    /**
     * @notice Sets `XPSRAddress`.
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function setXPSRAddress(address _token) external onlyOwner {
        XPSRAddress = _token;
    }

    /**
     * @notice Sets `canBeDirectlyTraded` for a token.
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function setToBeDirectlyTraded(address _token, bool _value) external onlyOwner {
        canBeDirectlyTraded[_token] = _value;
    }

    /**
     * @notice Sets `rebalanceTimer`.
     * @dev This is the minimum time between rebalances.
     * Requirements:
     *
     * - Caller must be the owner.
     */
    function setRebalanceTimer(uint256 _hours) external onlyOwner {
        rebalanceTimer = _hours * (1 hours);
    }

    /**
    * @notice Sets the fee for a user group.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setFeeTier(uint256 tier, uint256 _fee) external onlyOwner {
        feeTiers[tier] = _fee;
    }

    /**
    * @notice Sets a users fee tier.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setUserFeeTier(uint256 tier, address _user) external onlyOwner {
        userFeeTier[_user] = tier;
    }

    /**
    * @notice Sets the max supply of basket shares.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setBasketCap(uint256 _cap) external onlyOwner {
        basketCap = _cap;
    }

    /**
    * @notice Sets `maxSlippage`.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setMaxSlippage(uint256 _slippageFactor) external onlyOwner {
        maxSlippage = _slippageFactor;
    }

    /**
    * @notice Sets `expenseRatio`.
    * Requirements:
    *
    * - Caller must be the owner.
    * - The expense ratio must be under 500 (5%).
    */
    function changeExpenseRatio(uint256 _expenseRatio) external onlyOwner {
        require(_expenseRatio <= 500);
        expenseRatio = _expenseRatio;
    }

    /**
    * @notice Sets `XPSRRequirement` for minting and redeeming basket shares.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setXPSRRequirement(uint256 _req) external onlyOwner {
        XPSRRequirement = _req;
    }

    /**
    * @notice Sets `buyAndSellFromFee` for trading directly with the basket during rebalances.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function setBuyAndSellFromFee(uint256 _fee) external onlyOwner {
        buyAndSellFromFee = _fee;
    }

    /**
    * @notice Allows the basket to skip a token trade during a rebalance.
    * Requirements:
    *
    * - Caller must be the owner.
    */
    function addBypassTrade(address _token) external onlyOwner {
        bypassTrade[epoch][_token] = true;
    }

    function getTokenMarketCap(uint256 _epoch, address _token) external view returns (uint256){
        return tokenMarketCaps[_epoch][_token];
    }

    function getTokenPortions(uint256 _epoch, address _token) external view returns (uint256){
        return tokenPortions[_epoch][_token];
    }

    function getTokenPrice(uint256 _epoch, address _token) external view returns (uint256){
        return tokenPrices[_epoch][_token];
    }

    function getTokenBuyAmount(uint256 _epoch, address _token) external view returns (uint256){
        return tokenBuyAmount[_epoch][_token];
    }

    function getTokenSellAmount(uint256 _epoch, address _token) external view returns (uint256){
        return tokenSellAmount[_epoch][_token];
    }

    function getTokens(uint256 _epoch, uint256 _index) external view returns (address) {
        return tokens[_epoch][_index];
    }

    function updateTokenPrice(address _token) private {
        tokenPrices[epoch][_token] = IExposureManager(exposureManager).getPrice(_token);
    }

    /**
    * @notice Pays out the expense ratio during rebalances.
    * @dev The amount paid is the annualized expense ratio.
    * eg if the expense ratio is 1% and the rebalance happened after 1 week
    * the total payout during the rebalance will be 0.01923%
    *
    * @dev Emits a {Transfer} event for each token.
    * @dev Emits a {ExpenseRatioPay} event.
    *
    * @param percentage Percentage of the expense ratio to pay out (each function gets a percentage).
    */
    function payoutExpenseRatio(uint256 percentage) private {
        if (epoch == 0 || msg.sender == feeContract)
            return;

        uint256 percentageToPay = (expenseRatio * 1e18 / 10000) * percentage / 1e18;
        uint256 _epochPayout = epoch - 1;

        if (rebalanceStep > 1)
            _epochPayout = epoch;

        uint256 amountToTransfer;
        for (uint256 i = 0; i < tokens[_epochPayout].length; i++) {
            amountToTransfer = IExposureManager(exposureManager).getBalance(tokens[_epochPayout][i]) * percentageToPay / 1e18;
            if (amountToTransfer > 0) {
                IExposureManager(exposureManager).authorizedTransfer(tokens[_epochPayout][i], msg.sender, amountToTransfer);
                emit ExpenseRatioPay(amountToTransfer, percentage, msg.sender, tokens[_epochPayout][i]);
            }
        }
    }

    /**
    * @notice Calculates the NAV for determining portions during rebalances.
    * Requirements:
    *
    * - Epoch must be greater than 0.
    */
//    function calculateNAV(uint256 _epoch) private view returns (uint256) {
//        require(epoch > 0);
//
//        uint256 nav_index = 0;
//        uint256 token_price_usd;
//        for (uint256 i = 0; i < tokens[_epoch].length; i++) {
//            token_price_usd = tokenPrices[epoch][tokens[_epoch][i]];
//            nav_index += (((token_price_usd) * (tokenPortions[_epoch][tokens[_epoch][i]])) * indexDivisor / 1e36);
//        }
//
//        return nav_index;
//    }

    /**
    * @notice Calculates the fees paid for numerous functions.
    */
    function fee(uint256 _value, uint256 feeType) private pure returns (uint256) {
        if (_value == 0)
            return 0;

        return (_value * (feeType)) / (10000);
    }
}
