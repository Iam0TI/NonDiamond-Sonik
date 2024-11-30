const { generateProof } = require("./createMerkleProof");
const fs = require("fs/promises");
const path = require("path");

async function main() {
  try {
    // Get the address from the command-line arguments
    const address = process.argv[2];

    if (!address) {
      console.error("Error: No address provided. Usage: node script/checkProofForAddressCli.js <address>");
      process.exit(1); // Exit with a non-zero code to indicate error
    }

    // Generate the proof for the provided address
    const proof = generateProof(address);

    // Create the JSON object to save
    const output =  proof;
    

    // Define the output file path
    const outputPath = path.join(__dirname, `proof.json`);

    // Write the JSON object to a file
    await fs.writeFile(outputPath, JSON.stringify(output, null, 1));
    console.log(output)
    console.log(`Proof saved to ${outputPath}`);
  } catch (error) {
    console.error("An error occurred:", error);
  }
}

main().catch((error) => console.error("Unhandled error:", error));
