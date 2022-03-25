// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract UtilitarianEconomy {
    // Initializing all variables relating to the Utilitarian Economy
    address public committee;
    uint[2] private allocation_estimating;
    uint[2] private allocation_voting;
    uint[2] private reward_estimation;
    uint[2] private punishment_estimation;
    uint[2] private ratio_estimating_voting;
    uint[2] private reward_accusation;
    uint[2] private punishment_accusation;
    uint private estimating_time;
    uint private voting_time;
    
    // Initializing properties of a person
    struct Person {
        bool initialized;
        int balance; 
        bool entitlement;
        bool suspended;
        uint end_suspension;
        uint[2][] transaction_estimator;
        uint[2][] transaction_voter;
    }

    // Initializing properties of an estimation contract
    struct Estimation {
        string description;
        address estimator;
        address[] contributors;
        address[] affected;
        int value;
        string template;
        uint votes;
        address[] voters;
    }

    // Initializing properties of the cycle: the process from estimating to voting to settling
    struct Cycle {
        Estimation[] estimations;
        int estimation_value;
        address estimator;
        address[] voters;
        uint[] indexes;
        address[] allocated_estimators;
        address[] allocated_voters_estimators;
        bool estimating_running;
        bool voting_running;
        uint timestamp_estimating;
        uint timestamp_voting;
    }
    
    // Initializing properties of a unique transaction that can house multiple estimation contracts
    struct Transaction {
        uint id;
        Cycle[] cycles;
    }

    // Initializing properties of an accusation
    struct Accusation {
        string accusation;
        address accuser;
        address[] offenders;
        address[] affected;
    }
    
    // Mapping people to addresses so that
    mapping(address => Person) private people;
    mapping(address => mapping(address => bool)) private delegates;
    
    // Making an array of transactions to help in the estimation process
    Transaction[] public transactions;
    Accusation[] public accusations;
    address[] private initialized;
    
    // When calling the contract, the variables' initial values will have to be specified
    constructor(uint[2] memory _allocation_estimating, uint[2] memory _allocation_voting, uint[2] memory _reward_estimation, uint[2] memory _punishment_estimation, uint[2] memory _ratio_estimating_voting, uint[2] memory _reward_accusation, uint[2] memory _punishment_accusation) {
        committee = msg.sender;
        allocation_estimating = _allocation_estimating;
        allocation_voting = _allocation_voting;
        reward_estimation = _reward_estimation;
        punishment_estimation = _punishment_estimation;
        reward_accusation = _reward_accusation;
        punishment_accusation = _punishment_accusation;
        ratio_estimating_voting = _ratio_estimating_voting;
    }

    // Returns the variable values to the public
    function return_constants() public view returns(uint[2] memory, uint[2] memory, uint[2] memory, uint[2] memory, uint[2] memory, uint[2] memory, uint[2] memory) {
        require(
            msg.sender == committee,
            "Only the committee can call this function."
        );
        return (allocation_estimating, allocation_voting, reward_estimation, punishment_estimation, ratio_estimating_voting, reward_accusation, punishment_accusation);
    }

    // Lets the committee change the allocation variables
    function change_allocation(uint[2] memory _allocation_estimating, uint[2] memory _allocation_voting) public {
        require(
            msg.sender == committee,
            "Only the committee can change constants."
        );
        allocation_estimating = _allocation_estimating;
        allocation_voting = _allocation_voting;
    }

    // Lets the committee change the evaluation variables related to the estimation process
    function change_evaluation_estimation(uint[2] memory _reward_estimation, uint[2] memory _punishment_estimation, uint[2] memory _ratio_estimating_voting) public {
        require(
            msg.sender == committee,
            "Only the committee can change constants."
        );
        reward_estimation = _reward_estimation;
        punishment_estimation = _punishment_estimation;
        ratio_estimating_voting = _ratio_estimating_voting;
    }

    // Lets the committee change the evaluation variables related to the accusation process
    function change_evaluation_accusation(uint[2] memory _reward_accusation, uint[2] memory _punishment_accusation) public {
        require(
            msg.sender == committee,
            "Only the committee can change constants."
        );
        reward_accusation = _reward_accusation;
        punishment_accusation = _punishment_accusation;
    }
    
    // Lets the committee initialize accounts
    function initialize_account(address _person, int _balance, bool _entitlement) public {
        require(
            msg.sender == committee,
            "Only the committee can initialize accounts."
        );
        require(
            !people[_person].initialized,
            "The account has already been initialized."
        );
        initialized.push(_person);
        people[_person].initialized = true;
        people[_person].balance = _balance;
        people[_person].entitlement = _entitlement;
    }

    // Lets the committee change the entitlement to the estimation process of individuals having a registered account
    function entitle(address _person, bool _entitlement) public {
        require(
            msg.sender == committee,
            "Only the committee is authorised to entitle people or not."
        );
        require(
            people[_person].initialized,
            "The account has not yet been initialized."
        );
        people[_person].entitlement = _entitlement;
    }
    
    // Lets the committee suspend individuals with an initialized account from the estimation process
    function suspend(address _person, uint _duration) public {
        require(
            msg.sender == committee,
            "Only the committee can suspend people from the estimation process."
        );
        require(
            people[_person].initialized,
            "The account has not yet been initialized."
        );
        people[_person].suspended = true;
        people[_person].end_suspension = block.timestamp + _duration;
    }

    // Lets the committee remove the suspension of an individual with an initialized account
    function force_free(address _person) public {
        require(
            msg.sender == committee,
            "Only the committee can force_free people from the estimation process."
        );
        require(
            people[_person].initialized,
            "The account has not yet been initialized."
        );
        people[_person].suspended = false;
    }
    
    // Lets the anybody check if the initialized person provided is suspended and set them 'free' when applicable
    function check_free(address _person) public returns (string memory) {
        require(
            people[_person].initialized,
            "The account has not yet been initialized."
        );
        require(
            people[_person].suspended,
            "The account is not currently listed as suspended."
        );

        // If the person is not anymore suspended, register it accordingly
        if (people[_person].end_suspension < block.timestamp) {
            people[_person].suspended = false;
            return "The account has been successfully been listed as free.";
        } else {
            return "The account is not yet permitted to be freed.";
        }
    }
    
    // Returns information on the submitted address per person either to the person themself or the committee
    function return_person(address _person) public view returns (Person memory) {
         require(
            msg.sender == _person || msg.sender == committee,
            "Only you or the commitee can request your information."
        );
        Person memory person = people[_person];
        return person;
    }
    
    // Returns the people the person has delegated to transfer funds on their behalf to either the person themself or the committee
    function return_delegate(address _person, address _delegate) public view returns (bool) {
         require(
            msg.sender == _person || (delegates[_person][msg.sender] && msg.sender == _delegate),
            "Only oneself or their delegates can request this information."
        );
        return delegates[_person][_delegate];
    }
    
    // Delegates or de-delegates the person specified if the caller has permission to do so
    function delegate(address _person, address _delegate, bool _delegated) public {
        require(
            msg.sender == _person || (delegates[_person][msg.sender] && msg.sender == _delegate),
            "Only oneself and their delegates can call this function."
        );
        delegates[_person][_delegate] = _delegated;
    }
    
    // Transfers funds from and to the address specified if the caller has permission to do so
    function transfer(address _from, address _to, int _amount) public returns (string memory) {
        require(
            msg.sender == _from || delegates[_from][msg.sender] || msg.sender == committee,
            "Only oneself, their delegates or the committee can call this function."
        );
        require(
            _to != committee,
            "The committee can't receive money."
        );
        require(
            people[_to].initialized,
            "The account you want to send funds to is not yet initialised."
        );
        if (_amount > 0) {
            people[_from].balance -= _amount;
            people[_to].balance += _amount;
            return "Transfer of funds processed successfully.";
        } else {
            return "Transfer amount must be a positive integer.";
        }
    }
    
    // Begin a new estimation cycle either for a new or existing transaction by starting out with an estimation
    function post_estimate(uint _id, string memory _description, address[] memory _contributors, address[] memory _affected, int _value, string memory _template) public {
        require(_value != 0,
        "Value of the externality estimation must be non-zero");
        require(msg.sender != committee, "The committee can't estimate externalities.");
        uint id;
        uint length;
        if (_id == 0) {
          id = transactions.length;
          length = 0;
        } else {
          length = transactions[id].cycles.length;
          id = _id;
          require(keccak256(abi.encodePacked(transactions[id].cycles[length - 1].estimations[0].description)) == keccak256(abi.encodePacked(_description)),
          "The description must match that of the original estimation of this transaction.");
          require(keccak256(abi.encodePacked(transactions[id].cycles[length - 1].estimations[0].contributors)) == keccak256(abi.encodePacked(_contributors)),
          "The contributors must match those of the original estimation of this transaction.");
          require(keccak256(abi.encodePacked(transactions[id].cycles[length - 1].estimations[0].affected)) == keccak256(abi.encodePacked(_affected)),
          "The affected must match those of the original estimation of this transaction.");
        }
        Estimation storage estimation = transactions[id].cycles[length].estimations[0];
        estimation.description = _description;
        estimation.estimator = msg.sender;
        estimation.contributors = _contributors;
        estimation.affected = _affected;
        estimation.value = _value;
        estimation.template = _template;
        Cycle storage cycle = transactions[id].cycles[length];
        cycle.estimating_running = true;
        cycle.timestamp_estimating = uint(block.timestamp);
        allocate_estimators(id, length, transactions[id].cycles[length]);
    }
    
    // Allocating estimators that are permitted to add their estimations to the new cycle of a particular transaction estimation
    function allocate_estimators(uint _transaction_id, uint _cycle_id, Cycle storage _cycle) private {
        uint nr_estimators;

        // Calculating the number of estimators to allocate to the estimation cycle
        if (_cycle.estimations[0].value > 0) {
            nr_estimators = uint(_cycle.estimations[0].value) * allocation_estimating[0] / 10 ** allocation_estimating[1] + 1;
        } else {
            nr_estimators = uint(_cycle.estimations[0].value * -1) * allocation_estimating[0] / 10 ** allocation_estimating[1] + 1;
        }
        uint[] memory indexes;
        address[] memory chosen_addresses;
        for (uint i = 0; i < nr_estimators; i++) {

            // Pseudo-randomly picking a group of people from the list of initialized people
            uint det_random_index = uint(keccak256(abi.encodePacked(block.timestamp, initialized.length))) % initialized.length;
            bool in_chosen = false;
            for (uint j = 0; j < indexes.length; j++) {
                if (det_random_index == indexes[j] || initialized[j] == msg.sender) {
                    in_chosen = true;
                    break;
                }
            }
            if (in_chosen) {
              i--;
            } else {

              // Registering the allocation of estimator to the respective people
              people[initialized[det_random_index]].transaction_estimator.push([_transaction_id, _cycle_id]);
              uint length = indexes.length;
              indexes[length] = det_random_index;
              chosen_addresses[length] = initialized[det_random_index];
            }           
        }
        _cycle.allocated_estimators = chosen_addresses;
        _cycle.indexes = indexes;
        allocate_voters(_transaction_id, _cycle_id, _cycle);
    }
    
    // Function allocated people can call to add their estimation to the cycle
    function estimate(uint _transaction_id, uint _cycle_id, int _value, string memory _template) public {
      Cycle storage cycle = transactions[_transaction_id].cycles[_cycle_id];
      require(cycle.estimating_running = true, "The estimating part of the cycle must be active.");

      // Check if the estimation process is still running
      if (cycle.timestamp_estimating + estimating_time < block.timestamp) {
        cycle.estimating_running = false;
        cycle.voting_running = true;
        cycle.timestamp_voting = uint(block.timestamp);
      }
      // Return function if not
      require(cycle.estimating_running = true, "The estimating time has ran out for this cycle.");
      bool in_allocated;

      // Check if caller of function is registered as an estimator for this function
      for (uint i = 0; i < people[msg.sender].transaction_estimator.length; i++) {
          in_allocated = true;
        if (people[msg.sender].transaction_estimator[i][0] != _transaction_id) {
            in_allocated = false;
        } else if (people[msg.sender].transaction_estimator[i][0] != _transaction_id) {
            in_allocated = false;
        }
          if (in_allocated) {
            delete people[msg.sender].transaction_estimator[i];
            break;
          }
      }
      require(in_allocated, "One must be allocated to this estimation contract.");

      // Add estimation to respective cycle
      uint length = cycle.estimations.length;
      Estimation storage estimation = cycle.estimations[length];
      estimation.estimator = msg.sender;
      estimation.value = _value;
      estimation.template = _template;
    }

    // Allocate voters to the new estimation contract
    function allocate_voters(uint _transaction_id, uint _cycle_id, Cycle storage _cycle) private {

      // Calculating the number of voters to allocate to the estimation cycle
      uint nr_voters;
        if (_cycle.estimations[0].value > 0) {
            nr_voters = uint(_cycle.estimations[0].value) * allocation_voting[0] / 10 ** allocation_voting[1] + 1;
        } else {
            nr_voters = uint(_cycle.estimations[0].value * -1) * allocation_voting[0] / 10 ** allocation_voting[1] + 1;
        }
        uint[] memory indexes = transactions[_transaction_id].cycles[_cycle_id].indexes;
        address[] memory chosen_addresses = transactions[_transaction_id].cycles[_cycle_id].allocated_estimators;

        // Pseudo-randomly picking a group of people from the list of initialized people
        for (uint i = 0; i < nr_voters; i++) {
            uint det_random_index = uint(keccak256(abi.encodePacked(block.timestamp, initialized.length))) % initialized.length;
            bool in_chosen = false;
            for (uint j = 0; j < indexes.length; j++) {
                if (det_random_index == indexes[j] || initialized[j] == msg.sender) {
                    in_chosen = true;
                    break;
                }
            }
            if (in_chosen) {
              i--;
            } else {

              // Registering the allocation of estimator to the respective people
              people[initialized[det_random_index]].transaction_voter.push([_transaction_id, _cycle_id]);
              uint length = indexes.length;
              indexes[length] = det_random_index;
              chosen_addresses[length] = initialized[det_random_index];
            }           
        }
        _cycle.allocated_voters_estimators = chosen_addresses;
        _cycle.indexes = indexes;
    }

    // Function the allocated people can call to cast their vote
    function vote(uint _transaction_id, uint _cycle_id, uint _estimation_id) public {
      Cycle storage cycle = transactions[_transaction_id].cycles[_cycle_id];
      require(cycle.estimating_running = false, "The estimating part of the cycle must be active.");
      require(cycle.voting_running = true, "The voting part of the cycle must be active.");
      // Check if the voting process is still running
      if (cycle.timestamp_voting + voting_time < block.timestamp) {
        cycle.voting_running = false;
        settle_contract(_transaction_id, _cycle_id);
      }

      // Return function if not
      require(cycle.voting_running = true, "The voting time has ran out for this cycle.");
      uint index;
      bool in_allocated;

      // Check if caller of function is registered as a voter for this function
      for (uint i = 0; i < people[msg.sender].transaction_voter.length; i++) {
          in_allocated = true;    
          if (people[msg.sender].transaction_voter[i][0] != _transaction_id) {
            in_allocated = false;
          } else if (people[msg.sender].transaction_voter[i][1] != _cycle_id) {
            in_allocated = false;
          }
          if (in_allocated) {
              delete people[msg.sender].transaction_voter[i];
              index = i;
              break;
          }
      }
      require(in_allocated, "One must be allocated to vote for the cycle of this contract.");
      delete people[msg.sender].transaction_voter[index];

      // Add vote to respective estimation
      cycle.estimations[_estimation_id].votes++;
      cycle.estimations[_estimation_id].voters.push(msg.sender);
    }

    // Pay out new successful estimator and voters and settle for the difference in previous successful estimations
    function settle_contract(uint _transaction_id, uint _cycle_id) private {
    Cycle storage cycle = transactions[_transaction_id].cycles[_cycle_id];
      uint best_vote;
      uint max_votes = 0;

      // Count votes
      for (uint i = 0; i < cycle.estimations.length; i++) {
        if (cycle.estimations[i].votes > max_votes) {
          max_votes = cycle.estimations[i].votes;
          best_vote = i;
        }
      }
      cycle.estimation_value = cycle.estimations[best_vote].value;
      cycle.estimator = cycle.estimations[best_vote].estimator;
      cycle.voters = cycle.estimations[best_vote].voters;

      // Looping over all cycles of the transaction
      for (uint i = 0; i < transactions[_transaction_id].cycles.length; i++) {
        int diff_offset; 

        // Find the change in the offset for the successful estimation in every cycle
        if (transactions[_transaction_id].cycles.length > 1) {
          int new_offset = transactions[_transaction_id].cycles[_cycle_id].estimation_value - transactions[_transaction_id].cycles[i].estimation_value;
          if (new_offset < 0) {
            new_offset *= -1;
          }
          int old_offset = transactions[_transaction_id].cycles[_cycle_id - 1].estimation_value - transactions[_transaction_id].cycles[i].estimation_value;
          if (old_offset < 0) {
            old_offset *= -1;
          }
          diff_offset = old_offset - new_offset;
        } else {
          diff_offset = transactions[_transaction_id].cycles[i].estimation_value;
          if (diff_offset < 0) {
            diff_offset *= -1;
          }
        }
        address estimator = transactions[_transaction_id].cycles[i].estimator;
        address[] storage voters = transactions[_transaction_id].cycles[i].voters;
        int sum;
        int pun_rew_e;
        int pun_rew_v;
        if (i == transactions[_transaction_id].cycles.length - 1) {

          // Calculate reward for new estimator and their voters
          pun_rew_e = int((uint(diff_offset) * reward_estimation[0] / reward_estimation[1] ** 10) * ratio_estimating_voting[0] / ratio_estimating_voting[1] ** 10);
          pun_rew_v = int(uint(diff_offset) * reward_estimation[0] / reward_estimation[1] ** 10) / int(cycle.voters.length);
        } else {

          // Calculate punishment for previous estimators and voters
          pun_rew_e = int((uint(diff_offset) * punishment_estimation[0] / punishment_estimation[1] ** 10) * ratio_estimating_voting[0] / ratio_estimating_voting[1] ** 10);
          pun_rew_v = int(uint(diff_offset) * punishment_estimation[0] / punishment_estimation[1] ** 10) / int(cycle.voters.length);
        }

        // Settle reward or punishment for the successful estimator
        people[estimator].balance += pun_rew_e;
        sum += pun_rew_v;

        // Settle reward or punishment for the successful voters
        for (uint j = 0; j < voters.length; j++) {
          people[voters[j]].balance += pun_rew_v;
          sum += pun_rew_v;
        }

        // Evening out the payment or punishment to estimator and voters
        address[] storage contributors = transactions[_transaction_id].cycles[i].estimations[best_vote].contributors;
        uint nr_contributors = contributors.length;
        int share = int(uint(sum) / nr_contributors);
        int remainder = sum % share;      
        for (uint j = 0; j < nr_contributors; j++) {
          people[contributors[j]].balance -= share;
        }
        address person = cycle.estimator;
        people[person].balance += remainder;

        // Actually settling the externality amount
        if (transactions[_transaction_id].cycles.length > 1) {
          int new_offset = transactions[_transaction_id].cycles[_cycle_id].estimation_value - transactions[_transaction_id].cycles[i].estimation_value;
          int old_offset = transactions[_transaction_id].cycles[_cycle_id - 1].estimation_value - transactions[_transaction_id].cycles[i].estimation_value;
          diff_offset = new_offset - old_offset;
        } else {
          diff_offset = transactions[_transaction_id].cycles[i].estimation_value;
        }
        sum = 0;
        share = diff_offset / int(nr_contributors);
        for (uint j = 0; j < nr_contributors; j++) {
            people[contributors[j]].balance += share;
            sum += share;
        }
        address[] storage affected = transactions[_transaction_id].cycles[i].estimations[best_vote].affected;
        uint nr_affected = affected.length;
        share = sum / int(nr_affected);
        remainder = sum % share;
        for (uint j = 0; j < nr_affected; j++) {
            people[affected[j]].balance -= share;
        }
        uint det_random_index = uint(keccak256(abi.encodePacked(block.timestamp, nr_affected))) % nr_affected;
        people[affected[det_random_index]].balance -= remainder;
      }
    }

    // Adding an accusation to the list thereof
    function accuse(string memory _accusation, address[] memory _offenders, address[] memory _affected) public {
        Accusation memory accusation;
        accusation.accusation = _accusation;
        accusation.accuser = msg.sender;
        accusation.offenders = _offenders;
        accusation.affected = _affected;
        accusations.push(accusation);
    }

    // Can be called by committee to settle an accusation
    function judge(uint _accusation_index, int _rew_pun) public {
        require(msg.sender == committee, "Only the committee can handle estimations.");
        Accusation storage accusation = accusations[_accusation_index];
        int rew_pun = _rew_pun * int(reward_accusation[0]) / int(reward_accusation[1]) ** 10;
        uint length = accusation.offenders.length;
        int share = rew_pun / int(length);
        int remainder = rew_pun % share;
        for (uint i = 0; i < length; i++) {
            people[accusation.offenders[i]].balance -= share;
        }
        people[accusation.accuser].balance += rew_pun - remainder;
    }
}