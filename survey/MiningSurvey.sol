// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./base/BaseSurveyQuestions.sol";

/**
 * @title MiningSurvey
 * @dev Survey questions specific to mining industry workers
 * Covers both underground and surface mining conditions,
 * focusing on safety, health, and working conditions
 */

contract MiningSurvey is BaseSurveyQuestions {
    constructor() BaseSurveyQuestions() {
        initializeMiningQuestions();
    }

    function initializeMiningQuestions() internal {
        // Safety Equipment
        string[] memory yesNo = new string[](2);
        yesNo[0] = "Yes";
        yesNo[1] = "No";

        addQuestion(
            "Is personal protective equipment (helmets, boots, respirators) provided and regularly maintained?",
            1, // Yes/No
            yesNo
        );

        // Emergency Equipment
        addQuestion(
            "Do you have access to emergency breathing apparatus in your work area?",
            1,
            yesNo
        );

        // Ventilation
        string[] memory ventilationOptions = new string[](4);
        ventilationOptions[0] = "Always adequate";
        ventilationOptions[1] = "Usually adequate";
        ventilationOptions[2] = "Sometimes inadequate";
        ventilationOptions[3] = "Frequently inadequate";

        addQuestion(
            "How would you rate the ventilation in your work area?",
            3, // Multiple Choice
            ventilationOptions
        );

        // Working Hours
        string[] memory hoursOptions = new string[](4);
        hoursOptions[0] = "Less than 8 hours";
        hoursOptions[1] = "8-10 hours";
        hoursOptions[2] = "10-12 hours";
        hoursOptions[3] = "More than 12 hours";

        addQuestion(
            "How long is your typical work shift?",
            3,
            hoursOptions
        );

        // Rest Periods
        string[] memory restOptions = new string[](4);
        restOptions[0] = "Every 2 hours";
        restOptions[1] = "Every 4 hours";
        restOptions[2] = "Every 6 hours";
        restOptions[3] = "No regular breaks";

        addQuestion(
            "How often are you given rest breaks during shifts?",
            3,
            restOptions
        );

        // Emergency Training
        addQuestion(
            "Have you received training on emergency procedures in the last 6 months?",
            1,
            yesNo
        );

        // Emergency Routes
        addQuestion(
            "Are emergency escape routes clearly marked and unobstructed?",
            1,
            yesNo
        );

        // Health Monitoring
        string[] memory healthCheckOptions = new string[](4);
        healthCheckOptions[0] = "Monthly";
        healthCheckOptions[1] = "Quarterly";
        healthCheckOptions[2] = "Annually";
        healthCheckOptions[3] = "Never";

        addQuestion(
            "How often do you receive health check-ups?",
            3,
            healthCheckOptions
        );

        // Water Access
        addQuestion(
            "Do you have access to clean drinking water at your work site?",
            1,
            yesNo
        );

        // Communication Systems
        addQuestion(
            "Are communication systems (radio, phone) working and accessible in your work area?",
            1,
            yesNo
        );

        // Hazard Reporting
        string[] memory reportingOptions = new string[](4);
        reportingOptions[0] = "Always addressed";
        reportingOptions[1] = "Usually addressed";
        reportingOptions[2] = "Sometimes addressed";
        reportingOptions[3] = "Never addressed";

        addQuestion(
            "When you report safety concerns, how are they typically handled?",
            3,
            reportingOptions
        );

        // Equipment Maintenance
        addQuestion(
            "Is mining equipment regularly inspected and maintained?",
            1,
            yesNo
        );

        // First Aid
        addQuestion(
            "Are first aid kits readily available and properly stocked?",
            1,
            yesNo
        );

        // Chemical Safety
        addQuestion(
            "Have you been trained on handling hazardous materials?",
            1,
            yesNo
        );

        // Dust Control
        string[] memory dustOptions = new string[](4);
        dustOptions[0] = "Very effective";
        dustOptions[1] = "Somewhat effective";
        dustOptions[2] = "Not very effective";
        dustOptions[3] = "Ineffective";

        addQuestion(
            "How effective are dust control measures in your work area?",
            3,
            dustOptions
        );
    }
}