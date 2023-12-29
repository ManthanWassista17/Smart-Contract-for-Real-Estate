// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RealEstateContract {
    string public propertyName;
    address public primaryOwner;
    address public secondaryOwner;
    address public buyer;
    uint256 public price;
    uint256 public deposit;
    uint256 public escrowAmount;
    bool public isPropertyTransferred;
    bool public isInspectionPassed;
    bool public isDispute;
    bool public isContingencyMet;
    uint256 public deadline;
    uint256 public mortgageAmount;
    address public mortgageLender;
    string public propertyDescription;
    uint256 public propertyId;  // Add property ID

    enum State { Created, DepositPaid, InspectionPassed, MortgageApproved, ContingencyMet, Completed, DisputeResolved }

    State public state;

    modifier onlyOwner() {
        require(msg.sender == primaryOwner || msg.sender == secondaryOwner, "Only an owner can call this function.");
        _;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only the buyer can call this function.");
        _;
    }

    event PropertyTransferred(address indexed seller, address indexed buyer, uint256 price);
    event DepositPaid(address indexed buyer, uint256 amount);
    event InspectionPassed(address indexed buyer);
    event DisputeRaised(address indexed partyRaisingDispute);
    event DisputeResolved(bool disputeResolved);
    event MortgageApproved(address indexed lender, uint256 amount);
    event ContingencyMet();
    event EscrowReleased();

    constructor(
        address _secondaryOwner,
        string memory _description,
        string memory _propertyName,
        uint256 _propertyId  // Initialize property name and ID
    ) {
        primaryOwner = msg.sender;
        secondaryOwner = _secondaryOwner;
        propertyDescription = _description;
        propertyName = _propertyName;
        propertyId = _propertyId;
        state = State.Created;
    }

    function setPrice(uint256 _price) public onlyOwner {
        require(state == State.Created, "Price can only be set in Created state.");
        price = _price;
    }

    function setDeadline(uint256 _days) public onlyOwner {
        require(state == State.Created, "Deadline can only be set in Created state.");
        deadline = block.timestamp + (_days * 1 days);
    }

    function depositFunds() public onlyBuyer payable {
        require(state == State.Created, "Deposits can only be made in Created state.");
        require(msg.value == price / 10, "Deposit amount must be 10% of the property price.");
        deposit = msg.value;
        escrowAmount = msg.value;
        state = State.DepositPaid;
        emit DepositPaid(buyer, msg.value);
    }

    function passInspection() public onlyBuyer {
        require(state == State.DepositPaid, "Inspection can only be passed in DepositPaid state.");
        isInspectionPassed = true;
        state = State.InspectionPassed;
        emit InspectionPassed(buyer);
    }

    function raiseDispute() public onlyOwner {
        require(state != State.Completed && state != State.DisputeResolved, "Dispute can only be raised in active states.");
        isDispute = true;
        state = State.DisputeResolved;
        emit DisputeRaised(msg.sender);
    }

    function resolveDispute(bool disputeResolved) public onlyBuyer {
        require(state == State.DisputeResolved, "Dispute can only be resolved in DisputeResolved state.");
        state = disputeResolved ? State.Completed : State.DepositPaid;
        emit DisputeResolved(disputeResolved);
    }

    function approveMortgage(uint256 _mortgageAmount, address _mortgageLender) public onlyBuyer {
        require(state == State.DepositPaid, "Mortgage can only be approved in DepositPaid state.");
        mortgageAmount = _mortgageAmount;
        mortgageLender = _mortgageLender;
        escrowAmount = escrowAmount - _mortgageAmount;
        state = State.MortgageApproved;
        emit MortgageApproved(_mortgageLender, _mortgageAmount);
    }

    function meetContingency() public onlyBuyer {
        require(state == State.MortgageApproved, "Contingency can only be met in MortgageApproved state.");
        isContingencyMet = true;
        state = State.ContingencyMet;
        emit ContingencyMet();
    }

    function releaseEscrow() public onlyOwner {
        require(state == State.Completed, "Escrow can only be released in Completed state.");
        (bool sent, ) = primaryOwner.call{value: escrowAmount}("");
        require(sent, "Failed to release escrow to the seller.");
        state = State.DisputeResolved;
        emit EscrowReleased();
    }

    function transferProperty() public onlyBuyer {
        require(state == State.ContingencyMet, "Property can only be transferred in ContingencyMet state.");
        require(block.timestamp <= deadline, "Transaction deadline has passed.");
        require(isInspectionPassed, "Property cannot be transferred without passing inspection.");
        (bool sent, ) = primaryOwner.call{value: price - deposit}("");
        require(sent, "Failed to send funds to the seller.");
        buyer = msg.sender;
        isPropertyTransferred = true;
        state = State.Completed;
        emit PropertyTransferred(primaryOwner, buyer, price);
    }
}