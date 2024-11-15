// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RentToOwn is ReentrancyGuard, Ownable {
    struct Agreement {
        address borrower;
        address lender;
        address nftContract;
        uint256 nftId;
        uint256 monthlyPayment;
        uint256 totalPrice;
        uint256 totalPaid;
        uint256 nextPaymentDue;
        bool isActive;
    }

    mapping(uint256 => Agreement) public agreements;
    uint256 public agreementCounter;

    event AgreementCreated(
        uint256 agreementId,
        address lender,
        address nftContract,
        uint256 nftId,
        uint256 monthlyPayment,
        uint256 totalPrice
    );
    event PaymentMade(uint256 agreementId, uint256 amount, uint256 remaining);
    event AgreementCompleted(uint256 agreementId, address newOwner);
    event AgreementDefaulted(uint256 agreementId);

    constructor(address initialOwner) Ownable(initialOwner) {}

    // Lender lists NFT for rent-to-own
    function listNFT(
        address _nftContract,
        uint256 _nftId,
        uint256 _monthlyPayment,
        uint256 _numberOfPayments
    ) external nonReentrant {
        require(_monthlyPayment > 0, "Payment must be greater than 0");
        require(_numberOfPayments > 0, "Number of payments must be greater than 0");

        // Transfer NFT to contract
        IERC721(_nftContract).transferFrom(msg.sender, address(this), _nftId);

        // Verify transfer was successful
        require(
            IERC721(_nftContract).ownerOf(_nftId) == address(this),
            "NFT transfer to contract failed"
        );

        uint256 totalPrice = _monthlyPayment * _numberOfPayments;
        uint256 agreementId = agreementCounter++;

        agreements[agreementId] = Agreement({
            borrower: address(0),
            lender: msg.sender,
            nftContract: _nftContract,
            nftId: _nftId,
            monthlyPayment: _monthlyPayment,
            totalPrice: totalPrice,
            totalPaid: 0,
            nextPaymentDue: 0,
            isActive: true
        });

        emit AgreementCreated(
            agreementId,
            msg.sender,
            _nftContract,
            _nftId,
            _monthlyPayment,
            totalPrice
        );
    }

    // Borrower starts the agreement with first payment
    function startAgreement(uint256 _agreementId) external payable nonReentrant {
        Agreement storage agreement = agreements[_agreementId];
        require(agreement.isActive, "Agreement not active");
        require(agreement.borrower == address(0), "Already has a borrower");
        require(msg.value == agreement.monthlyPayment, "Incorrect payment");

        agreement.borrower = msg.sender;
        agreement.nextPaymentDue = block.timestamp + 30 days;
        agreement.totalPaid = msg.value;

        // Transfer payment to lender
        payable(agreement.lender).transfer(msg.value);

        emit PaymentMade(
            _agreementId,
            msg.value,
            agreement.totalPrice - agreement.totalPaid
        );
    }

    // Make monthly payment
    function makePayment(uint256 _agreementId) external payable nonReentrant {
        Agreement storage agreement = agreements[_agreementId];
        require(agreement.isActive, "Agreement not active");
        require(msg.sender == agreement.borrower, "Not the borrower");
        require(msg.value == agreement.monthlyPayment, "Incorrect payment");
        require(block.timestamp <= agreement.nextPaymentDue, "Payment is late");

        agreement.totalPaid += msg.value;
        agreement.nextPaymentDue += 30 days;

        // Transfer payment to lender
        payable(agreement.lender).transfer(msg.value);

        emit PaymentMade(
            _agreementId,
            msg.value,
            agreement.totalPrice - agreement.totalPaid
        );

        // Check if fully paid
        if (agreement.totalPaid >= agreement.totalPrice) {
            agreement.isActive = false;
            // Only transfer NFT to borrower after full payment
            IERC721(agreement.nftContract).transferFrom(
                address(this),
                agreement.borrower,
                agreement.nftId
            );
            emit AgreementCompleted(_agreementId, agreement.borrower);
        }
    }

    // Handle default (can be called by lender)
    function handleDefault(uint256 _agreementId) external nonReentrant {
        Agreement storage agreement = agreements[_agreementId];
        require(agreement.isActive, "Agreement not active");
        require(msg.sender == agreement.lender, "Not the lender");
        require(block.timestamp > agreement.nextPaymentDue, "Not defaulted yet");

        // Transfer NFT back to lender
        IERC721(agreement.nftContract).transferFrom(
            agreement.borrower,
            agreement.lender,
            agreement.nftId
        );

        agreement.isActive = false;
        emit AgreementDefaulted(_agreementId);
    }

    // View remaining balance
    function getRemainingBalance(uint256 _agreementId) external view returns (uint256) {
        Agreement storage agreement = agreements[_agreementId];
        return agreement.totalPrice - agreement.totalPaid;
    }
}
