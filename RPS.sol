pragma solidity ^0.8.0;

//SPDX-License-Identifier: MIT

contract RockPaperScissors {
   bytes32 rockHash = keccak256(abi.encodePacked("rock"));
   bytes32 paperHash = keccak256(abi.encodePacked("paper"));
   bytes32 scissorsHash = keccak256(abi.encodePacked("scissors"));
   uint256 public playsCount;
   enum DuelStage {
      Respond,
      Show,
      Winner
    }

   struct Duel {
      bool active;
      address player1;
      address player2;
      uint256 bet;
      DuelStage duelStage;
      bytes32 play1;
      bytes32 play2;
      bytes32 show1;
      bytes32 show2;
      uint256 duelTime;
      string winner;
      address winnerAddress;
    }

  mapping(bytes32 => Duel) public duel;
  mapping(address => bytes32) public activeDuel;
  event GameCreated(address creator, uint gameNumber, uint bet);
  
  modifier isDuel(bytes32 duelCode, DuelStage duelStage) {
      require(duel[duelCode].active == true, 'No duel detected');
      require(
          duel[duelCode].player1 == msg.sender ||
          duel[duelCode].player2 == msg.sender,
          'Must be a duelist'
        );
      require(
          duel[duelCode].duelStage == duelStage,
          'Duel not in correct phase'
        );
        _;
    }
    
  function createGame(
      address rival,
      string memory choice,
      string memory password
      ) public payable returns (bytes32) {
      bytes32 uniqueness = bytes32(block.timestamp);
      bytes32 duelCode = bytes32(
        keccak256(abi.encodePacked(uniqueness, msg.sender))
      );
    require(msg.value >= 0, "Must bet");
      require(!duel[duelCode].active, "This code exists");
      require(msg.sender != rival, "You are not a fair rival to yourself");
      
      duel[duelCode].active = true;
      duel[duelCode].player1 = msg.sender;
      duel[duelCode].player2 = rival;
      address gameAddress = address(this);
      payable(gameAddress).transfer(msg.value);

      duel[duelCode].bet = msg.value;
      duel[duelCode].duelStage = DuelStage.Respond;
      activeDuel[msg.sender] = duelCode;

      bytes32 myChoice = keccak256(abi.encodePacked(choice));

      require(
        myChoice == rockHash ||
        myChoice == paperHash ||
        myChoice == scissorsHash,
          "'rock', 'paper' or 'scissors' are the only choices"
        );
      
      bytes32 hashedChoice = keccak256(abi.encodePacked(choice, password));
      duel[duelCode].play1 = hashedChoice;
      playsCount++;
      
      emit GameCreated(msg.sender, playsCount, msg.value);
      
      return duelCode;
  }
      function respond(
        address rival,
        string memory choice,
        string memory password
    ) public isDuel(activeDuel[rival], DuelStage.Respond) {
        bytes32 duelCode = activeDuel[rival];
        bytes32 respondChoice = keccak256(abi.encodePacked(choice));
        uint256 preBet = duel[duelCode].bet;
        address gameAddress = address(this);
        payable(gameAddress).transfer(preBet);
        duel[duelCode].bet = (preBet * 2 );
        require(
            respondChoice == rockHash ||
                respondChoice == paperHash ||
                respondChoice == scissorsHash,
            "'rock', 'paper' or 'scissors' are the only choices"
        );

        bytes32 hashedChoice2 = keccak256(abi.encodePacked(choice, password));
        duel[duelCode].play2 = hashedChoice2;
        duel[duelCode].duelStage = DuelStage.Show;
    }

    function reveal(address challenger, string memory password)
        public
        isDuel(activeDuel[challenger], DuelStage.Show)
    {
        bytes32 duelCode = activeDuel[challenger];

        if (duel[duelCode].player1 == msg.sender) {
            require(duel[duelCode].show1 == 0, 'Already shown');
        } else {
            require(duel[duelCode].show2 == 0, 'Already shown');
        }

        bytes32 isRock = keccak256(abi.encodePacked('rock', password));
        bytes32 isPaper = keccak256(abi.encodePacked('paper', password));
        bytes32 isScissors = keccak256(abi.encodePacked('scissors', password));

        bytes32 myPlay = (duel[duelCode].player1 == msg.sender)
            ? duel[duelCode].play1
            : duel[duelCode].play2;

        require(
            isRock == myPlay || isPaper == myPlay || isScissors == myPlay,
            "This doesn't match a response"
        );

        string memory choice;
        if (isRock == myPlay) {
            choice = 'rock';
        } else if (isPaper == myPlay) {
            choice = 'paper';
        } else {
            choice = 'scissors';
        }

        if (duel[duelCode].player1 == msg.sender) {
          duel[duelCode].show1 = keccak256(abi.encodePacked(choice));
        } else {
          duel[duelCode].show2 = keccak256(abi.encodePacked(choice));
        }

        if (duel[duelCode].show1 != 0 && duel[duelCode].show2 != 0) {
          duel[duelCode].winner = duelWinner(
                duel[duelCode].show1,
                duel[duelCode].show2
            );
            duel[duelCode].duelStage = DuelStage.Winner;
        if (keccak256(abi.encodePacked(duel[duelCode].winner)) == keccak256(abi.encodePacked("Draw"))) {
          duel[duelCode].winnerAddress = address(0);
          uint256 equalRwrd = (duel[duelCode].bet)/2;
          payable(duel[duelCode].player1).transfer(equalRwrd);
          payable(duel[duelCode].player2).transfer(equalRwrd);
        } else if (keccak256(abi.encodePacked(duel[duelCode].winner)) == keccak256(abi.encodePacked("Player1"))) {
            duel[duelCode].winnerAddress = duel[duelCode].player1;
            payable(duel[duelCode].player1).transfer(duel[duelCode].bet);
        } else {
            duel[duelCode].winnerAddress = duel[duelCode].player2;
            payable(duel[duelCode].player2).transfer(duel[duelCode].bet);
        }
        } else {
            duel[duelCode].duelTime = block.timestamp + 3 minutes;
        }

    }

    function determineDefaultWinner(address challenger)
        public
        isDuel(activeDuel[challenger], DuelStage.Show)
    {
        bytes32 duelCode = activeDuel[challenger];
        require(
            duel[duelCode].duelTime < block.timestamp,
            "Still can't pick a winner"
        );
        duel[duelCode].winner = duelWinner(
            duel[duelCode].show1,
            duel[duelCode].show2
        );
        duel[duelCode].duelStage = DuelStage.Winner;
        if (keccak256(abi.encodePacked(duel[duelCode].winner)) == keccak256(abi.encodePacked("Draw"))) {
            duel[duelCode].winnerAddress = address(0);
        } else if (keccak256(abi.encodePacked(duel[duelCode].winner)) == keccak256(abi.encodePacked("Player1"))) {
            duel[duelCode].winnerAddress = duel[duelCode].player1;
        } else {
            duel[duelCode].winnerAddress = duel[duelCode].player2;
        }
        if (duel[duelCode].winnerAddress == duel[duelCode].player1) {
        payable(duel[duelCode].player1).transfer(duel[duelCode].bet);

        } else if (duel[duelCode].winnerAddress == address(0)) {
          uint256 equalRwrd = (duel[duelCode].bet)/2;
          payable(duel[duelCode].player1).transfer(equalRwrd);
          payable(duel[duelCode].player2).transfer(equalRwrd);
        } else {
          payable(duel[duelCode].player2).transfer(duel[duelCode].bet);
        }
    }

    function duelWinner(bytes32 choice1, bytes32 choice2)
        internal
        view
        returns (string memory winner)
    {
        if (choice1 != 0 && choice2 != 0) {
            if (choice1 == choice2) {
                string memory result = 'Draw';
                return result;
            }
            if (choice1 == rockHash) {
                if (choice2 == scissorsHash) {
                    string memory result = 'Player1';
                    return result;
                } else {
                    string memory result = 'Player2';
                    return result;
                }
            } else if (choice1 == paperHash) {
                if (choice2 == rockHash) {
                    string memory result = 'Player1';
                    return result;
                } else {
                    string memory result = 'Player2';
                    return result;
                }
            } else {
                if (choice2 == paperHash) {
                    string memory result = 'Player1';
                    return result;
                } else {
                    string memory result = 'Player2';
                    return result;
                }
            }
        } else if (choice1 != 0) {
            string memory result = 'Player1';
            return result;
        } else {
            string memory result = 'Player2';
            return result;
        }
    }
    
    function leaveGame() isDuel(activeDuel[msg.sender], DuelStage.Respond)public {
      bytes32 duelCode = activeDuel[msg.sender];
      uint256 firstBet = duel[duelCode].bet;
      duelCode = bytes32(0);
      payable(duel[duelCode].player1).transfer(firstBet);
       
    }
}
