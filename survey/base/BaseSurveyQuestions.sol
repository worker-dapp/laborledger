// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title BaseSurveyQuestions
 * @dev Base contract for industry-specific survey questions
 */

abstract contract BaseSurveyQuestions {
    struct Question {
        uint256 id;
        string content;
        uint256 responseType;
        string[] options;
        bool isBaseQuestion;
        bool active;
    }

    mapping(uint256 => Question) public questions;
    uint256 public questionCount;
    uint256 public baseQuestionCount;
    address public admin;

    event QuestionAdded(uint256 id, string content);
    event QuestionDeactivated(uint256 id);

    constructor() {
        admin = msg.sender;
    }

    // Base functions that all survey modules will share
    function addBaseQuestion(
        string memory _content,
        uint256 _responseType,
        string[] memory _options
    ) internal returns (uint256) {
        questionCount++;
        baseQuestionCount++;
        questions[questionCount] = Question({
            id: questionCount,
            content: _content,
            responseType: _responseType,
            options: _options,
            isBaseQuestion: true,
            active: true
        });

        emit QuestionAdded(questionCount, _content);
        return questionCount;
    }

    function addIndustryQuestion(
        string memory _content,
        uint256 _responseType,
        string[] memory _options
    ) internal returns (uint256) {
        questionCount++;
        questions[questionCount] = Question({
            id: questionCount,
            content: _content,
            responseType: _responseType,
            options: _options,
            isBaseQuestion: false,
            active: true
        });

        emit QuestionAdded(questionCount, _content);
        return questionCount;
    }

    function initializeBaseQuestions() internal {
        string[] memory yesNo = new string[](2);
        yesNo[0] = "Yes";
        yesNo[1] = "No";

        // Add standard base questions
        addBaseQuestion(
            "Do you receive regular breaks during your work day?",
            1,
            yesNo
        );

        addBaseQuestion(
            "Do you feel safe at your workplace?",
            1,
            yesNo
        );

        // Add more base questions...
    }
}