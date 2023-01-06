//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface AggregatorV3Interface {
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int answer,
      uint startedAt,
      uint updatedAt,
      uint80 answeredInRound
    );
}

contract NFT_Marketplace {
    receive() external payable {}

    uint256 list_fee = 0.001 ether;
    event NFT_Listed(address indexed _from, address indexed _NFT_contract_address, uint256 indexed _tokenID);
    event NFT_Listed_In_Dai(address indexed _from, address indexed _NFT_contract_address, uint256 indexed _tokenID);
    event NFT_Price_Change(address indexed _contract_address, uint256 indexed _tokenID, uint256 indexed _new_listing_price);
    event NFT_De_Listed(address indexed _contract_address, uint256 indexed _tokenID);
    event NFT_Purchased(uint256 indexed _amount);
    event Proceeds_Withdrawn(uint256 indexed _amount);

    AggregatorV3Interface internal priceFeed;
    IERC20 internal Dai;

    constructor() {
        // ETH / USD
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        Dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    }

    mapping(address => mapping(uint256 => uint256)) ListedTokens2;

    mapping(address => uint256) Proceeds;

    mapping(address => uint256) Proceeds_in_dai;

    modifier CheckListed(address _contract_address, uint256 _tokenID) {
        require(check_if_listed2(_contract_address, _tokenID), "NFT not listed! You Suck!");
        _;
    }

    modifier OwnerCheck(address _NFT_contract_address, uint256 _tokenID) {
        require(msg.sender == IERC721(_NFT_contract_address).ownerOf(_tokenID), "You are not the owner! You Suck!");
        _;
    }

    function getLatestPrice() public view returns (int) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return price / 1e8;
    }

    function list_NFT2(address _NFT_contract_address, uint256 _tokenID, uint256 _listPrice) public payable OwnerCheck(_NFT_contract_address, _tokenID) {
        require(msg.value > list_fee, "Insufficient Funds, You Suck!");
        IERC721(_NFT_contract_address).approve(address(this), _tokenID);
        require(IERC721(_NFT_contract_address).isApprovedForAll(msg.sender, address(this)), "Fail! You Suck!");
        ListedTokens2[_NFT_contract_address][_tokenID] = _listPrice;
        emit NFT_Listed(msg.sender, _NFT_contract_address, _tokenID);
    }

    function list_NFT_in_dai(address _NFT_contract_address, uint256 _tokenID, uint256 _listPrice, int _amountSentDai) public payable OwnerCheck(_NFT_contract_address, _tokenID) {
        int listingFeeInDai = getLatestPrice()/1000;
        require(_amountSentDai >= listingFeeInDai, "Insufficient Funds! You Suck!");
        Dai.transferFrom(msg.sender, address(this), uint256(_amountSentDai));
        require(IERC721(_NFT_contract_address).isApprovedForAll(msg.sender, address(this)), "Fail! You Suck!");
        ListedTokens2[_NFT_contract_address][_tokenID] = _listPrice;
        emit NFT_Listed(msg.sender, _NFT_contract_address, _tokenID);
    }

    function check_if_listed2(address _contract_address, uint256 _tokenID) private view returns (bool) {
        if (ListedTokens2[_contract_address][_tokenID] > 0) {
            return true;
        } else {
            return false;
        }
    }

    function change_listing_price2(address _contract_address, uint256 _tokenID, uint256 _new_listing_price) public CheckListed(_contract_address, _tokenID) OwnerCheck(_contract_address, _tokenID) {
        ListedTokens2[_contract_address][_tokenID] = _new_listing_price;
        emit NFT_Price_Change(_contract_address, _tokenID, _new_listing_price);
    }

    function de_list_NFT2(address _contract_address, uint256 _tokenID) public CheckListed(_contract_address, _tokenID) OwnerCheck(_contract_address, _tokenID) {
        delete ListedTokens2[_contract_address][_tokenID];
        emit NFT_De_Listed(_contract_address, _tokenID);
    }

    function Buy_NFT2(address _NFT_contract_address, uint256 _tokenID) public payable CheckListed(_NFT_contract_address, _tokenID) {
        require(msg.value > ListedTokens2[_NFT_contract_address][_tokenID], "Insufficent Funds! You Suck!");
        require(IERC721(_NFT_contract_address).isApprovedForAll(msg.sender, address(this)), "Fail! You Suck!");
        address owner = IERC721(_NFT_contract_address).ownerOf(_tokenID);
        IERC721(_NFT_contract_address).transferFrom(owner, msg.sender, _tokenID);
        Proceeds[payable(msg.sender)] = Proceeds[payable(msg.sender)] + msg.value;
        emit NFT_Purchased(msg.value);
    }

    function Buy_NFT_in_dai(address _NFT_contract_address, uint256 _tokenID, uint256 _amountPaidInDai) public payable CheckListed(_NFT_contract_address, _tokenID) {
        uint256 listingPriceInDai = ListedTokens2[_NFT_contract_address][_tokenID] / uint256(getLatestPrice());
        require(_amountPaidInDai >= listingPriceInDai, "Insufficient Funds! You Suck!");
        address owner = IERC721(_NFT_contract_address).ownerOf(_tokenID);
        IERC721(_NFT_contract_address).transferFrom(owner, msg.sender, _tokenID);
        Proceeds_in_dai[payable(msg.sender)] = Proceeds_in_dai[payable(msg.sender)] + _amountPaidInDai;
        emit NFT_Purchased(_amountPaidInDai);
    }

    function withdraw_proceeds() public {
        require(Proceeds[msg.sender] > 0, "You have no money! You Suck!");
        (bool sent, ) = msg.sender.call{value: Proceeds[msg.sender]}("");
        require(sent, "Transfer failed! You Suck!");
        emit Proceeds_Withdrawn(Proceeds[msg.sender]);
    }

    function withdraw_proceeds_in_dai() public {
        require(Proceeds_in_dai[msg.sender] > 0, "You have no money! You Suck!");
        Dai.transferFrom(address(this), msg.sender, Proceeds_in_dai[msg.sender]);
        emit Proceeds_Withdrawn(Proceeds_in_dai[msg.sender]);
    }
}