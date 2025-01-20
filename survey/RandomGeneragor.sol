// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RandomGenerator
 * @dev Provides pseudo-random number generation for survey question selection
 */

contract RandomGenerator {
    function getRandomNumber(uint256 max, bytes32 salt) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            salt
        ))) % max;
    }

    function selectRandomQuestions(
        uint256 baseQuestionCount,
        uint256 industryQuestionCount,
        address worker
    ) external view returns (uint256, uint256) {
        bytes32 salt = keccak256(abi.encodePacked(worker, block.number));
        
        uint256 baseQuestion = getRandomNumber(baseQuestionCount, salt);
        uint256 industryQuestion = getRandomNumber(industryQuestionCount, 
            keccak256(abi.encodePacked(salt, baseQuestion))
        );

        return (baseQuestion, industryQuestion);
    }
}