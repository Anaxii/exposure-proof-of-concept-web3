import {Network} from "./Network";

const {ethers} = require("ethers");

export default class Subnet extends Network {

    constructor(config: SubNetwork, eventHandler: any, privateKey: string) {
        super(config, eventHandler, privateKey)
        this.monitor()
    }

    private async monitor() {

        const abi = [
            "event BridgeToMainnet(address indexed user, address indexed assetMainnet, address indexed assetSubnet, uint256 amount, string name_, string symbol_)"
        ];

        const contract = new ethers.Contract(this.config.bridge_manager_address, abi, this.provider);

        contract.on("BridgeToMainnet", (user: any, assetMainnet: any, assetSubnet: any, amount: any, assetName: any, assetSymbol: any, event: any) => {
            this.eventHandler.emit('BridgeToMainnet', {
                network: this.config,
                user,
                assetMainnet,
                assetSubnet,
                amount: amount.toString(),
                assetName,
                assetSymbol
            });
        });
    }

    async bridgeToSubnet(asset: string, user: string, amount: string, assetName: string, assetSymbol: string) {
        const abi = [
            "function bridgeToSubnet(address asset, address user, uint256 amount, string memory name_, string memory symbol_) public"
        ];

        const contract = new ethers.Contract(this.config.bridge_manager_address, abi, this.provider);

        const signer = new ethers.Wallet(this.privateKey, this.provider)
        const contractWithSigner = contract.connect(signer)
        let tx = await contractWithSigner.bridgeToSubnet(asset, user, amount, assetName, assetSymbol)
        await tx.wait()
        console.log(`Bridged ${amount} (1e18) ${assetSymbol} to the subnet for ${user}`)
    }
}
