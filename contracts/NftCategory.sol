// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NftCategory is ERC721Enumerable, Ownable, ReentrancyGuard {
  using Counters for Counters.Counter;
  using SafeMath for uint256;
  Counters.Counter private _tokenIdTracker;

  string private _baseTokenURI;

  bool public isAdminMintingDone;

  uint256 public REVEAL_TIMESTAMP;
  uint256 public lastPublicTokenMinted;
  uint256 public maxTokensPerUser;

  mapping(uint256 => bool) public tokensReserved;
  mapping(address => uint256[]) public reservedTokenOwners;
  mapping(address => mapping(uint256 => bool)) public allowMint;
  mapping(address => mapping(uint256 => uint256))
    public tokensMintedPerCategoryPerAddress;
  mapping(uint256 => uint256) public totalTokensMintedPerCategory;

  struct category {
    uint256 id;
    uint256 startTime;
    uint256 endTime;
    uint256 maxPerAddress;
    uint256 categoryTokenCap;
    bool isPrivate;
    bool isActive;
    uint256 price;
  }

  category[] public categories;

  constructor(
    string memory name,
    string memory symbol,
    uint256 _maxTokenPerUser,
    string memory baseTokenURI_
  ) ERC721(name, symbol) {
    maxTokensPerUser = _maxTokenPerUser;
    _baseTokenURI = baseTokenURI_;
  }

  function baseURI() public view returns (string memory) {
    return _baseURI();
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURILink(string memory _baseURILink) external onlyOwner {
    _baseTokenURI = _baseURILink;
  }

  function setRevealTimestamp(uint256 revealTimeStamp) public onlyOwner {
    REVEAL_TIMESTAMP = revealTimeStamp;
  }

  receive() external payable {}

  function stopAdminMinting() public onlyOwner {
    isAdminMintingDone = true;
  }

  function setMaxTokensPerUser(uint256 _value) public onlyOwner {
    maxTokensPerUser = _value;
  }

  function disableAddressMint(address _address, uint256 _categoryId)
    public
    onlyOwner
  {
    allowMint[_address][_categoryId] = false;
  }

  function allowAddressToMint(address _address, uint256 _categoryId)
    public
    onlyOwner
  {
    allowMint[_address][_categoryId] = true;
  }

  function addCategory(
    uint256 _startTime,
    uint256 _endTime,
    uint256 _maxPerAddress,
    uint256 _categoryTokenCap,
    bool _isPrivate,
    bool _isActive,
    uint256 _price
  ) public onlyOwner {
    categories.push(
      category({
        id: categories.length,
        startTime: _startTime,
        endTime: _endTime,
        maxPerAddress: _maxPerAddress,
        categoryTokenCap: _categoryTokenCap,
        isPrivate: _isPrivate,
        isActive: _isActive,
        price: _price
      })
    );
  }

  function updateCategory(
    uint256 _categoryId,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _maxPerAddress,
    uint256 _categoryTokenCap,
    bool _isPrivate,
    bool _isActive,
    uint256 _price
  ) public onlyOwner {
    categories[_categoryId].isActive = _isActive;
    categories[_categoryId].isPrivate = _isPrivate;
    categories[_categoryId].maxPerAddress = _maxPerAddress;
    categories[_categoryId].categoryTokenCap = _categoryTokenCap;
    categories[_categoryId].startTime = _startTime;
    categories[_categoryId].endTime = _endTime;
    categories[_categoryId].price = _price;
  }

  function reserveToken(address _address, uint256 _tokenId) public onlyOwner {
    require(!tokensReserved[_tokenId], "Token already reserved");
    require(!isAdminMintingDone, "Admin Minting Done");
    tokensReserved[_tokenId] = true;
    reservedTokenOwners[_address].push(_tokenId);
  }

  function unreserveToken(address _address, uint256 _tokenId) public onlyOwner {
    require(tokensReserved[_tokenId], "Token is not reserved");
    require(!_exists(_tokenId), "Token already minted");
    tokensReserved[_tokenId] = false;
    uint256[] memory tokenIds = reservedTokenOwners[_address];
    uint256 index = findTokenIndex(_tokenId, tokenIds);
    removeReservedFromList(_address, index);
  }

  function findTokenIndex(uint256 _tokenId, uint256[] memory tokenIdList)
    internal
    pure
    returns (uint256)
  {
    for (uint256 i; i < tokenIdList.length; i++) {
      if (tokenIdList[i] == _tokenId) {
        return i;
      }
    }
  }

  function removeReservedFromList(address _address, uint256 index) internal {
    for (uint256 a = index; a < reservedTokenOwners[_address].length - 1; a++) {
      reservedTokenOwners[_address][a] = reservedTokenOwners[_address][a + 1];
    }
    reservedTokenOwners[_address].pop();
  }

  function mintTokens(uint256 _categoryId, uint256 _quantity) public payable {
    require(
      categories[_categoryId].price.mul(_quantity) <= msg.value,
      "Not enough ETH"
    );
    for (uint256 i; i < _quantity; i++) {
      require(categories[_categoryId].isActive, "Category not Active");
      require(
        categories[_categoryId].startTime <= block.timestamp,
        "Category not Active"
      );
      require(
        categories[_categoryId].endTime >= block.timestamp,
        "Category already Expired"
      );
      require(
        tokensMintedPerCategoryPerAddress[msg.sender][_categoryId] <
          categories[_categoryId].maxPerAddress,
        "Over Max wallet category"
      );
      require(
        totalTokensMintedPerCategory[_categoryId] <
          categories[_categoryId].categoryTokenCap,
        "Over Max category tokens"
      );
      require(
        balanceOf(msg.sender) < maxTokensPerUser,
        "Over Max Wallet tokens"
      );

      if (categories[_categoryId].isPrivate) {
        require(allowMint[msg.sender][_categoryId], "Category is private");
      }

      if (reservedTokenOwners[msg.sender].length > 0 && !isAdminMintingDone) {
        _safeMint(
          msg.sender,
          reservedTokenOwners[msg.sender][
            reservedTokenOwners[msg.sender].length - 1
          ]
        );
        reservedTokenOwners[msg.sender].pop();
      } else {
        require(isAdminMintingDone, "Team mint in progress");
        bool tokenMinted = false;
        while (!tokenMinted) {
          if (!_exists(lastPublicTokenMinted)) {
            _safeMint(msg.sender, lastPublicTokenMinted);
            lastPublicTokenMinted++;
            tokenMinted = true;
          } else {
            lastPublicTokenMinted++;
          }
        }
      }
      tokensMintedPerCategoryPerAddress[msg.sender][_categoryId]++;
      totalTokensMintedPerCategory[_categoryId]++;
    }
  }

  function withdrawETH(address _wallet, uint256 _amount) public onlyOwner {
    payable(_wallet).transfer(_amount);
  }
}
