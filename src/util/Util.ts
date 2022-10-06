const fs = require('fs');

export function getJSON(file_name: string) {
    let rawdata = fs.readFileSync("storage/" + file_name);
    return JSON.parse(rawdata)
}

export function writeJSON(file_name: string, data: any) {
    fs.writeFileSync('storage/' + file_name, JSON.stringify(data, null, 4))

}

export function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
