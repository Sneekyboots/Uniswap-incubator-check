// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointsHook is BaseHook, ERC1155 {
    // Custom error definition
    error Currency0IsNotAddressZero();

    constructor(IPoolManager _manager) BaseHook(_manager) {}

    // every lP starts with a PoolkEY
    // PoolKey.toId=> PoolId(bytes32)
    // setting up the hook permission to return true
    // for the two hook functions we are using true
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Implement the ERC1155 `uri` function
    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }

    function _beforeInitialize(address, PoolKey calldata _poolKey, uint160) internal pure override returns (bytes4) {
        // check that the token zero only allows if eth is the one being bought
        if (!_poolKey.currency0.isAddressZero()) {
            revert Currency0IsNotAddressZero();
        }
        return this.beforeInitialize.selector;
    }

    function _afterSwap(
        address,
        PoolKey calldata _poolKey,
        SwapParams calldata _swapParams,
        BalanceDelta _delta,
        bytes calldata _hookData
    ) internal override returns (bytes4, int128) {
        // make sure this is eth token //we have done this at the top
        // make sure that the swap is being made for eth at token zero
        if (!_swapParams.zeroForOne) {
            return (this.afterSwap.selector, 0);
        }

        // Mint the points equa to 20% of the eth being bought or swapped in
        // if amount specified is less than zero that means it exact input for variable outpu
        // the amount of eth they spend is equal to amountSpecified
        //
        // if amount specified is more than zero then it is the case for exact output for the input
        // in this case the amount of eth they spent is equal to the BalanceDelta.amout0()
        uint256 ethSpendAmount = uint256(int256(-_delta.amount0())); //in this case we know user will give negative since user is spending eth
        uint256 pointsForSwap = ethSpendAmount / 5; //SINCE WE ARE GIVING OUT 20%

        _assignPoints(_poolKey.toId(), _hookData, pointsForSwap);

        return (this.afterSwap.selector, 0);
    }

    function _assignPoints(PoolId _poolId, bytes calldata _hookData, uint256 _points) internal {
        // we dont want to stop the swaps so we will just skip if no hookdata is given
        if (_hookData.length == 0) {
            return;
        }

        // but if we did get hookdata extract the user address from _hookData
        address user = abi.decode(_hookData, (address));

        // if user gives an adress which is not zero adress then
        if (user == address(0)) {
            return;
        }

        // ERC20 will hold the value of the amount
        // ERC721 Holds the uniqueid and unique owner
        // ERC1155 is combination which holds the uniqueid and also amount
        uint256 poolIdUint = uint256(PoolId.unwrap(_poolId));
        _mint(user, poolIdUint, _points, "");
    }
}
