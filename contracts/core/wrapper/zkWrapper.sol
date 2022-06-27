pragma solidity ^0.8.0;

import "../../libs/token/ERC20/utils/SafeERC20.sol";
import "../../libs/token/ERC20/IERC20.sol";
import "../../libs/access/Ownable.sol";
import "../../libs/security/ReentrancyGuard.sol";
import "../../libs/utils/SafeMath.sol";
import "../../libs/security/Pausable.sol";

import "../lock_proxy/ILockProxy.sol";

contract Wrapper is Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address public feeCollector;
    IERC20 public feeToken;
    ILockProxy public lockProxy;

    constructor(address _feeToken) {
        feeToken = IERC20(_feeToken);
    }

    function setFeeCollector(address collector) external onlyOwner {
        require(collector != address(0), "emtpy address");
        feeCollector = collector;
    }

    function setLockProxy(address _lockProxy) external onlyOwner {
        require(_lockProxy != address(0));
        lockProxy = ILockProxy(_lockProxy);
        require(lockProxy.managerProxyContract() != address(0), "not lockproxy");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function extractFee(address token) external {
        require(msg.sender == feeCollector, "!feeCollector");
        IERC20(token).safeTransfer(feeCollector, IERC20(token).balanceOf(address(this)));
    }
    
    function lock(address fromAsset, uint64 toChainId, bytes memory toAddress, uint amount, uint fee, uint id) public payable nonReentrant whenNotPaused {
        
        require(toAddress.length !=0, "empty toAddress");
        address addr;
        assembly { addr := mload(add(toAddress,0x14)) }
        require(addr != address(0),"zero toAddress");
        
        if (fromAsset == address(feeToken)) {
            IERC20(fromAsset).safeTransferFrom(msg.sender, address(this), amount.add(fee));
        } else {
            IERC20(fromAsset).safeTransferFrom(msg.sender, address(this), amount);
            feeToken.safeTransferFrom(msg.sender, address(this), fee);
        }

        IERC20(fromAsset).safeApprove(address(lockProxy), 0);
        IERC20(fromAsset).safeApprove(address(lockProxy), amount);
        require(lockProxy.lock(fromAsset, toChainId, toAddress, amount), "lock erc20 fail");

        emit PolyWrapperLock(fromAsset, msg.sender, toChainId, toAddress, amount, fee, id);
    }

    event PolyWrapperLock(address indexed fromAsset, address indexed sender, uint64 toChainId, bytes toAddress, uint net, uint fee, uint id);

}