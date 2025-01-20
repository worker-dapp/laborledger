// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./base/BaseSurveyQuestions.sol";

/**
 * @title FisheriesSurvey
 * @dev Survey questions specific to fishing industry workers
 * Covers both on-vessel and processing facility conditions
 */

contract FisheriesSurvey is BaseSurveyQuestions {
    constructor() BaseSurveyQuestions() {
        initializeFisheriesQuestions();
    }

    function initializeFisheriesQuestions() internal {
        // Safety Equipment Questions
        string[] memory yesNo = new string[](2);
        yesNo[0] = "Yes";
        yesNo[1] = "No";

        addQuestion(
            "Is proper safety equipment (life jackets, emergency beacons) provided and accessible?",
            1, // Yes/No
            yesNo
        );

        // Working Hours
        string[] memory hoursOptions = new string[](4);
        hoursOptions[0] = "Less than 12 hours";
        hoursOptions[1] = "12-14 hours";
        hoursOptions[2] = "14-16 hours";
        hoursOptions[3] = "More than 16 hours";

        addQuestion(
            "How many hours do you typically work in a day at sea?",
            3, // Multiple Choice
            hoursOptions
        );

        // Rest Periods
        string[] memory restOptions = new string[](4);
        restOptions[0] = "Every 4 hours";
        restOptions[1] = "Every 6 hours";
        restOptions[2] = "Every 8 hours";
        restOptions[3] = "No regular breaks";

        addQuestion(
            "How often are you given rest breaks during work shifts?",
            3,
            restOptions
        );

        // Living Conditions
        addQuestion(
            "Do you have access to clean drinking water and proper food storage?",
            1,
            yesNo
        );

        addQuestion(
            "Are sleeping quarters adequately ventilated and maintained?",
            1,
            yesNo
        );

        // Processing Facility Questions
        string[] memory frequencyOptions = new string[](4);
        frequencyOptions[0] = "Always";
        frequencyOptions[1] = "Usually";
        frequencyOptions[2] = "Sometimes";
        frequencyOptions[3] = "Never";

        addQuestion(
            "How often is protective equipment provided for processing work?",
            3,
            frequencyOptions
        );

        // Temperature Conditions
        string[] memory tempOptions = new string[](4);
        tempOptions[0] = "Comfortable";
        tempOptions[1] = "Slightly uncomfortable";
        tempOptions[2] = "Very uncomfortable";
        tempOptions[3] = "Unsafe";

        addQuestion(
            "How would you rate the temperature conditions in processing areas?",
            3,
            tempOptions
        );

        // Documentation
        addQuestion(
            "Do you have access to your personal documents (ID, work permits)?",
            1,
            yesNo
        );

        // Communication
        addQuestion(
            "Do you have regular access to communication with family/shore?",
            1,
            yesNo
        );

        // Emergency Procedures
        addQuestion(
            "Have you been trained in emergency procedures and vessel safety?",
            1,
            yesNo
        );
    }
}