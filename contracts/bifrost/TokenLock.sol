// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

/// @title Token locking contract
/// @author Michael, Daniel Lee
/// @notice You can use this contract to apply locking to any ERC20 token
/// @dev All function calls are currently implemented without side effects
contract TokenLock is Initializable, ERC721EnumerableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct LockInfo {
        address token;
        uint256 amount;
        uint256 lockExpiresAt;
    }

    /// @notice ID => locks
    mapping(uint256 => LockInfo) public lockedTokens;

    event Locked(address indexed token, address indexed locker, uint256 amount);
    event Unlocked(address indexed token, address indexed locker, uint256 amount);

    function initialize() external initializer {
        __ERC721Enumerable_init();
    }

    /**
     * @notice lock tokens
     * @param _token address to lock
     * @param _amount to lock
     * @param _period to lock
     */
    function lock(address _token, uint256 _amount, uint256 _period) external {
        uint256 id = totalSupply() + 1;
        lockedTokens[id] = LockInfo(_token, _amount, block.timestamp + _period);
        _mint(msg.sender, id);

        emit Locked(_token, msg.sender, _amount);

        IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice unlock current tokens
     */
    function unlock(uint256 id) external {
        require(ownerOf(id) == msg.sender, "Not owner of this lock");

        LockInfo memory lockInfo = lockedTokens[id];

        require(lockInfo.amount > 0, "Not locked");
        require(lockInfo.lockExpiresAt <= block.timestamp, "Still in the lock period");

        delete lockedTokens[id];

        emit Unlocked(lockInfo.token, msg.sender, lockInfo.amount);

        // transfer unlocked amount to user
        IERC20Upgradeable(lockInfo.token).safeTransfer(msg.sender, lockInfo.amount);
    }
}
