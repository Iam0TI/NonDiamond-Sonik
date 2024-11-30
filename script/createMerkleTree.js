const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");
const { values } = require("./airdrop_list");

const tree = StandardMerkleTree.of(values, ["address" ,"uint256"]);

// (3) Output the Merkle root
console.log("Merkle Root:", tree.root);

// (4) Write the Merkle tree data to a JSON file
fs.writeFileSync("tree.json", JSON.stringify(tree.dump(), null, 1), "utf8");

console.log("JSON file created: tree.json");
