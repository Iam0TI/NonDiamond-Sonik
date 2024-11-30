const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

function generateProof(address) {
  // Load the Merkle tree from a JSON file
  const tree = StandardMerkleTree.load(
    JSON.parse(fs.readFileSync("tree.json", "utf8"))
  );

  for (const [i, v] of tree.entries()) {
    if (v[0].toLowerCase() === address.toLowerCase()) {
      // Generate the proof for the given index
      const proof = tree.getProof(i);
      return {
         proof,
      };
    }
  }

  // If the address is not found, return emepty object
  return {
        // value: '',
        proof: "",
      };
}

module.exports = { generateProof };
