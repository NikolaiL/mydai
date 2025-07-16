//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
}

/**
 * A smart contract that takes ETH and sends back DAI swapping it using uniswap v2
 */
contract YourContract is Ownable, Pausable {
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address private constant DAI_USD_PAIR = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
    address private constant ETH_USD_PAIR = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    AggregatorV3Interface ethUsdPriceFeed;
    AggregatorV3Interface daiUsdPriceFeed;

    IUniswapV2Router private router;

    constructor(address _owner) Ownable(_owner) {
        router = IUniswapV2Router(UNISWAP_V2_ROUTER);
        ethUsdPriceFeed = AggregatorV3Interface(ETH_USD_PAIR);
        daiUsdPriceFeed = AggregatorV3Interface(DAI_USD_PAIR);
    }

    /**
     * Function that allows the owner to withdraw all the Ether in the contract
     * The function can only be called by the owner of the contract as defined by the isOwner modifier
     */
    function withdraw() public onlyOwner {
        (bool success, ) = payable(owner()).call{ value: address(this).balance }("");
        require(success, "Failed to send Ether");
    }

    function getEthToDaiPrice() public view returns (uint) {
        (, int ethUsd, , , ) = ethUsdPriceFeed.latestRoundData();
        (, int daiUsd, , , ) = daiUsdPriceFeed.latestRoundData();
        return (uint(ethUsd) * 1e18) / uint(daiUsd);
    }

    function getEthToUsdPrice() public view returns (uint) {
        (, int ethUsd, , , ) = ethUsdPriceFeed.latestRoundData();
        return uint(ethUsd);
    }

    function getDaiToUsdPrice() public view returns (uint) {
        (, int daiUsd, , , ) = daiUsdPriceFeed.latestRoundData();
        return uint(daiUsd);
    }

    function swapEthToDai() public payable whenNotPaused {
        require(msg.value > 0, "Send ETH to swap");

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;

        uint slippage = 50; // 0.5%
        uint multiplier = 10000; // 100%
        uint deadline = block.timestamp + 300; // 5 minutes

        uint amountOutMin = getEthToDaiPrice() * msg.value * (multiplier - slippage) / multiplier / 1e18;

        router.swapExactETHForTokens{ value: msg.value }(
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // Allow contract to receive ETH
    receive() external payable {
        if (msg.value > 0) {
            swapEthToDai();
        }
    }
}
