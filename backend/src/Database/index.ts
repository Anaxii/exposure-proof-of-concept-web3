const sqlite3 = require('sqlite3').verbose();

export default async function Database() {
    let db = new sqlite3.Database('backend/storage/database.db', sqlite3.OPEN_READWRITE, async (err: any) => {
        if (err) {
            db = await setupDatabase()
            console.error("Created new database");
        }
        console.log('Connected to the chinook database.');
    });
    await createTables(db)
    db.close()
}

async function setupDatabase() {
    return new sqlite3.Database("backend/storage/database.db",
        sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE,
        (err: any) => {
            console.log("Critical error: DB |", err)
            process.exit(1)
        })
}

async function createTables(db: any) {
    await db.run("CREATE TABLE routers(network_name text, dex_name text, contract_address text)", (err: any) => {
        if (err) {
            return console.log("CREATE ROUTERS", err.message);
        }
        db.run(`INSERT INTO routers(network_name, dex_name, contract_address) VALUES(?,?,?)`, ["fuji", "exposure", "0x2D99ABD9008Dc933ff5c0CD271B88309593aB921"], (err: any) => {
            if (err) {
                return console.log(err.message);
            }
        });
    })
    await db.run("CREATE TABLE tokens(network_name text, token_name text, contract_address text)", (err: any) => {
        if (err) {
            return console.log("CREATE TOKENS", err.message);
        }
        db.run(`INSERT INTO tokens(network_name, token_name, contract_address) VALUES(?,?,?)`, ["fuji", "WAVAX", "0x72187342BC71CAd08FcCC361ff8336A684dd6883"], (err: any) => {
            if (err) {
                return console.log(err.message);
            }
        });
    })
    await db.run("CREATE TABLE liquidity_tokens(network_name text, token_name text, contract_address text)", (err: any) => {
        if (err) {
            return console.log("CREATE LIQUIDITY_TOKENS", err.message);
        }
        db.run(`INSERT INTO liquidity_tokens(network_name, token_name, contract_address) VALUES(?,?,?)`, ["fuji", "WAVAX", "0x72187342BC71CAd08FcCC361ff8336A684dd6883"], (err: any) => {
            if (err) {
                return console.log(err.message);
            }
        });
    })
    await db.run("CREATE TABLE dollar_coins(network_name text, token_name text, contract_address text)", (err: any) => {
        if (err) {
            return console.log("CREATE DOLLAR_COINS", err.message);
        }
        db.run(`INSERT INTO dollar_coins(network_name, token_name, contract_address) VALUES(?,?,?)`, ["fuji", "USDC", "0x803871f6BB32a9C1230cdc182002f8e058791A9A"], (err: any) => {
            if (err) {
                return console.log(err.message);
            }
        });
    })
    await db.run("CREATE TABLE prices(token_name text, price text)", (err: any) => {
        if (err) {
            return console.log("CREATE PRICES", err.message);
        }
    })
    await db.run("CREATE TABLE mcaps(token_name text, mcap text)", (err: any) => {
        if (err) {
            return console.log("CREATE MCAPS", err.message);
        }
    })
    await db.run("CREATE TABLE baskets(basket_name text, contract_address text)", (err: any) => {
        if (err) {
            return console.log("CREATE BASKETS", err.message);
        }
    })
    await db.run("CREATE TABLE pairs(network_name text, token_name text, quote_name text, dex_name text, pair_name text, pair_address text, token_address text, quote_address text)", (err: any) => {
        if (err) {
            return console.log("CREATE PAIRS", err.message);
        }
        db.run(
            `INSERT INTO pairs(network_name, token_name, quote_name, dex_name, pair_name, pair_address, token_address, quote_address) VALUES(?,?,?,?,?,?,?,?)`,
            [
                "fuji",
                "WAVAX",
                "USDC",
                "exposure",
                "WAVAX/USDC",
                "0x23Cb1c2582C23C7E45415E290580E7C7e5af7C0D",
                "0x72187342BC71CAd08FcCC361ff8336A684dd6883",
                "0x803871f6BB32a9C1230cdc182002f8e058791A9A",
            ], (err: any) => {
            if (err) {
                return console.log(err.message);
            }
        });
    })
}

async function query() {
    // let sql = `SELECT * FROM routers WHERE network_name = ?`;
    //
    // db.get(sql, ["fuji"], (err: any, row: any) => {
    //     if (err) {
    //         return console.error(err.message);
    //     }
    //     console.log(row)
    //
    // });
}

