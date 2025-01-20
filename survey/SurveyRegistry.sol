// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AgricultureSurvey.sol";
import "./ManufacturingSurvey.sol";
import "./ConstructionSurvey.sol";
import "./TextilesSurvey.sol";
import "./MiningSurvey.sol";
import "./FisheriesSurvey.sol";
import "./RandomGenerator.sol";

contract SurveyRegistry {
    enum Industry {
        AGRICULTURE,
        MANUFACTURING,
        CONSTRUCTION,
        TEXTILES,
        MINING,
        FISHERIES
    }

    mapping(Industry => address) public surveyModules;
    address public admin;
    RandomGenerator public randomGenerator;

    event ModuleRegistered(Industry industry, address moduleAddress);

    constructor() {
        admin = msg.sender;
        randomGenerator = new RandomGenerator();
        // Deploy and register all survey modules
        surveyModules[Industry.AGRICULTURE] = address(new AgricultureSurvey());
        surveyModules[Industry.MANUFACTURING] = address(new ManufacturingSurvey());
        surveyModules[Industry.CONSTRUCTION] = address(new ConstructionSurvey());
        surveyModules[Industry.TEXTILES] = address(new TextilesSurvey());
        surveyModules[Industry.MINING] = address(new MiningSurvey());
        surveyModules[Industry.FISHERIES] = address(new FisheriesSurvey());
    }

    function getSurveyModule(Industry _industry) external view returns (address) {
        return surveyModules[_industry];
    }

    function createSurveyForIndustry(
        Industry _industry,
        uint256[] memory _questionIds,
        uint256 _workerCount,
        uint256 _duration
    ) external returns (uint256) {
        address moduleAddress = surveyModules[_industry];
        require(moduleAddress != address(0), "Industry module not found");
        
        // Create survey using the appropriate module
        return BaseSurveyQuestions(moduleAddress).createSurvey(
            _questionIds,
            _workerCount,
            _duration
        );
    }

    function getRandomQuestions(
        Industry _industry,
        address _worker
    ) external view returns (
        Question memory baseQuestion,
        Question memory industryQuestion
    ) {
        address moduleAddress = surveyModules[_industry];
        require(moduleAddress != address(0), "Industry module not found");
        
        BaseSurveyQuestions module = BaseSurveyQuestions(moduleAddress);
        
        // Get random question IDs
        (uint256 baseId, uint256 industryId) = randomGenerator.selectRandomQuestions(
            module.baseQuestionCount(),
            module.questionCount() - module.baseQuestionCount(),
            _worker
        );

        // Get the actual questions
        baseQuestion = module.questions(baseId);
        industryQuestion = module.questions(
            module.baseQuestionCount() + industryId
        );

        return (baseQuestion, industryQuestion);
    }

    function recordRandomSurveyResponse(
        Industry _industry,
        address _worker,
        uint256[2] memory _responses
    ) external returns (bool) {
        (Question memory baseQ, Question memory industryQ) = getRandomQuestions(_industry, _worker);
        
        // Record responses
        // Implementation depends on how you want to store responses
        
        return true;
    }
}