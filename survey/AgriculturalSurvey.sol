// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./base/BaseSurveyQuestions.sol";

contract AgricultureSurvey is BaseSurveyQuestions {
    constructor() BaseSurveyQuestions() {
        initializeAgricultureQuestions();
    }

    function initializeAgricultureQuestions() internal {
        string[] memory yesNo = new string[](2);
        yesNo[0] = "Yes";
        yesNo[1] = "No";

        addQuestion(
            "Do you have access to clean drinking water in the fields?",
            1, // Yes/No
            yesNo
        );

        addQuestion(
            "Are you provided with proper protection from pesticides?",
            1,
            yesNo
        );

        string[] memory restOptions = new string[](4);
        restOptions[0] = "Every 2 hours";
        restOptions[1] = "Every 4 hours";
        restOptions[2] = "Once per day";
        restOptions[3] = "No regular breaks";

        addQuestion(
            "How often are you given rest breaks during harvest?",
            3, // Multiple Choice
            restOptions
        );
    }
}