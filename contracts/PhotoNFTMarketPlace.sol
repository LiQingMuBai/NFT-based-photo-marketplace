// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFTCollection is ERC721, ERC721Enumerable {
  string[] public tokenURIs;
  mapping(string => bool) _tokenURIExists;
  mapping(uint => string) _tokenIdToTokenURI;

  constructor() 
    ERC721("WOWARRIORS Collection", "WOWNFT") 
  {
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function tokenURI(uint256 tokenId) public override view returns (string memory) {
    require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
    return _tokenIdToTokenURI[tokenId];
  }

  function safeMint(string memory _tokenURI) public {
    require(!_tokenURIExists[_tokenURI], 'The token URI should be unique');
    tokenURIs.push(_tokenURI);    
    uint _id = tokenURIs.length;
    _tokenIdToTokenURI[_id] = _tokenURI;
    _safeMint(msg.sender, _id);
    _tokenURIExists[_tokenURI] = true;
  }
}

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFTMarketplace is AccessControl{
  uint public offerCount;
  mapping (uint => _Offer) public offers;
  mapping (address => uint) public userFunds;
  uint [] array;
  NFTCollection nftCollection;
  bool private pause = false;
  bytes32 public constant MAKE_ROLE = keccak256("MAKE_OFFER_ROLE");
  bytes32 public constant FILL_ROLE = keccak256("FILL_OFFER_ROLE");

  struct _Offer {
    uint offerId;
    uint id;
    address user;
    uint price;
    bool fulfilled;
    bool cancelled;
  }

  event Offer(
    uint offerId,
    uint id,
    address user,
    uint price,
    bool fulfilled,
    bool cancelled
  );


  event ClaimNFT(uint offerId, uint id, address newOwner);
  event OfferFilled(uint offerId, uint id, address newOwner);
  event OfferCancelled(uint offerId, uint id, address owner);
  event ClaimFunds(address user, uint amount);

  constructor(address _nftCollection) {
    nftCollection = NFTCollection(_nftCollection);
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

   modifier processApprove() {
        require(!pause, "Contract paused");
        _;
    }
  
    
    function setPause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        pause = true;
    }
    
    function unSetPause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        pause = false;
    }


  function claimNFT(uint _offerId) public onlyRole(DEFAULT_ADMIN_ROLE){
      _Offer storage _offer = offers[_offerId];
      nftCollection.transferFrom(address(this), msg.sender, _offer.id);
      emit ClaimNFT(_offerId, _offer.id, msg.sender);
  }
  
  function addItem(uint _type, uint _id, uint _price) public onlyRole(MAKE_ROLE) processApprove{ 
    nftCollection.transferFrom(msg.sender, address(this), _id);
    offerCount ++;
    offers[offerCount] = _Offer(offerCount, _id, msg.sender, _price, false, false);
    emit Offer(offerCount, _id, msg.sender, _price, false, false);
  }

  function buyItems(uint num) public payable onlyRole(FILL_ROLE) processApprove{ 
      require(offerCount - num > 0, 'The offer must exist');
      for(uint i=1;i<=num;i++){
        require(offerCount > 0, 'The offer must exist');
        _Offer storage _offer = offers[offerCount];
        require(msg.value >= _offer.price * num, 'The ETH amount should match with the NFT Price');
        require(_offer.user != msg.sender, 'The owner of the offer cannot fill it');
        require(!_offer.fulfilled, 'An offer cannot be fulfilled twice');
        require(!_offer.cancelled, 'A cancelled offer cannot be fulfilled');
        require(msg.value == _offer.price, 'The ETH amount should match with the NFT Price');
        nftCollection.transferFrom(address(this), msg.sender, _offer.id);
        _offer.fulfilled = true;
        userFunds[_offer.user] += msg.value;
        offerCount--;
        emit OfferFilled(_offer.id, _offer.id, msg.sender);
      }
  }

  function buyItem() public payable onlyRole(FILL_ROLE) processApprove{ 
    require(offerCount > 0, 'The offer must exist');
    _Offer storage _offer = offers[offerCount];
    require(_offer.user != msg.sender, 'The owner of the offer cannot fill it');
    require(!_offer.fulfilled, 'An offer cannot be fulfilled twice');
    require(!_offer.cancelled, 'A cancelled offer cannot be fulfilled');
    require(msg.value == _offer.price, 'The ETH amount should match with the NFT Price');
    nftCollection.transferFrom(address(this), msg.sender, _offer.id);
    _offer.fulfilled = true;
    userFunds[_offer.user] += msg.value;
    offerCount--;
    emit OfferFilled(_offer.id, _offer.id, msg.sender);
  }

  function claimFunds() public {
    require(userFunds[msg.sender] > 0, 'This user has no funds to be claimed');
    payable(msg.sender).transfer(userFunds[msg.sender]);
    emit ClaimFunds(msg.sender, userFunds[msg.sender]);
    userFunds[msg.sender] = 0;    
  }

  // Fallback: reverts if Ether is sent to this smart-contract by mistake
  fallback () external {
    revert();
  }
}
