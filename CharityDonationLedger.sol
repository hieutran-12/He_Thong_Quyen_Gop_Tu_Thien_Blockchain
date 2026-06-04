// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CharityDonationLedger {

    address public owner;
    uint256 public campaignCounter;

    struct Campaign {
        uint256 id;
        string name;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 spentAmount;
        bool isActive;
        uint256 createdAt;
    }

    struct Donation {
        address donor;
        uint256 amount;
        string message;
        uint256 timestamp;
        uint256 campaignId;
    }

    struct Expense {
        uint256 amount;
        string purpose;
        bytes32 evidenceHash;
        uint256 timestamp;
        address spender;
        uint256 campaignId;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Donation[]) public campaignDonations;
    mapping(uint256 => Expense[]) public campaignExpenses;
    mapping(address => uint256) public totalDonatedByAddress;

    event CampaignCreated(uint256 indexed campaignId, string name, uint256 targetAmount, uint256 timestamp);
    event DonationReceived(uint256 indexed campaignId, address indexed donor, uint256 amount, string message, uint256 timestamp);
    event ExpenseRecorded(uint256 indexed campaignId, uint256 amount, string purpose, bytes32 evidenceHash, uint256 timestamp);
    event CampaignClosed(uint256 indexed campaignId, uint256 totalRaised, uint256 totalSpent, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].isActive, "Campaign is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        campaignCounter = 0;
    }

    function createCampaign(string memory _name, string memory _description, uint256 _targetAmount) external onlyOwner returns (uint256 campaignId) {
        require(bytes(_name).length > 0, "Campaign name cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        campaignId = campaignCounter;
        campaigns[campaignId] = Campaign({
            id: campaignId,
            name: _name,
            description: _description,
            targetAmount: _targetAmount,
            raisedAmount: 0,
            spentAmount: 0,
            isActive: true,
            createdAt: block.timestamp
        });
        campaignCounter++;
        emit CampaignCreated(campaignId, _name, _targetAmount, block.timestamp);
    }

    function recordExpense(uint256 _campaignId, uint256 _amount, string memory _purpose, bytes32 _evidenceHash) external onlyOwner campaignExists(_campaignId) {
        require(_amount > 0, "Expense amount must be greater than 0");
        require(bytes(_purpose).length > 0, "Purpose cannot be empty");
        require(_evidenceHash != bytes32(0), "Evidence hash cannot be empty");
        Campaign storage c = campaigns[_campaignId];
        uint256 remainingBalance = c.raisedAmount - c.spentAmount;
        require(_amount <= remainingBalance, "Insufficient balance");
        campaignExpenses[_campaignId].push(Expense({
            amount: _amount,
            purpose: _purpose,
            evidenceHash: _evidenceHash,
            timestamp: block.timestamp,
            spender: msg.sender,
            campaignId: _campaignId
        }));
        c.spentAmount += _amount;
        emit ExpenseRecorded(_campaignId, _amount, _purpose, _evidenceHash, block.timestamp);
    }

    function closeCampaign(uint256 _campaignId) external onlyOwner campaignExists(_campaignId) campaignActive(_campaignId) {
        Campaign storage c = campaigns[_campaignId];
        c.isActive = false;
        emit CampaignClosed(_campaignId, c.raisedAmount, c.spentAmount, block.timestamp);
    }

    function donate(uint256 _campaignId, string memory _message) external payable campaignExists(_campaignId) campaignActive(_campaignId) {
        require(msg.value > 0, "Donation amount must be greater than 0");
        Campaign storage c = campaigns[_campaignId];
        campaignDonations[_campaignId].push(Donation({
            donor: msg.sender,
            amount: msg.value,
            message: _message,
            timestamp: block.timestamp,
            campaignId: _campaignId
        }));
        c.raisedAmount += msg.value;
        totalDonatedByAddress[msg.sender] += msg.value;
        emit DonationReceived(_campaignId, msg.sender, msg.value, _message, block.timestamp);
    }

    function getCampaignDetails(uint256 _campaignId) external view campaignExists(_campaignId) returns (uint256 id, string memory name, string memory description, uint256 targetAmount, uint256 raisedAmount, uint256 spentAmount, bool isActive, uint256 createdAt) {
        Campaign storage c = campaigns[_campaignId];
        return (c.id, c.name, c.description, c.targetAmount, c.raisedAmount, c.spentAmount, c.isActive, c.createdAt);
    }

    function getDonations(uint256 _campaignId) external view campaignExists(_campaignId) returns (Donation[] memory) {
        return campaignDonations[_campaignId];
    }

    function getExpenses(uint256 _campaignId) external view campaignExists(_campaignId) returns (Expense[] memory) {
        return campaignExpenses[_campaignId];
    }

    function getRemainingBalance(uint256 _campaignId) external view campaignExists(_campaignId) returns (uint256) {
        Campaign storage c = campaigns[_campaignId];
        return c.raisedAmount - c.spentAmount;
    }

    function getDonationCount(uint256 _campaignId) external view campaignExists(_campaignId) returns (uint256) {
        return campaignDonations[_campaignId].length;
    }

    function getExpenseCount(uint256 _campaignId) external view campaignExists(_campaignId) returns (uint256) {
        return campaignExpenses[_campaignId].length;
    }

    function getAllCampaigns() external view returns (Campaign[] memory) {
        Campaign[] memory result = new Campaign[](campaignCounter);
        for (uint256 i = 0; i < campaignCounter; i++) {
            result[i] = campaigns[i];
        }
        return result;
    }
}
