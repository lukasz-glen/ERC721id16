# ERC721id16

Efficient Implementation of ERC721Enumerable with tokenId &lt; 2\*\*16.

The solution minimize gas cost of REC721 transfers while supporting the enumeration of owners' tokens.
It is assumed than minting and burning are much less frequent.
Moreover, minting technic can significantly affect how global enumeration is handled.
For that reasons, this implementation offers only base `_min()` and `_burn()` functions 
without implementation of `totalSupply()` and `tokenByIndex()`.

Token ids are less than 2\*\*16. 
Thanks to that implementation can be very efficient.
If owners' balances do not exceed several tokens,
a token transfer cost is comparable to a token transfer in a base ERC721 contract.

## List16 concept

Any tokenId is less than 2\*\*16. 
With this the total supply, a balance of any user, any index in enumeration are less than 2\*\*16.
So they fit in `uint16`.
The idea is to put more of such data within one storage slot which is 256 bits.

Enumerable requires to maintain wallets of users that support 
`tokenOfOwnerByIndex()` and `balanceOf()` functions.
A user's wallet is a list of owned token ids which are `uint16`.
And here is its layout.

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

Let's consider a scenario. An owner transfers a token another user. 
The owner has a few tokens, and the user has a few tokens.
There are the following storage operations:
- update the owner's wallet (1 slot update),
- update the user's wallet (1 slot update),
- update the token ownership and the token index (1 slot update),
- update the token index of replaced token (1 slot update), can be required, possibly not.

This is 4*5k gas for storage operations, plus 21k for a transaction, 
plus 1k for Transfer event plus some gas for other operations.
It is 43-44k gas in total what is pretty nice.
Notice that gas cost may vary significantly depending on a scenario.  

### Single approve

A typical implementation clears `_tokenApprovals` upon a transfer by default.
We provide a little gas optimisation.
An approval is not deleted even if it is read.
Instead, a token's transfer counter is attached to an approval.
It is set when approving.
A current token's transfer counter is stored with token's ownership.

```markdown
|                                      _owners[tokenId]                                         |
|-----------------------------------------------------------------------------------------------|
| user address (160 bits) | token index in user's wallet (16 bits) | transfer counter (80 bits) |
```

A token's transfer counter is increased at every transfer.
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
Both implementation assumes that a total supply is given at the constructor.

