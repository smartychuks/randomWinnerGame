// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract RandomWinnerGame is VRFConsumerBase, Ownable {
    uint256 public fee; // amount of LINK to send with the request
    bytes32 public keyHash; // ID for public key for generate randomness

    address[] public players; //Address of pplayers
    uint8 maxPlayers;
    bool public gameStarted;
    uint entryFee;
    uint256 public gameId;

    // show when game is started
    event GameStarted(uint256 gameId, uint8 maxPlayers, uint256 entryFee);
    // show when someone joins the game
    event PlayerJoined(uint256 gameId, address player);
    // indicate when game ends
    event GameEnded(uint256 gameId, address winner, bytes32 requestId);

    constructor(address vrfCoordinator, address linkToken, bytes32 vrfKeyHash, uint256 vrfFee)
    VRFConsumerBase(vrfCoordinator, linkToken){
        keyHash = vrfKeyHash;
        fee = vrfFee;
        gameStarted = false;
    }

    // function to start the game
    function startGame(uint8 _maxPlayers, uint256 _entryFee) public onlyOwner {
        // Check if game was on already
        require(!gameStarted, "Game is currently running");
        delete players; // empty players array
        maxPlayers = _maxPlayers;
        gameStarted = true;
        entryFee = _entryFee;
        gameId += 1;
        emit GameStarted(gameId, maxPlayers, entryFee);
    }

    // function for when a user wants to enter the game
    function joinGame() public payable {
        // check if a game is running
        require(gameStarted, "Game has not yet been started");
        // Check if user is paying the correct entry fee
        require(msg.value == entryFee, "Value sent is not correct entryFee");
        // check if new user can still be added to the game
        require(players.length < maxPlayers, "Game is full");
        // add the user to player's list
        players.push(msg.sender);
        // if the player list is full, select the winner
        if(players.length == maxPlayers) {
            getRandomWinner();
        }
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal virtual override {
        // to make winner inder to start from 0 - players length-1
        uint256 winnerIndex = randomness % players.length;
        // get the winners address in array
        address winner = players[winnerIndex];
        //send the winner thier price
        (bool sent,) = winner.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
        // emit that game has ender
        emit GameEnded(gameId, winner, requestId);
        // reinitiaize the game
        gameStarted = false;
    }

    // function that starts the process of selecting winner
    function getRandomWinner() private returns (bytes32 requestId) {
        // check that contract has enough LINK to make request
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK in contract");
        // make a request to the vrfCoordinator
        return requestRandomness(keyHash, fee);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}