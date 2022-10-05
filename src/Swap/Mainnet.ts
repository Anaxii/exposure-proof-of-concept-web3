import {Network} from "./Network";

const {ethers} = require("ethers");

export default class Mainnet extends Network {

    constructor(config: MainNetwork, eventHandler: any, privateKey: string) {
        super(config, eventHandler, privateKey)
        this.monitor()
    }

    private async monitor() {
        const abi = [
            "event BridgeToSubnet(address indexed user, address indexed asset, uint256 indexed amount, string name_, string symbol_)",
            "event BridgeToMainnet(address indexed user, address indexed asset, uint256 indexed amount, string name_, string symbol_)"
        ];

        const contract = new ethers.Contract(this.config.bridge_address, abi, this.provider);


        contract.on("BridgeToSubnet", (user: any, asset: any, amount: any, assetName: any, assetSymbol: any, event: any) => {
            this.eventHandler.emit('BridgeToSubnet', {
                network: this.config,
                user,
                asset,
                amount: amount.toString(),
                assetName,
                assetSymbol
            });
        });
    }

    async bridgeToMainnet(asset: string, user: string, amount: string, symbol: string, network: string) {
        const abi = [
            "function bridgeToMainnet(uint256 amount, address asset, address user) public",
        ];

        const contract = new ethers.Contract(this.config.bridge_address, abi, this.provider);

        const signer = new ethers.Wallet(this.privateKey, this.provider)
        const contractWithSigner = contract.connect(signer)
        let tx = await contractWithSigner.bridgeToMainnet(amount, asset, user)
        await tx.wait()
        console.log(`Bridged ${amount} (1e18) ${symbol} to ${network} (mainnet) for ${user}`)

    }
}
