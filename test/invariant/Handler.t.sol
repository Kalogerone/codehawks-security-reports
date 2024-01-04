// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";

contract Handler is StdInvariant, Test {
    ERC20Mock poolToken;
    ERC20Mock weth;

    address lp = makeAddr("lp");
    address swapper = makeAddr("swapper");
    TSwapPool pool;

    int256 startingY;
    int256 startingX;
    int256 expectedDeltaY;
    int256 expectedDeltaX;

    int256 actualDeltaY;
    int256 actualDeltaX;

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(pool.getWeth());
        poolToken = ERC20Mock(pool.getPoolToken());
    }

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWeth) public {
        outputWeth = bound(outputWeth, 0, type(uint64).max);
        if (outputWeth >= weth.balanceOf(address(pool))) {
            return;
        }
        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
            outputWeth, poolToken.balanceOf(address(pool)), weth.balanceOf(address(pool))
        );
        if (poolTokenAmount > type(uint64).max) {
            return;
        }

        startingY = int256(weth.balanceOf(address(this)));
        startingX = int256(poolToken.balanceOf(address(this)));
        expectedDeltaY = int256(-1) * int256(outputWeth);
        expectedDeltaX = int256(pool.getPoolTokensToDepositBasedOnWeth(poolTokenAmount));

        if (poolToken.balanceOf(swapper) < poolTokenAmount) {
            poolToken.mint(swapper, poolTokenAmount - poolToken.balanceOf(swapper) + 1);
        }

        vm.startPrank(swapper);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        vm.stopPrank();

        //actual
        uint256 endingY = weth.balanceOf(address(this));
        uint256 endingX = poolToken.balanceOf(address(this));

        actualDeltaX = int256(endingX) - int256(startingX);
        actualDeltaY = int256(endingY) - int256(startingY);
    }

    function deposit(uint256 wethAmount) public {
        wethAmount = bound(wethAmount, 0, type(uint64).max);

        startingY = int256(weth.balanceOf(address(this)));
        startingX = int256(poolToken.balanceOf(address(this)));
        expectedDeltaY = int256(wethAmount);
        expectedDeltaX = int256(pool.getPoolTokensToDepositBasedOnWeth(wethAmount));

        vm.startPrank(lp);
        weth.mint(lp, wethAmount);
        poolToken.mint(lp, uint256(expectedDeltaX));
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);
        pool.deposit(wethAmount, 0, uint256(expectedDeltaX), uint64(block.timestamp));
        vm.stopPrank();

        //actual
        uint256 endingY = weth.balanceOf(address(this));
        uint256 endingX = poolToken.balanceOf(address(this));

        actualDeltaX = int256(endingX) - int256(startingX);
        actualDeltaY = int256(endingY) - int256(startingY);
    }
}
