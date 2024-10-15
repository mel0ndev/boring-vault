// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

// Import Decoder and Sanitizer to deploy.
import {PointFarmingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Fraxtal/DeployBridgingTestVault.s.sol:DeployBridgingTestVaultScript --evm-version london --broadcast --etherscan-api-key $FRAXSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployBridgingTestVaultScript is DeployArcticArchitecture, MerkleTreeHelper {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Bridging Test Vault";
    string public boringVaultSymbol = "BTEV";
    uint8 public boringVaultDecimals = 18;

    address internal owner;
    address internal testAddress;
    ERC20 internal wfrxETH;
    address internal balancerVault;
    address internal deployerAddress;
    address internal uniswapV3NonFungiblePositionManager;
    address internal liquidPayoutAddress;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("fraxtal");
        setSourceChainName(fraxtal);

        owner = getAddress(sourceChain, "dev0Address");
        testAddress = getAddress(sourceChain, "dev0Address");
        wfrxETH = getERC20(sourceChain, "wfrxETH");
        balancerVault = address(0);
        deployerAddress = getAddress(sourceChain, "deployerAddress");
        uniswapV3NonFungiblePositionManager = address(0);
        liquidPayoutAddress = getAddress(sourceChain, "liquidPayoutAddress");

        droneCount = 1;
    }

    function run() external {
        // Configure the deployment.
        configureDeployment.deployContracts = false;
        configureDeployment.setupRoles = true;
        configureDeployment.setupDepositAssets = true;
        configureDeployment.setupWithdrawAssets = true;
        configureDeployment.finishSetup = true;
        configureDeployment.setupTestUser = true;
        configureDeployment.saveDeploymentDetails = true;
        configureDeployment.deployerAddress = deployerAddress;
        configureDeployment.balancerVault = balancerVault;
        configureDeployment.WETH = address(wfrxETH);

        // Save deployer.
        deployer = Deployer(configureDeployment.deployerAddress);

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = BridgingTestVaultEthRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = BridgingTestVaultEthName;
        names.manager = BridgingTestVaultEthManagerName;
        names.accountant = BridgingTestVaultEthAccountantName;
        names.teller = BridgingTestVaultEthTellerName;
        names.rawDataDecoderAndSanitizer = BridgingTestVaultEthDecoderAndSanitizerName;
        names.delayedWithdrawer = BridgingTestVaultEthDelayedWithdrawer;
        names.droneBaseName = BridgingTestVaultDroneName;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = wfrxETH;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e18;
        //  4 decimals
        accountantParameters.managementFee = 0.02e4;
        accountantParameters.performanceFee = 0;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(PointFarmingDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs = abi.encode(deployer.getAddress(names.boringVault));

        // Setup extra deposit assets.
        // none

        // Setup withdraw assets.
        withdrawAssets.push(
            WithdrawAsset({
                asset: wfrxETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        bool allowPublicDeposits = true;
        bool allowPublicWithdraws = true;
        uint64 shareLockPeriod = 0;
        address delayedWithdrawFeeAddress = liquidPayoutAddress;

        vm.startBroadcast(privateKey);

        _deploy(
            "Fraxtal/BridgingTestVaultDeployment.json",
            owner,
            boringVaultName,
            boringVaultSymbol,
            boringVaultDecimals,
            creationCode,
            constructorArgs,
            delayedWithdrawFeeAddress,
            allowPublicDeposits,
            allowPublicWithdraws,
            shareLockPeriod,
            testAddress
        );

        vm.stopBroadcast();
    }
}