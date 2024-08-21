// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VestingContract {
    IERC20 public token; //ERC20
    address public owner;

    struct Employee {
        address employeeAddress;
        string employeeName;
        string employeeEmail;
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
        string employeeName,
        string employeeEmail,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 totalDuration,
        uint256 totalTokens
    );

    event TokensReleased(address indexed employeeAddress, uint256 amount);

    // event EmployeeRemoved(
    //     address  employeeAddress

    // );

    constructor(IERC20 _token) {
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
        string memory _employeeName,
        string memory _employeeEmail
    )
        public
        // uint256 _cliffDuration,
        // uint256 _totalDuration
        onlyOwner
    {
        require(!employees[_employee].exists, "Employee already exists");

        uint256 currentTime = block.timestamp;
        // uint256 employeeCliffDuration = block.timestamp + _cliffDuration;
        // uint256 employeeTotalDuration = block.timestamp + _totalDuration;
        uint256 employeeCliffDuration = block.timestamp + 1 minutes;
        uint256 employeeTotalDuration = block.timestamp + 4 minutes;

        employees[_employee] = Employee({
            employeeAddress: _employee,
            employeeName: _employeeName,
            employeeEmail: _employeeEmail,
            startTime: currentTime,
            cliffDuration: employeeCliffDuration,
            totalDuration: employeeTotalDuration,
            totalTokens: _totalTokens,
            receivedTokens: 0,
            exists: true
        });

        emit EmployeeAdded(
            _employee,
            _employeeName,
            _employeeEmail,
            currentTime,
            employeeCliffDuration,
            employeeTotalDuration,
            _totalTokens
        );
    }

    //Function to remove employees from mapping
    function removeEmployee(address _employee) public onlyOwner {
        require(employees[_employee].exists, "Employee does not exist");

        // You may also want to transfer any unvested tokens back to the owner or handle them accordingly
        // uint256 remainingTokens = employees[_employee].totalTokens -
        //     employees[_employee].receivedTokens;
        // if (remainingTokens > 0) {
        //     token.transfer(owner, remainingTokens);
        // }

        delete employees[_employee]; // Remove the employee from the mapping

        // emit EmployeeRemoved(_employee);
    }

    //Function to withDraw Tokens
    function withDraw(address _employee) public nonReentrant {
        Employee storage employee = employees[_employee];

        require(employee.exists, "Employee does not exist");
        require(
            employee.totalTokens != employee.receivedTokens,
            "You have already claimed tokens."
        );
        require(block.timestamp >= employee.totalDuration, "You should wait");

        uint256 vestedTokens = calculateVestedTokens(_employee);

        employee.receivedTokens += vestedTokens;
        token.transfer(_employee, employee.totalTokens);

        emit TokensReleased(_employee, vestedTokens);
    }

    //Function to calculate Tokens for employees
    function calculateVestedTokens(address _employee)
        public
        view
        returns (uint256)
    {
        Employee storage employee = employees[_employee];
        require(employee.exists, "Employee does not exist");

        if (block.timestamp > employee.cliffDuration) {
            if (block.timestamp >= employee.totalDuration) {
                if (employee.totalTokens == employee.receivedTokens) {
                    return 0;
                } else {
                    return employee.totalTokens;
                }
            } else {
                if (employee.totalTokens == employee.receivedTokens) {
                    return 0;
                } else {
                    uint256 timeElapsedSinceCliff = block.timestamp -
                        employee.cliffDuration;
                    uint256 vestingDuration = employee.totalDuration -
                        employee.cliffDuration;

                    // Calculate the number of periods that have passed (e.g., minutes or months)
                    uint256 periodDuration = vestingDuration / 10; // Each period corresponds to 10% of total tokens
                    uint256 periodsPassed = timeElapsedSinceCliff /
                        periodDuration;

                    // Calculate the vested tokens based on the periods passed
                    uint256 vestedTokens = (periodsPassed *
                        employee.totalTokens) / 10;

                    // Ensure the vested tokens do not exceed the total tokens allocated to the employee
                    if (vestedTokens > employee.totalTokens) {
                        vestedTokens = employee.totalTokens;
                    }
                    return vestedTokens;
                }
            }
        } else {
            return 0;
        }
    }

    //Function to check available tokens
    function availableTokens(address _employee) public view returns (uint256) {
        Employee storage employee = employees[_employee];

        require(employee.exists, "Employee does not exist");

        // Check if the employee has already claimed all their tokens
        if (employee.totalTokens == employee.receivedTokens) {
            return 0;
        }

        // Check if the vesting period has been completed
        if (block.timestamp >= employee.totalDuration) {
            return employee.totalTokens;
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

    function employeeCheck(address _employee)
        public
        view
        returns (bool _value)
    {
        Employee storage employee = employees[_employee];
        if (employee.exists) {
            return true;
        } else {
            return false;
        }
    }
}
