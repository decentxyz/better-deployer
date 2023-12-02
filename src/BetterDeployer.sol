// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {CommonBase} from "forge-std/Base.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

contract BetterDeployer is CommonBase {
    using Strings for uint256;
    string public deploymentsPath;
    string public deploymentFile;

    mapping(string => address) public addressBook;
    string[] public deployments;
    string fileContent = "";

    constructor(string memory _path, string memory _deploymentFile) {
        deploymentsPath = _path;
        deploymentFile = (bytes(_deploymentFile).length == 0)
            ? getDefaultName()
            : _deploymentFile;
    }

    function ensureFileContentLoaded() public {
        if (bytes(fileContent).length > 0) {
            return;
        }
        string memory path = deployFilePath();
        if (vm.isFile(path)) {
            fileContent = vm.readFile(path);
        }
    }

    function loadFromFile(
        string memory name
    ) public returns (address deployment) {
        ensureFileContentLoaded();
        if (bytes(fileContent).length == 0) {
            return address(0);
        }
        try vm.parseJsonAddress(fileContent, string.concat(".", name)) returns (
            address dep
        ) {
            deployment = dep;
        } catch {
            deployment = address(0);
        }
        recordAddress(name, deployment);
    }

    function getDefaultName() public returns (string memory) {
        uint currTime = vm.unixTime();
        string memory timestamp = string(abi.encodePacked(bytes32(currTime)));
        return string.concat(timestamp, "_deployments.json");
    }

    function get(
        string memory deploymentName
    ) public returns (address deployed) {
        deployed = addressBook[deploymentName];
        if (deployed == address(0)) {
            deployed = loadFromFile(deploymentName);
        }
        if (deployed == address(0)) {
            revert(
                string.concat(
                    "No deployment found for ",
                    deploymentName,
                    "in file: ",
                    deployFilePath()
                )
            );
        }
    }

    function recordAddress(
        string memory deploymentName,
        address deployed
    ) public {
        vm.label(deployed, deploymentName);
        addressBook[deploymentName] = deployed;
        deployments.push(deploymentName);
    }

    function deploy(
        string memory deploymentName,
        string memory artifact,
        bytes memory args
    ) public returns (address deployed) {
        bytes memory bytecode = vm.getCode(artifact);
        bytes memory data = bytes.concat(bytecode, args);
        assembly {
            deployed := create(0, add(data, 0x20), mload(data))
        }
        if (deployed == address(0)) {
            revert(string.concat("Failed to deploy ", deploymentName));
        }
        recordAddress(deploymentName, deployed);
    }

    function deployFilePath() public view returns (string memory) {
        return string.concat(deploymentsPath, "/", deploymentFile);
    }

    function dump() public {
        string memory file = "addressBook";
        for (uint i = 0; i < deployments.length - 1; i++) {
            string memory key = deployments[i];
            vm.serializeAddress(file, key, addressBook[key]);
        }
        string memory lastKey = deployments[deployments.length - 1];
        string memory collected = vm.serializeAddress(
            file,
            string(lastKey),
            addressBook[lastKey]
        );

        vm.writeJson(collected, deployFilePath());
    }
}

// deploy script should just deploy the contract
// get(name) should return the instance of that contract
// there should be some configuration for pointing to the directory that contains the deployment
// there should be a default directory called "latest"
//
