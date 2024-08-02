// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vesting {
    IERC20 public token; //ERC20
    address public owner;

    struct Employee {
        address employeeAddress;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 totalDuration;
        uint256 totalTokens;
        uint256 receivedTokens;
        bool exists;
    }

    mapping(address => Employee) public employees;

    event EmployeeAdded(
        address indexed employeeAddress,
        uint256 startTime,
         uint256 cliffDuration,
        uint256 totalDuration,
        uint256 totalTokens
    );

    event TokensReleased(address indexed employeeAddress, uint256 amount);

    constructor(
        IERC20 _token 
    ) 
    {
        token = _token;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    //Mutex for Re-entrancy
    bool private locked;
    modifier nonReentrant() {
        require(!locked, "No re-entrancy Wait Please !");
        locked = true;
        _;
        locked = false;
    }

    //Function to add employees
    function addEmployee(
        address _employee,
        uint256 _totalTokens,
        uint256 _cliffDuration,
        uint256 _totalDuration
    ) public onlyOwner {
        require(!employees[_employee].exists, "Employee already exists");

        uint256 currentTime = block.timestamp;
        uint256 employeeCliffDuration = block.timestamp + _cliffDuration;
        uint256 employeeTotalDuration = block.timestamp + _totalDuration;
        
        employees[_employee] = Employee({
            employeeAddress: _employee,
            startTime: currentTime,
            cliffDuration: employeeCliffDuration,
            totalDuration: employeeTotalDuration,
            totalTokens: _totalTokens,
            receivedTokens: 0,
            exists: true
        });

        emit EmployeeAdded(_employee, currentTime, employeeCliffDuration  ,employeeTotalDuration ,_totalTokens);
    }

    //Function to withDraw Tokens
    function withDraw(address _employee) public nonReentrant {
        require(employees[_employee].exists, "Employee does not exist");
        require(employees[_employee].totalTokens !=employees[_employee].receivedTokens, "You have already claimed tokens.");
        require(block.timestamp > employees[_employee].totalDuration,"You should wait");

        uint256 vestedTokens = calculateVestedTokens(_employee);
    
        employees[_employee].receivedTokens += vestedTokens;
        token.transferFrom(owner,_employee,employees[_employee].totalTokens);

        emit TokensReleased(_employee, vestedTokens);
    }
 
    //Function to calculate Tokens for employees
    function calculateVestedTokens(address _employee)
        public
        view
        returns (uint256)
    {
        Employee storage employee = employees[_employee];

        if (block.timestamp > employee.cliffDuration) {
            if (block.timestamp >= employee.totalDuration) {
                return employee.totalTokens;
            } else {
                uint256 timeElapsed = block.timestamp - employee.startTime;
                uint256 vestingDuration = employee.totalDuration -  employee.cliffDuration;

                // Calculate the vested tokens based on the elapsed time
                uint256 vestedTokens = (timeElapsed * employee.totalTokens) /
                    vestingDuration;

                // Ensure the vested tokens do not exceed the total tokens allocated to the employee
                if (vestedTokens > employee.totalTokens) {
                    vestedTokens = employee.totalTokens;
                }
                return vestedTokens;
            }
        } else {
            return 0;
        }
     
    }

    function getTime() external view returns (uint256) {
        return block.timestamp;
    }

    function balanceOf(address _account) public view returns (uint256) {
        return token.balanceOf(_account);
    }

}
