# ERC721id16

Efficient Implementation of EIP721 and EIP721+Enumerable with tokenId &lt; 2\*\*16.

Contracts here are divided according to two distinct purposes.
They are weakly related.
One is to look for ERC721 transfers as cheap as possible.
The other is to lower transfer costs for ERC721+Enumerable.
The latter assumes that tokenId &lt; 2\*\*16, what allows enumeration to be even cheaper.

## ERC721id16

### id16 concept

Any tokenId is less than 2\*\*16. 
With this the total supply, a balance of any user, any index in enumeration are less than 2\*\*16.
So they fit in `uint16`.
The idea is to put more of such data within one storage slot which is 256 bits.

Enumerable requires to maintain wallets of users that support 
`tokenOfOwnerByIndex()` and `balanceOf()` functions.
A user's wallet is a list of owned token ids which are `uint16`.
And this is its layout.

```markdown
|                               slot 1                                     | ... |
|--------------------------------------------------------------------------|-----|
| length (16 bits) | 1st token id (16 bits) | 2nd token id (16 bits) | ... | ... |
```

If a user owns less than 16 tokens, a whole wallet fits in a single slot.
While updating a user's balance, tokens' indexes are updated along.
It makes one storage update instead of two (adding a token) or three (removing a token).
When a user owns much more tokens, the saving diminishes, possibly to zero.

There is another benefit of having `uint16` as token ids.
Usually `_owners` are of the type `mapping(uint256 => address)`, token id => owner.
But `address` is 160 bits and 96 bits are left unused. 
An index of token in a user's wallet is appended in order to save storage.
So the structure is

```markdown
|                                _owners[tokenId]                                    |
|------------------------------------------------------------------------------------|
| user address (160 bits) | token index in user's wallet (16 bits) | other (80 bits) |
```

Lets consider a scenario. An owner transfers a token another user. 
The owner has a few tokens, and the user has a few tokens.
There are the following storage operations:
- update the owner's wallet (1 slot update),
- update the user's wallet (1 slot update),
- update the token ownership and the token index (1 slot update),
- update the token index of replaced token (1 slot update), can be required, possibly not.

This is 4*5k gas for storage operations, plus 21k for a transaction, plus 1k for Transfer event plus some gas for other operations.
It is 43-44k gas in total what is pretty nice.
Notice that gas cost may vary significantly depending on a scenario.  

### Single approve

A typical implementation clears `_tokenApprovals` upon a transfer by default.
We provide a little gas optimisation.
An approval is not deleted even if it is read.
Instead, a token's transfer counter is attached to an approval.
It is set at approving.
A current token's transfer counter is stored with token's ownership.

```markdown
|                                      _owners[tokenId]                                         |
|-----------------------------------------------------------------------------------------------|
| user address (160 bits) | token index in user's wallet (16 bits) | transfer counter (80 bits) |
```

A token's transfer counter is increased at each transfer.
It does not cost any additional storage operation since a counter is appended to an ownership slot.
An approval is valid if its saved counter equals current token's counter.

### Minting

ERC721id16 is a base contract.
Inheriting contracts have to provide minting methods like in OZ implementation.
They also have to implement `totalSupply()` and `tokenByIndex()` which are a part of Enumerable interface.
I came to a conclusion that gas efficient implementations depend on minting method.
In particular, if there is lazy minting.

There are two implementations, ERC721id16LazyMint and ERC721BatchMint.
But you can create your own.
Both implementations assume that a total supply is given at the constructor.

## ERC721 Mini

This is not id16 concept as the name of this repo would suggest. A separate repo could work actually.

### balanceOf() - gas cost

Costly operations for a token transfer are typically as follows.
- chagne ownership (1 slot update),
- potentially check an operator allowance (1 slot read),
- potentially check a single approval (1 slot read),
- update sender balance (1 slot update or deletion),
- update receiver balance (1 slot update or creation),
- delete a single approval (1 slot deletion even if is zero),
- emit Transfer event - 1k gas.

### balanceOf() - reasoning

The function `balanceOf()` is a part of the standard.

