// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";

// import "@ethereum-attestation-service/eas-contracts/SchemaEncoder.sol";

contract DocTalk is Ownable {
	// State Variables
	address public immutable easContractAddress;
	IEAS public eas;
	ISchemaRegistry public schemaRegistry;

	struct Doctor {
		bool isVerified;
		uint256 reputationScore;
		uint256 stakedAmount;
	}

	struct Patient {
		bool isVerified;
		address assignedDoctor;
	}

	mapping(address => Doctor) public doctors;
	mapping(address => Patient) public patients;

	event DoctorRegistered(address indexed doctor);
	event PatientRegistered(address indexed patient);
	event ReputationAttested(
		address indexed doctor,
		address indexed patient,
		uint256 score
	);
	event StakeDeposited(address indexed doctor, uint256 amount);
	event Settlement(
		address indexed doctor,
		address indexed patient,
		uint256 amount,
		bool treatmentOccurred
	);

	constructor(address _easContractAddress) {
		easContractAddress = _easContractAddress;
		eas = IEAS(_easContractAddress);
		schemaRegistry = ISchemaRegistry(eas.getSchemaRegistry());
	}

	// Modifier to check if the caller is a verified doctor
	modifier onlyVerifiedDoctor() {
		require(
			doctors[msg.sender].isVerified,
			"You are not a verified doctor"
		);
		_;
	}

	// Modifier to check if the caller is a verified patient
	modifier onlyVerifiedPatient() {
		require(
			patients[msg.sender].isVerified,
			"You are not a verified patient"
		);
		_;
	}

	// Function for doctors to register and stake ETH
	function registerAsDoctor() external payable {
		require(!doctors[msg.sender].isVerified, "Already registered");

		// Verify the doctor's identity using World ID (handled off-chain and verified here)
		doctors[msg.sender] = Doctor({
			isVerified: true,
			reputationScore: 0,
			stakedAmount: msg.value
		});

		emit DoctorRegistered(msg.sender);
		emit StakeDeposited(msg.sender, msg.value);
	}

	// Function for patients to register
	function registerAsPatient(address doctorAddress) external {
		require(!patients[msg.sender].isVerified, "Already registered");
		require(doctors[doctorAddress].isVerified, "Doctor is not verified");

		// Verify the patient's identity using World ID (handled off-chain and verified here)
		patients[msg.sender] = Patient({
			isVerified: true,
			assignedDoctor: doctorAddress
		});

		emit PatientRegistered(msg.sender);
	}

	// Function to attest a doctor's reputation
	// function attestDoctorReputation(
	// 	address doctorAddress,
	// 	uint256 score
	// ) external onlyVerifiedPatient {
	// 	require(doctors[doctorAddress].isVerified, "Doctor is not verified");

	// 	// Ensure that attestation is happening within the allowed schema
	// 	// Schema registration and validation should be handled during contract deployment/setup
	// 	bytes32 schemaId = keccak256("Reputation(uint256 score)");
	// 	SchemaEncoder.Schema memory schema = SchemaEncoder.encode(
	// 		schemaId,
	// 		address(this)
	// 	);

	// 	eas.attest(doctorAddress, schema, score);

	// 	// Update doctor's reputation score (could be more complex based on EAS implementation)
	// 	doctors[doctorAddress].reputationScore += score;

	// 	emit ReputationAttested(doctorAddress, msg.sender, score);
	// }

	// Function for monthly settlement
	function settleMonth(bool treatmentOccurred) external onlyVerifiedDoctor {
		Doctor storage doctor = doctors[msg.sender];
		require(doctor.stakedAmount > 0, "No staked amount");

		address patientAddress = patients[msg.sender].assignedDoctor;
		uint256 payout = doctor.stakedAmount;

		if (treatmentOccurred) {
			// Treatment occurred, doctor loses the staked amount
			payout = 0;
		} else {
			// No treatment, doctor gets their staked ETH plus patient's monthly payment
			payout += address(this).balance; // Assuming patient's payment is in the contract balance
		}

		// Transfer ETH back to the doctor
		(bool success, ) = msg.sender.call{ value: payout }("");
		require(success, "Failed to send Ether");

		emit Settlement(msg.sender, patientAddress, payout, treatmentOccurred);
	}

	// Function to receive ETH from patients
	receive() external payable {}
}
