
function runERC721benchmark (owner, newOwner) {
  const data = '0x42';

  context('Benchmarks', function () {
    it('Basic transferFrom gas cost', async function () {
      await this.token.safeMint(owner, 1001, data);
      await this.token.safeMint(owner, 1002, data);
      await this.token.safeMint(owner, 1003, data);
      await this.token.transferFrom(owner, newOwner, 1001, {from: owner})
      const tx = await this.token.transferFrom(owner, newOwner, 1002, {from: owner})
      console.log('Basic transferFrom gas cost: ' + tx.receipt.gasUsed)
    })
  })
}

module.exports = {
  runERC721benchmark,
};
