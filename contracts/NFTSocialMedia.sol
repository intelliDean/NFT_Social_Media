// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

//import "contracts/socialMedia/INFTFactory.sol";
//import "contracts/socialMedia/NFTFactory.sol";
import "./Err.sol";


contract NFTSocialMedia {

    address private owner;
    NFTFactory private nftFactory;

    Post[] feeds;
    mapping(address => Account) private accounts;
    mapping(address => bool) private loggedIn;

    mapping(address => mapping (address => bool)) private followers;
    mapping(address => User) private users;
    mapping(address => address) private userNFTContracts;

    mapping(bytes32 => Post) private posts;

    event Registered(address userId, bool success);
    event LoggedIn(address userId, bool success);
    event CreatePost(address userId, bytes32 postId, bool success);

    enum ROLE {
        ADMIN, USER
    }

    struct User {
        address userId;
        ROLE role;
    }

    struct Account {
        User userInfo;
        string fullName;
        string username;
        uint256 noOfPost;
        address[] followers;
        Post[] posts;
    }

    struct Post {
        bytes32 postId;
        string nftURI;
        string content;
        uint256 postTime;
        string[] comments;
        uint256 likes;
    }

    constructor(address _nftContract) {
        owner = msg.sender;
        nftFactory = NFTFactory(_nftContract);
    }

    function checkAddressZero() private view {
        if (msg.sender == address(0)) revert Err.ADDRESS_ZERO_NOT_ALLOWED();
    }

    function onlyOwner() private view {
        if (msg.sender != owner) revert ONLY_OWNER();
    }

    function onlyUser() private view {
        if (users[msg.sender].role != ROLE.USER) revert Err.ONLY_USER();
    }

    function isLoggedIn() private view {
        if (!loggedIn[msg.sender]) revert Err.YOU_ARE_NOT_LOGGED_IN__LOG_IN_TO_CONTINUE();
    }

    function registerUser(
        string calldata _fullName,
        string calldata _username,
        string memory _nftName,
        string memory _nftSymbol
        ) external {
        checkAddressZero();
        if (users[msg.sender].userId != address(0)) revert Err.ALREADY_REGISTERED__LOGIN();

        User storage _user = users[msg.sender];
        _user.userId = msg.sender;
        _user.role = ROLE.USER;

        address nftFactoryAddress = nftFactory.createNFT(msg.sender, _nftName, _nftSymbol);
        userNFTContracts[msg.sender] = nftFactoryAddress;

        Account storage _account = accounts[msg.sender];
        _account.userInfo = _user;
        _account.username = _username;
        _account.fullName = _fullName;

        emit Registered(msg.sender, true);
    }

    function login() external returns(bool){
        checkAddressZero();
        onlyUser();

        assert(!loggedIn[msg.sender]);

        loggedIn[msg.sender] = true;
        emit LoggedIn(msg.sender, true);

        return true;
    }

    function logout() external returns(bool) {
        checkAddressZero();
        onlyUser();

       loggedIn[msg.sender] = false;
        emit LoggedIn(msg.sender, true);

        return true;
    }

    function createPost(string memory _content, string memory _uri) external {
        checkAddressZero();
        isLoggedIn();

       bytes32 _postId = keccak256(abi.encodePacked(msg.sender, _content, block.timestamp));

       if (!nftFactory.mintNFT(msg.sender, _uri)) revert Err.COULD_NOT_CREATE_NFT();

       Post storage _post = posts[_postId];
       _post.postId = _postId;
       //this content will be the NFT eventually
       _post.content = _content;
       _post.nftURI = _uri;
       _post.postTime = block.timestamp;

       //push post into necessary places
       feeds.push(_post);
       accounts[msg.sender].posts.push(_post);

        emit CreatePost(msg.sender, _postId, true);
    }


    function getPost(bytes32 _postId) external view returns(Post memory) {

        return posts[_postId];
    }
}