// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import '@openzeppelin/contracts/access/Ownable.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

// import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
// import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/ISwapRouter.sol';
import './Math.sol';
import 'hardhat/console.sol';

interface ERC20 {
    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function mint(address to, uint256 value) external;

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

contract LendingPool is Ownable {
    using SafeMath for uint256;
    //  AggregatorV3Interface public priceCollateral;
    //  AggregatorV3Interface public priceLoan;

    // AggregatorV3Interface internal constant priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
    ISwapRouter public constant uniswapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    mapping(address => uint256) public lendingPoolTokenList;
    mapping(address => uint256) public lendersList;
    mapping(address => uint256) public borrowwerList;
    uint256 public lendingId = 0;
    uint256 public borrowerId = 0;
    uint256 public borrowPercentage;
    uint256 public loan;

    //===========================================================================
    struct lendingMember {
        address lenderAddress; // address of the user that lended
        string token; //eth,Matic ,bnb
        uint256 tokenAmount; //1
        uint256 SuppliedAmount; //1
        uint256 startDay; // time when he lended
        uint256 endDay; // when lending period ends
        bool isRedeem; // if true is means he has something in pool if false it means he/she redeem
        address pledgeToken;
    }
    // if we have struct as above we can also map it like this
    // mapping(address => lendingMember) public mapLenderInfo;

    // mapping(address => mapping(string => lendingMember)) public mapLenderInfo;
    mapping(uint256 => lendingMember) public mapLenderInfo; // lending id goes to struct
    mapping(address => mapping(string => uint256[])) public lenderIds;
    mapping(address => mapping(string => uint256)) public lenderShares;
    //===========================================================================
    struct borrowMember {
        address borrowerAddress;
        string collateralToken;
        uint256 tokenAmount;
        uint256 borrowDay;
        uint256 endDay;
        bool hasRepaid;
    }
    mapping(uint256 => borrowMember) public mapBorrowerInfo;
    mapping(address => mapping(string => uint256[])) public borrowerIds;
    mapping(address => mapping(string => uint256)) public borrowerShares;

    constructor() {}

    function lend(
        string memory _tokenSymbol,
        uint256 _amount,
        uint256 _days,
        address _token,
        address _ftoken
    ) public payable {
        require(msg.value <= 0, 'Can not send 0 amount');

        // mapLenderInfo[msg.sender][_tokenSymbol].lenderAddress = msg.sender;
        // mapLenderInfo[msg.sender][_tokenSymbol].token = _tokenSymbol;
        // mapLenderInfo[msg.sender][_tokenSymbol].tokenAmount = _amount;
        // mapLenderInfo[msg.sender][_tokenSymbol].startDay = block.timestamp;
        // mapLenderInfo[msg.sender][_tokenSymbol].endDay = block.timestamp + _days * 1 days;
        // mapLenderInfo[msg.sender][_tokenSymbol].isRedeem = false;
        lendingId += 1;
        lenderIds[msg.sender][_tokenSymbol].push(lendingId);
        lenderShares[msg.sender][_tokenSymbol] += _amount;

        mapLenderInfo[lendingId].lenderAddress = msg.sender;
        mapLenderInfo[lendingId].token = _tokenSymbol;
        mapLenderInfo[lendingId].SuppliedAmount = _amount;
        mapLenderInfo[lendingId].tokenAmount = _amount;
        mapLenderInfo[lendingId].startDay = block.timestamp;
        mapLenderInfo[lendingId].endDay = block.timestamp + _days * 1 days;
        mapLenderInfo[lendingId].isRedeem = false;
        mapLenderInfo[lendingId].pledgeToken = _ftoken;
        ERC20(_token).transferFrom(msg.sender, address(this), _amount);
        ERC20(_ftoken).mint(msg.sender, _amount);
    }

    // function isLenderExist (address _address) public view return (bool){
    //   return true
    // }
    function getLenderId(string memory _tokenSymbol) public view returns (uint256[] memory) {
        return lenderIds[msg.sender][_tokenSymbol];
    }

    function getLenderAsset(uint256 _id) public view returns (lendingMember memory) {
        return mapLenderInfo[_id];
    }

    function getLenderShare(string memory _tokenSymbol) public view returns (uint256) {
        return lenderShares[msg.sender][_tokenSymbol];
    }

    // function lendedAssetDetails(string memory _tokenSymbol) public view returns () {
    //     // return mapLenderInfo[msg.sender][_tokenSymbol][1];
    //     return mapLenderInfo[msg.sender][_tokenSymbol][50];
    // }

    function redeem(
        string memory _tokenSymbol,
        uint256 _amount,
        address _token,
        uint256 _lendeingId
    ) external payable {
        // require(block.timestamp >= mapLenderInfo[_lendeingId].endDay, "Can not redeem before end day");
        require(keccak256(abi.encodePacked(mapLenderInfo[_lendeingId].token)) == keccak256(abi.encodePacked(_tokenSymbol)), 'Use correct token');
        mapLenderInfo[_lendeingId].isRedeem = true;
        mapLenderInfo[_lendeingId].tokenAmount -= _amount;
        lenderShares[msg.sender][_tokenSymbol] -= _amount;
        ERC20(_token).transfer(msg.sender, _amount);
        ERC20(mapLenderInfo[_lendeingId].pledgeToken).transferFrom(msg.sender, address(this), _amount);
    }

    function borrow(
        string memory _collateralTokenSymbol,
        uint256 _collateralAmount,
        address _collateralToken,
        address _loanToken
        // address loanAggregator,
        // address collateralAggregator
    ) external payable {
        // require(block.timestamp >= mapLenderInfo[_borrowerId].endDay, "Can not redeem before end day");
        // require(keccak256(abi.encodePacked(mapLenderInfo[_borrowerId].token)) == keccak256(abi.encodePacked(_tokenSymbol)),'Use correct token');
        // IERC20 tokenObj = IERC20(_token);
        uint256 _borrowerId = borrowerId++;
        borrowerIds[msg.sender][_collateralTokenSymbol].push(lendingId);
        // uint alloweAmount =  getLoanAmount(loanAggregator,collateralAggregator,_collateralAmount);
        uint alloweAmount =  getLoanAmount2(_collateralAmount,1000,1);
        console.log("hardhat alloweAmount=>",alloweAmount);
        mapBorrowerInfo[_borrowerId].borrowerAddress = msg.sender;
        mapBorrowerInfo[_borrowerId].collateralToken = _collateralTokenSymbol;
        mapBorrowerInfo[_borrowerId].tokenAmount += _collateralAmount;
        mapBorrowerInfo[_borrowerId].borrowDay = block.timestamp;
        mapBorrowerInfo[_borrowerId].hasRepaid = false;
        borrowerShares[msg.sender][_collateralTokenSymbol] += _collateralAmount;
        ERC20(_collateralToken).transferFrom(msg.sender, address(this), _collateralAmount);
        ERC20(_loanToken).transfer(msg.sender, alloweAmount);
    }

    function repay(
        string memory _collateralTokenSymbol,
        uint256 _collateralAmount,
        address _collateralToken,
        address _loanToken,
        uint _loanAmount,
        uint _borrowerId
    ) external payable {
        require(mapBorrowerInfo[_borrowerId].borrowerAddress == msg.sender, "Wrong owner");
        if(mapBorrowerInfo[_borrowerId].tokenAmount ==_collateralAmount){
           mapBorrowerInfo[_borrowerId].hasRepaid = true;
        }
        mapBorrowerInfo[_borrowerId].tokenAmount -= _collateralAmount;
        borrowerShares[msg.sender][_collateralTokenSymbol] -= _collateralAmount;
        ERC20(_collateralToken).transfer(msg.sender, _collateralAmount);
        ERC20(_loanToken).transferFrom(msg.sender, address(this), _loanAmount);
    }


    function poolTokensBal(address _address) public view returns (uint256) {
        return ERC20(_address).balanceOf(address(this));
    }

    function setPercentage(uint256 _percentage) external {
        borrowPercentage = _percentage;
    }

    function checkPercentage(uint256 _amount) public view returns (uint256) {
        // uint per = (_amount * borrowPercentage) /10000;
        return _amount.mul(borrowPercentage).div(1e18);
    }

    function getBorrowerId(string memory _collateralTokenSymbol) public view returns (uint256[] memory) {
        return borrowerIds[msg.sender][_collateralTokenSymbol];
    }

    function getBorrowerDetails(uint256 _id) public view returns (borrowMember memory) {
        return mapBorrowerInfo[_id];
    }

    function getBorrowerShare(string memory _collateralTokenSymbol) public view returns (uint256) {
        return borrowerShares[msg.sender][_collateralTokenSymbol];
    }


    function getLoanAmount(
        address loanTokenAggregator,
        address collateralTokenAggregator,
        uint256 collateralAmount
    ) public view returns (uint256) {
        AggregatorV3Interface CollateralPrice = AggregatorV3Interface(collateralTokenAggregator);
        (, int256 price, , , ) = CollateralPrice.latestRoundData();

        AggregatorV3Interface LoanPrice = AggregatorV3Interface(loanTokenAggregator);
        ( , int256 loanPrice,,,) = LoanPrice.latestRoundData();

        uint256 amount = collateralAmount.mul(uint256(price));
        uint256 percentage = amount.mul(borrowPercentage).div(100);
        uint256 loadAmount = uint256(percentage).div(uint(loanPrice));
        return loadAmount;
    }

    function getLoanAmount2(
        uint256 collateralAmount,
        uint256 collateralTokenPrice,
        uint256 loanTokenPrice
    ) public view returns (uint256) {
        uint256 amount = collateralAmount.mul(collateralTokenPrice);
        uint256 percentage = amount.mul(borrowPercentage).div(100);
        uint256 price = uint256(percentage).div(loanTokenPrice);
        return price;
    }

    function getAggregatorPrice(address _tokenAddress) public view returns (uint256) {
        AggregatorV3Interface LoanPrice = AggregatorV3Interface(_tokenAddress);
        (
            ,
            /*uint80 roundID*/
            int256 loanPrice,
            ,
            ,

        ) = /*uint startedAt*/
            /*uint timeStamp*/
            /*uint80 answeredInRound*/
            LoanPrice.latestRoundData();

        return uint256(loanPrice);
    }
}
