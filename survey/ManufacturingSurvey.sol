// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./base/BaseSurveyQuestions.sol";

contract ManufacturingSurvey is BaseSurveyQuestions {
    constructor() BaseSurveyQuestions() {
        initializeManufacturingQuestions();
    }

    function initializeManufacturingQuestions() internal {
        string[] memory safetyOptions = new string[](4);
        safetyOptions[0] = "Always";
        safetyOptions[1] = "Usually";
        safetyOptions[2] = "Sometimes";
        safetyOptions[3] = "Never";

        addQuestion(
            "How often is safety equipment provided and maintained?",
            3,
            safetyOptions
        );

        addQuestion(
            "Are emergency exits clearly marked and accessible?",
            1,
            ["Yes", "No"]
        );
    }
}