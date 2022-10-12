import {getJSON, sleep} from "../../src/util";
import Mainnet from "../../src/EVM/Mainnet";
import Subnet from "../../src/EVM/Subnet";

const events = require('events');

let example_config: Config = {
    "private_key": "e5fb0910de1ba57e0328d591343c47e2ed620bdc7ba9364b62b1ff32968c45f7",
    "public_key": "0x56A52b69179fB4BF0d0Bc9aefC340E63c36d3895",
    "main_networks": [
        {
            "name": "fuji",
            "api_url": "https://red-weathered-firefly.avalanche-testnet.quiknode.pro/ext/bc/C/rpc",
            "bridge_address": "0x5f024972Fa6F59255AD8BDC289262930ea6A7261",
            "oracle": "0x92fb0Bfcd92b17f646f4a14b03Acb44869B62c2d",
            "abi": [
                "function bridgeToSubnet(uint256 amount, address asset) public returns (uint256)",
                "function approve(address spender, uint256 amount) public returns (bool)",
                "function bridgeToMainnet(address asset, address user, uint256 amount, uint256 _swapID) public returns (address)",
                "function updateMultiple(address[] memory pairs, address[] memory tokenIns, address[] memory tokenOuts)",
                "function price(address) view returns (uint256)",
                "function factory() external pure returns (address)",
                "function getPair(address tokenA, address tokenB) external view returns (address pair)",
                "event BridgeToSubnet(address indexed user, address indexed asset, uint256 indexed amount, string name_, string symbol_)",
                "event BridgeToMainnet(address indexed user, address indexed asset, uint256 indexed amount, string name_, string symbol_)"
            ]
        }
    ],
    "subnet": {
        "name": "fuji",
        "api_url": "https://red-weathered-firefly.avalanche-testnet.quiknode.pro/ext/bc/C/rpc",
        "bridge_manager_address": "0x862355f4d23D21E77aEaE24529819CBdA0A45858",
        "oracle": "0x665a3a94a52C27099B43995001F1e5aBde058D2e",
        "abi": [
            "event BridgeToMainnet(address indexed user, address indexed assetMainnet, address indexed assetSubnet, uint256 amount, string name_, string symbol_)",
            "function bridgeToMainnet(address asset, uint256 amount) public returns (uint256)",
            "function approve(address spender, uint256 amount) public returns (bool)",
            "function bridgeToSubnet(address asset, address user, uint256 amount, uint256 _swapID, string memory name_, string memory symbol_) public returns (address)",
            "function updateMultiple(address[] memory tokens, uint256[] memory prices) external",
            "function price(address) view returns (uint256)",
            "function updateMultipleMarketCap(address[] memory tokens, uint256[] memory mcaps) external",
            "function updateMarketCap(address mainnetToken, uint256 _mcap) public returns (uint256)",
            "function subnetAddresses(address) view returns (address)",
            "function burnAsset(address _token, uint256 _amount) public",
            "function mintAsset(address _token, uint256 _amount) public"
        ]
    }
}

let example_token = {
    "name": "Token C/WAVAX",
    "token": "Token C",
    "quote": "WAVAX",
    "pairAddress": "0xd32953c04A106a0753b29D371C1e7074C3cF8068",
    "tokenAddress": "0x1948EaB46Ff886190eBd50250EB486517e132F3B",
    "quoteAddress": "0x72187342BC71CAd08FcCC361ff8336A684dd6883"
}

let example_router = {
    "fuji": {"exposure": "0x2D99ABD9008Dc933ff5c0CD271B88309593aB921"}
}


let eventHandler = new events.EventEmitter();
let networks: { [key: string]: Mainnet } = {};
for (const i in example_config.main_networks) {
    networks[example_config.main_networks[i].name] = new Mainnet(example_config.main_networks[i], eventHandler, example_config.private_key)
}
let subnet: Subnet = new Subnet(example_config.subnet, eventHandler, example_config.private_key);
jest.setTimeout(60000)

describe("The network classes can initialize", () => {
    test('The subnet class should init', () => {
        subnet = new Subnet(example_config.subnet, eventHandler, example_config.private_key)
        expect(subnet.config);
    });
    test('Mainnet networks should init', () => {
        for (const i in example_config.main_networks) {
            networks[example_config.main_networks[i].name] = new Mainnet(example_config.main_networks[i], eventHandler, example_config.private_key)
        }
        expect(networks[Object.keys(networks)[0]].config);
    });
});

describe("The app can read and set prices", () => {
    let random_price = Math.floor(Math.random() * 100000).toString();
    test('The app can set new prices, read mainnet -> subnet token addresses, and read current subnet prices', async () => {
        let success = await subnet.updatePrices([example_token.tokenAddress], [random_price])
        expect(success);
    });

    let subToken: any
    test('The app can read mainnet -> subnet token addresses', async () => {
        subToken = await subnet.getSubnetAddress(example_token.tokenAddress)
        expect(subToken != "");
    });

    test('The app can read read subnet prices', async () => {
        let price = await subnet.getPrice(subToken)
        expect(price == random_price);
    });

    test('The app can update the mainnet oracle prices', async () => {
        let success = await networks['fuji'].updatePrices([example_token.pairAddress], [example_token.tokenAddress], [example_token.quoteAddress])
        expect(success);
    });

    test('The app can read mainnet oracle prices', async () => {
        let price = await networks['fuji'].getPrice(example_token.pairAddress)
        expect(price != "0");
    });

    test('The app can get mainnet pair addresses from dex and token/quote pairs', async () => {
        let pair = await networks['fuji'].getPairAddress(example_router.fuji.exposure, example_token.tokenAddress, example_token.quoteAddress)
        expect(pair != "");
    });
});

describe("The app can detect bridge requests and fulfill swaps", () => {
    test('The app can listen for bridgeToSubnet events on mainnet', async () => {
        let check = false
        let d = new Date().getTime()
        eventHandler.on('BridgeToSubnet', function (data: any) {
            console.log(data)
            check = true
            return
        })
        let pair = await networks['fuji'].bridgeToSubnet("1", example_token.tokenAddress)
        while (!check) {
            await sleep(250)
            if (new Date().getTime() - d > 30000)
                break
        }
        expect(pair);
    });

    test('The app can listen for bridgeToMainnet events on subnet', async () => {
        let check = false
        let d = new Date().getTime()
        eventHandler.on('BridgeToMainnet', function (data: any) {
            console.log(data)
            check = true
            return
        })
        let pair = await subnet.bridgeToMainnet(example_token.tokenAddress, example_config.public_key, "1")
        while (!check) {
            await sleep(250)
            if (new Date().getTime() - d > 60000)
                break
        }
        expect(pair);
    });

    test('The app can fulfill subnet bridge requests', async () => {
        let success = await subnet.bridgeToSubnet(example_token.tokenAddress, example_config.public_key, "1", example_token.token, example_token.token, Math.floor(Math.random() * 1000000000).toString())
        expect(success);
    });

    test('The app can fulfill mainnet bridge requests', async () => {
        let success = await networks['fuji'].bridgeToMainnet(example_token.tokenAddress, example_config.public_key, "1", example_token.token, example_token.token, Math.floor(Math.random() * 1000000000).toString())
        expect(success);
    });
});
