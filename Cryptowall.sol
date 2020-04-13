pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

contract Cryptowall {
  address public owner = msg.sender;
  uint public creationTime = now;
  mapping (address => uint) pendingWithdrawals;

  struct Writer {
    address writerAdr;
    string uid;
    uint128[] messageIds;
    string description;
    int8 level;
  }

  struct Message {
    string content;
    uint ts;
    address writer;
  }

  // Events

  event newUser(address writer, string uid);
  event newMessage(uint128 msgId);
  event newLevel(address writer, address by, int8 level);
  event newDescription(address writer);

  // writer address => writer info
  mapping(address => Writer) public writers;
  // msg id => msg
  mapping(uint128 => Message) public messages;

  // uid => user address
  mapping(string => address) identityLookup;
  // user seq => key in writers
  address[] writerLookup;

  uint128 msgCounter;

  constructor() public {
    msgCounter = 0;
  }

  /**
   * Modifiers
   */
  modifier onlyBy(address _account) {
    require(
      msg.sender == _account,
      "Sender not authorized."
    );
    _;
  }

  modifier costs(uint _amount) {
    require(
      msg.value >= _amount,
      "Not enough Ether provided."
    );
    _;
    pendingWithdrawals[owner] += _amount;
    if (msg.value > _amount)
        msg.sender.transfer(msg.value - _amount);
  }

  /**
   * Admin features
   */
  function changeOwner(address _newOwner) public onlyBy(owner) {
    owner = _newOwner;
  }

  function withdraw() public {
    uint amount = pendingWithdrawals[msg.sender];
    pendingWithdrawals[msg.sender] = 0;
    msg.sender.transfer(amount);
  }

  function levelToForUser(address usr, int8 level) public {
    require(writers[msg.sender].writerAdr != address(0), "user doesn't exist");
    require(writers[usr].writerAdr != address(0), "target user doesn't exist");

    Writer storage writer = writers[msg.sender];
    Writer storage target = writers[usr];

    bool hasPermission = owner == msg.sender ||
    (writer.level > target.level + 1 && writer.level > level + 1 &&
    (target.level - level < 3 || target.level - level > -3 ) );
    require(hasPermission, "not enough permission");

    target.level = level;
    emit newLevel(usr, msg.sender, level);
  }

  /**
   * User methods
   */
  function uidFromAddress() public view returns (string memory) {
    return writers[msg.sender].uid;
  }

  function register(string memory uid) payable public costs(10 finney) {
    register(uid, "");
  }

  function register(string memory uid, string memory description) payable public costs(10 finney) {
    require(identityLookup[uid] == address(0), "uid should not already taken");
    // one address per user
    require(writers[msg.sender].writerAdr == address(0), "one address can only have one account");
    // make sure size is right
    uint idLen = bytes(uid).length;
    require(idLen > 3 && idLen < 32, "id len is too short or too long");

    identityLookup[uid] = msg.sender;

    Writer storage writer = writers[msg.sender];
    writer.writerAdr = msg.sender;
    writer.uid = uid;
    writer.description = description;

    writerLookup.push(msg.sender);
    emit newUser(msg.sender, uid);
  }

  function changeDescription(string memory description) payable public costs(10 finney) {
    require(writers[msg.sender].writerAdr != address(0), "user should exist");
    writers[msg.sender].description = description;
    emit newDescription(msg.sender);
  }

  function getWriters() public view returns (Writer[] memory) {
    return getWriters(writerLookup.length, 0);
  }

  function getWriters(uint256 limit, uint48 offset) public view returns (Writer[] memory) {
    uint256 len = writerLookup.length;
    uint256 retLen = len;
    if (limit < len) {
      retLen = limit;
    }
    if (offset + retLen > len) {
      retLen = len - offset;
    }
    Writer[] memory ret = new Writer[](len);
    for(uint48 i = 0; i < len && i < retLen; i ++) {
      address adr = writerLookup[i];
      Writer memory writer = writers[adr];
      ret[i].writerAdr = writer.writerAdr;
      ret[i].uid = writer.uid;
      ret[i].description = writer.description;
      ret[i].level = writer.level;
    }
    return ret;
  }

  /**
   * Tweets methods
   */
  function write(string memory content) payable public costs(0.2 finney) {
    require(writers[msg.sender].writerAdr != address(0), "user should exist");
    Writer storage writer = writers[msg.sender];

    // write the message
    messages[msgCounter] = Message({
      content: content,
      ts: now,
      writer: msg.sender
      });

    // append it to writer's account
    writer.messageIds.push(msgCounter);

    emit newMessage(msgCounter);
    msgCounter ++;
  }

  function readById(uint128 id) public view returns (Message memory) {
    return messages[id];
  }

  function read(address adr, uint48 limit, uint48 offset) public view returns (Message[] memory) {
    Writer storage writer = writers[adr];
    uint256 len = writer.messageIds.length;
    uint256 retLen = len;
    if (limit < len) {
      retLen = limit;
    }
    if (offset + retLen > len) {
      retLen = len - offset;
    }
    Message[] memory msgs = new Message[](retLen);
    for(uint48 i = 0; i < len && i < retLen; i ++) {
      msgs[i] = messages[writer.messageIds[len - 1 - i - offset]];
    }
    return msgs;
  }

  function read(address adr) public view returns (Message[] memory) {
    Writer storage writer = writers[adr];
    uint256 len = writer.messageIds.length;
    Message[] memory msgs = new Message[](len);
    for(uint48 i = 0; i < len; i ++) {
      msgs[i] = messages[writer.messageIds[i]];
    }
    return msgs;
  }

  function read(string memory idt) public view returns (Message[] memory) {
    address idtAdr = identityLookup[idt];
    require(idtAdr != address(0), "not user for this id");
    return read(idtAdr);
  }

  function read() public view returns (Message[] memory) {
    return read(msg.sender);
  }

}