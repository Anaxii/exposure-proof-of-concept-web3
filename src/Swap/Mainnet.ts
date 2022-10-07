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
        await tx.wait(2)
        console.log(`Bridged ${amount} (1e18) ${symbol} to ${network} (mainnet) for ${user}`)

    }

    async updatePrice(pair: string[], asset: string[], quote: string[]) {
        const abi = [
            "function updateMultiple(address[] memory pairs, address[] memory tokenIns, address[] memory tokenOuts)",
        ];

        const contract = new ethers.Contract(this.config.oracle, abi, this.provider);

        const signer = new ethers.Wallet(this.privateKey, this.provider)
        const contractWithSigner = contract.connect(signer)
        let tx = await contractWithSigner.updateMultiple(pair, asset, quote)
        await tx.wait(2)
        console.log(`Updated some prices (batched)`)

    }

    async getPrice(pair: string) {
        const abi = [
            "function price(address) view returns (uint256)",
        ];

        const contract = new ethers.Contract(this.config.oracle, abi, this.provider);

        let price = await contract.price(pair)
        return price.toString()
    }

    async getPairAddress(router: string, token: string, quote: string) {
        const abi = [
            "function factory() external pure returns (address)",
            "function getPair(address tokenA, address tokenB) external view returns (address pair)"
        ];

        const routerContract = new ethers.Contract(router, abi, this.provider);
        let factory = await routerContract.factory()

        const factoryContract = new ethers.Contract(factory, abi, this.provider);
        return await factoryContract.getPair(token, quote)

    }
}
