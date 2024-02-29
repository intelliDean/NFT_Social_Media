// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Err.sol";
import "./NFTFactory.sol";


contract NFTSocialMedia {

    address private owner;
    uint8 private constant CONTENT_MAX_LENGTH = 120;
    uint8 private constant NAME_MAX_LENGTH = 20;

    NFTFactory private nftFactory;

    Post[] private feeds;
    mapping(address => Account) private accounts;
    mapping(address => bool) private loggedIn;


    mapping(address => User) private users;
    mapping(bytes32 => Group) private groups;
    mapping(bytes32 => Post) private posts;
    mapping(bytes32 => Comment) private comments;
    mapping(address => address) private userNFTContracts;
    mapping(address => mapping(address => bool)) private followers;
    mapping(address => mapping(bytes32 => bool)) private postLikes;
    mapping(address => mapping(bytes32 => bool)) private commentLikes;


    mapping(address => mapping(bytes32 => bool)) private groupMembers;
    mapping(bytes32 => mapping(bytes32 => Post)) private postsInGroup;
    mapping(address => mapping(bytes32 => mapping(bytes32 => bool))) private likePostInGroup;

    event Registered(address userId, address nftFactoryAddress, bool success);
    event LoggedIn(address userId, bool success);
    event CreatePost(address userId, bytes32 postId, bool success);
    event CommentOnPost(address commenter, bytes32 _postId, bytes32 commentId);
    event CreateGroup(address groupOwner, bytes32 _groupId, bool success);
    event PostOnGroup(address ownerOfPost, bytes32 _groupId, bytes32 _postId);
    event CommentOnGroupPost(address commenter, bytes32 groupId, bytes32 postId, bytes32 commentId);


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
        string groupName;
        address[] members;
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

    constructor(address _nftFactoryContract) {
        owner = msg.sender;
        nftFactory = NFTFactory(_nftFactoryContract);
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

    function contentLength(string memory _content) private pure {
        if (bytes(_content).length < 1) revert Err.CONTENT_CANNOT_BE_EMPTY();
        if (bytes(_content).length > CONTENT_MAX_LENGTH) revert Err.CONTENT_TOO_LONG();
    }

    function nameLength(string memory _name) private pure {
        if (bytes(_name).length < 1) revert Err.NAME_CANNOT_BE_EMPTY();
        if (bytes(_name).length > NAME_MAX_LENGTH) revert Err.NAME_TOO_LONG();
    }

    function isLoggedIn() private view {
        if (!loggedIn[msg.sender]) revert Err.YOU_ARE_NOT_LOGGED_IN__LOG_IN_TO_CONTINUE();
    }

    function onlyGroupMember(bytes32 _groupId) private view {
        if (!groupMembers[msg.sender][_groupId]) revert Err.YOU_ARE_NOT_A_MEMBER_OF_THIS_GROUP();
    }

    function registerUser(string calldata _fullName, string calldata _username, string memory _nftName, string memory _nftSymbol) external {
        checkAddressZero();
        if (users[msg.sender].userId != address(0)) revert Err.ALREADY_REGISTERED__LOGIN();
        nameLength(_fullName);
        nameLength(_username);
        nameLength(_nftName);
        nameLength(_nftSymbol);

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
        isLoggedIn();

        loggedIn[msg.sender] = false;
        emit LoggedIn(msg.sender, true);

        return true;
    }

    function createPost(string memory _content, string memory _uri) external {
        checkAddressZero();
        isLoggedIn();
        contentLength(_content);
        if (bytes(_uri).length < 1) revert Err.URI_CANNOT_BE_EMPTY();

        bytes32 _postId = keccak256(abi.encodePacked(msg.sender, _content, block.timestamp));

        //will uncomment this when i switch to testnet
        // if (!nftFactory.mintNFT(msg.sender, _uri)) revert COULD_NOT_CREATE_NFT();

        Post storage _post = posts[_postId];
        _post.postId = _postId;
        _post.content = _content;
        _post.nftURI = _uri;
        _post.postTime = block.timestamp;

        //push post into necessary places
        feeds.push(_post);
        accounts[msg.sender].posts.push(_post);

        emit CreatePost(msg.sender, _postId, true);
    }

    function getPost(bytes32 _postId) external view returns (Post memory) {
        return posts[_postId];
    }

    function likeAndUnlikePost(bytes32 _postId) external {
        isLoggedIn();

        Post storage _post = posts[_postId];

        _post.likes = postLikes[msg.sender][_postId] ? (_post.likes - 1) : (_post.likes + 1);
        postLikes[msg.sender][_postId] = !postLikes[msg.sender][_postId];
    }

    function commentOnPost(bytes32 _postId, string memory _content) external {
        checkAddressZero();
        isLoggedIn();
        contentLength(_content);

        bytes32 commentId = keccak256(abi.encodePacked(msg.sender, _postId, _content));

        Comment storage _comment = comments[commentId];
        _comment.commenter = msg.sender;
        _comment.commentId = commentId;
        _comment.content = _content;
        _comment.commentTime = block.timestamp;

        posts[_postId].comments.push(_comment);
        // comments[commentId] = _comment;

        emit CommentOnPost(msg.sender, _postId, commentId);
    }

    function getPostComment(bytes32 _commentId) external view returns (Comment memory) {
        return comments[_commentId];
    }

    function likeAndUnlikeComment(bytes32 _postId, bytes32 _commentId) external {
        isLoggedIn();

        Comment storage _comment = comments[_commentId];
        _comment.likes = commentLikes[msg.sender][_commentId] ? (_comment.likes - 1) : (_comment.likes + 1);
        commentLikes[msg.sender][_commentId] = !commentLikes[msg.sender][_commentId];

        posts[_postId].comments.push(_comment);
    }

    function userCreateGroup(string memory _groupName) external {
        checkAddressZero();
        isLoggedIn();
        nameLength(_groupName);
        if (bytes(_groupName).length < 1) revert Err.GROUP_NAME_CANNOT_BE_EMPTY();

        uint256 _time = block.timestamp;
        bytes32 _groupId = keccak256(abi.encodePacked(msg.sender, _groupName, _time));
        Group storage _group = groups[_groupId];
        _group.groupId = _groupId;
        _group.groupName = _groupName;
        _group.groupOwner = msg.sender;
        _group.createAt = _time;

        // creator is added to the group
        _group.members.push(msg.sender);
        groupMembers[msg.sender][_groupId] = true;

        emit CreateGroup(msg.sender, _groupId, true);
    }

    function getGroup(bytes32 _groupId) external view returns (Group memory) {
        return groups[_groupId];
    }

    function usersJoinGroup(bytes32 _groupId) external {
        checkAddressZero();
        isLoggedIn();

        Group storage _group = groups[_groupId];

        groupMembers[msg.sender][_groupId] = true;
        _group.members.push(msg.sender);
    }

    function membersPostOnGroup(bytes32 _groupId, string memory _content, string memory _uri) external {
        isLoggedIn();
        onlyGroupMember(_groupId);
        contentLength(_content);

        uint256 _time = block.timestamp;

        bytes32 _postId = keccak256(abi.encodePacked(msg.sender, _content, _time));

        //will uncomment this in testnet
        //if (!nftFactory.mintNFT(msg.sender, _uri)) revert COULD_NOT_CREATE_NFT();

        //    Post storage _post =  postsInGroup[_groupId][_postId];
        Post storage _post = posts[_postId];
        _post.postId = _postId;
        _post.content = _content;
        _post.nftURI = _uri;
        _post.postTime = _time;

        Group storage _group = groups[_groupId];
        _group.groupPosts.push(_post);

        emit PostOnGroup(msg.sender, _groupId, _postId);
    }

    function memberLikesAndUnlikePostOnGroup(bytes32 _groupId, bytes32 _postId) external {
        isLoggedIn();
        onlyGroupMember(_groupId);

        Post storage _post = posts[_postId];
        _post.likes = postLikes[msg.sender][_postId] ? (_post.likes - 1) : (_post.likes + 1);
        postLikes[msg.sender][_postId] = !postLikes[msg.sender][_postId];
    }

    function membersCommentOnPostOnGroup(bytes32 _groupId, bytes32 _postId, string memory _content) external {
        checkAddressZero();
        isLoggedIn();
        onlyGroupMember(_groupId);
        contentLength(_content);

        bytes32 commentId = keccak256(abi.encodePacked(msg.sender, _postId, _content));

        Comment storage _comment = comments[commentId];
        _comment.commenter = msg.sender;
        _comment.commentId = commentId;
        _comment.content = _content;
        _comment.commentTime = block.timestamp;

        posts[_postId].comments.push(_comment);

        emit CommentOnGroupPost(msg.sender, _groupId, _postId, commentId);
    }

    function membersLikeCommentOnPostsOnGroup(bytes32 _groupId, bytes32 _postId, bytes32 _commentId) external {
        checkAddressZero();
        isLoggedIn();
        onlyGroupMember(_groupId);

        Post storage _post = posts[_postId];
        _post.likes = commentLikes[msg.sender][_commentId] ? (_post.likes - 1) : (_post.likes + 1);
        commentLikes[msg.sender][_commentId] = !commentLikes[msg.sender][_commentId];
    }
}



