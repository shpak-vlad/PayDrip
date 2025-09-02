// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract StreamTemplate {
    struct Template {
        string name;
        uint256 duration;
        uint256 defaultAmount;
    }
    
    mapping(uint256 => Template) public templates;
    uint256 public templateCount;
    
    function createTemplate(string memory name, uint256 duration, uint256 amount) external returns (uint256) {
        uint256 templateId = templateCount++;
        templates[templateId] = Template(name, duration, amount);
        return templateId;
    }
}
// Template utilities
