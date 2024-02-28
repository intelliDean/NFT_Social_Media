// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

//import "contracts/socialMedia/INFTFactory.sol";
//import "contracts/socialMedia/NFTFactory.sol";
import "./Err.sol";
import "./NFTFactory.sol";





contract NFTSocialMedia {

    address private owner;
    NFTFactory private nftFactory;

    Post[] feeds;
    mapping(address => Account) private accounts;
    mapping(address => bool) private loggedIn;

    mapping(address => mapping(address => bool)) private followers;
    mapping(address => User) private users;
    mapping(address => address) private userNFTContracts;

    mapping(bytes32 => Post) private posts;
    mapping(bytes32 => Comment) private comments;
    mapping(address => mapping(bytes32 => bool)) private postLikes;
    mapping(address => mapping(bytes32 => bool)) private commentLikes;
    mapping(bytes32 => Group) private groups;
    mapping(address => mapping(bytes32 => bool)) private groupMembers;
    mapping(bytes32 => mapping(bytes32 => Post)) private postsInGroup;
    mapping(address => mapping(bytes32 => mapping(bytes32 => bool))) private likePostInGroup;


    event Registered(address userId, address nftFactoryAddress, bool success);
    event LoggedIn(address userId, bool success);
    event CreatePost(address userId, bytes32 postId, bool success);

    enum ROLE {
        ADMIN, USER
    }

    struct User {
        address userId;
        ROLE role;
    }

    struct Group {
        bytes32 groupId;
        address groupOwner;
        address[] member;
        uint256 createAt;
        Post[] groupPosts;
    }

    struct Account {
        User userInfo;
        string fullName;
        string username;
        uint256 noOfPost;
        address[] followers;
        Post[] posts;
    }

    struct Comment {
        address commenter;
        bytes32 commentId;
        string content;
        uint256 likes;
        uint256 commentTime;
    }

    struct Post {
        bytes32 postId;
        string nftURI;
        string content;
        uint256 postTime;
        Comment[] comments;
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
        if (msg.sender != owner) revert Err.ONLY_OWNER();
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

        emit Registered(msg.sender, nftFactoryAddress, true);
    }

    function login() external returns (bool){
        checkAddressZero();
        onlyUser();

        assert(!loggedIn[msg.sender]);

        loggedIn[msg.sender] = true;
        emit LoggedIn(msg.sender, true);

        return true;
    }

    function logout() external returns (bool) {
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

        //push post into necesary places
        feeds.push(_post);
        accounts[msg.sender].posts.push(_post);

        emit CreatePost(msg.sender, _postId, true);
    }

    function getPost(bytes32 _postId) external view returns (Post memory) {

        return posts[_postId];
    }

    function commentOnPost(bytes32 _postId, string memory _content) external {
        onlyUser();
        isLoggedIn();

        bytes32 commentId = keccak256(abi.encodePacked(msg.sender, _postId, _content));

        Comment storage _comment = comments[commentId];
        _comment.commenter = msg.sender;
        _comment.commentId = commentId;
        _comment.content = _content;
        _comment.commentTime = block.timestamp;

        posts[_postId].comments.push(_comment);
    }

    function likeAndUnlikePost(bytes32 _postId) external {
        onlyUser();
        isLoggedIn();

        Post storage _post = posts[_postId];

        if (postLikes[msg.sender][_postId]) {
            _post.likes = _post.likes - 1;
            postLikes[msg.sender][_postId] = false;
        } else {
            _post.likes = _post.likes + 1;
            postLikes[msg.sender][_postId] = true;
        }
    }

    function likeAndUnlikeComment(bytes32 _commentId) external {
        onlyUser();
        isLoggedIn();

        Comment storage _comment = comments[_commentId];
        if (commentLikes[msg.sender][_commentId]) {
            _comment.likes = _comment.likes - 1;
            commentLikes[msg.sender][_commentId] = false;
        } else {
            _comment.likes = _comment.likes + 1;
            commentLikes[msg.sender][_commentId] = true;
        }
    }

    function userCreateGroup() external {
        onlyUser();
        isLoggedIn();
        uint256 _time = block.timestamp;

        bytes32 _groupId = keccak256(abi.encodePacked(msg.sender, _time));
        Group storage _group = groups[_groupId];
        _group.groupId = _groupId;
        _group.groupOwner = msg.sender;
        _group.createAt = _time;
    }

    function usersJoinGroup(bytes32 _groupId) external {
        onlyUser();
        isLoggedIn();

        Group storage _group = groups[_groupId];

        groupMembers[msg.sender][_groupId] = true;
        _group.member.push(msg.sender);
    }

    function onlyGroupMember(bytes32 _groupId) private view {
        if (!groupMembers[msg.sender][_groupId]) revert Err.YOU_ARE_NOT_A_MEMBER_OF_THIS_GROUP();
    }

    function membersPostOnGroup(bytes32 _groupId, string memory _content, string memory _uri) external {
        onlyUser();
        isLoggedIn();
        onlyGroupMember(_groupId);

        uint256 _time = block.timestamp;

        bytes32 _postId = keccak256(abi.encodePacked(msg.sender, _content, _time));

        if (!nftFactory.mintNFT(msg.sender, _uri)) revert Err.COULD_NOT_CREATE_NFT();

        Post storage _post = postsInGroup[_groupId][_postId];
        _post.postId = _postId;
        _post.content = _content;
        _post.nftURI = _uri;
        _post.postTime = _time;

        Group storage _group = groups[_groupId];
        _group.groupPosts.push(_post);

    }


    function memberLikesAndUnlikePostOnGroup(bytes32 _groupId, bytes32 _postId) external {
        onlyUser();
        isLoggedIn();
        onlyGroupMember(_groupId);

        Post storage _post = postsInGroup[_groupId][_postId];

        if (likePostInGroup[msg.sender][_groupId][_postId]) {
            _post.likes = _post.likes - 1;
            likePostInGroup[msg.sender][_groupId][_postId] = false;
        } else {
            _post.likes = _post.likes + 1;
            likePostInGroup[msg.sender][_groupId][_postId] = true;
        }
    }
}