// 3rd Party Imports

import AccountIdentifier "mo:principal/AccountIdentifier";
import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Ext "mo:ext/Ext";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Random "mo:base/Random";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

// Project Imports

import AssetTypes "../Assets/types";

// Module Imports

import Types "types";


module TokensFactory {

    public class make (state : Types.State) {


        ////////////////////////
        // Utils / Internals //
        //////////////////////

        public func _getOwner (i : Nat32) : ?Types.Token {
            ledger.get(i);
        };

        public func _isOwner (
            caller      : Ext.AccountIdentifier,
            tokenIndex  : Ext.TokenIndex,
        ) : Bool {
            let token = switch (_getOwner(tokenIndex)) {
                case (?t) {
                    Text.map(caller, Prim.charToUpper) == Text.map(t.owner, Prim.charToUpper);
                };
                case _ false;
            };
        };

        // Turn a principal and a subaccount into an uppercase textual account id.
        func _accountId(
            principal   : Principal,
            subaccount  : ?Ext.SubAccount,
        ) : Ext.AccountIdentifier {
            let aid = AccountIdentifier.fromPrincipal(principal, subaccount);
            Text.map(AccountIdentifier.toText(aid), Prim.charToUpper);
        };

        // Generate a random deck of tarot cards from the available assets.
        // We know that there are 8 variations for each card.
        func generateDeck () : async [Types.Card] {
            let cards = Buffer.Buffer<Nat>(0);
            var seed = Random.Finite(await Random.blob());
            var index = 0;
            while (index < 79) {
                switch (seed.range(3)) {
                    case (?rando) {
                        cards.add(rando + 1);
                        index += 1;
                    };
                    case _ {
                        seed := Random.Finite(await Random.blob());
                    };
                };
            };
            let deck = Array.mapEntries<Nat, Types.Card>(cards.toArray(), func (chaos, index) {
                {
                    index = Nat8.fromNat(index);
                    chaos = Nat8.fromNat(chaos);
                    image = "chaos-" # Nat.toText(chaos) # "-card-" # Nat.toText(index) # ".webp";
                }
            });
            assert validateDeck(deck);
            deck;
        };

        func validateDeck (
            deck : [Types.Card]
        ) : Bool {
            if (deck.size() != 79) return false;
            return true;
        };

        // Decodes an ext token id
        public func decodeToken (tid : Text) : {
            index       : Nat32;
            canister    : [Nat8];
        } {
            let principal = Principal.fromText(tid);
            let bytes = Blob.toArray(Principal.toBlob(Principal.fromText(tid)));
            var index : Nat8 = 0;
            var _canister : [Nat8] = [];
            var _token_index : [Nat8] = [];
            var _tdscheck : [Nat8] = [];
            var length : Nat8 = 0;
            let tds : [Nat8] = [10, 116, 105, 100]; //b"\x0Atid"
            for (b in bytes.vals()) {
                length += 1;
                if (length <= 4) {
                    _tdscheck := Array.append(_tdscheck, [b]);
                };
                if (length == 4) {
                    if (Array.equal(_tdscheck, tds, Nat8.equal) == false) {
                        return {
                            index = 0;
                            canister = bytes;
                        };
                    };
                };
            };
            for (b in bytes.vals()) {
                index += 1;
                if (index >= 5) {
                    if (index <= (length - 4)) {            
                        _canister := Array.append(_canister, [b]);
                    } else {
                        _token_index := Array.append(_token_index, [b]);
                    };
                };
            };
            let v : {
                index       : Nat32;
                canister    : [Nat8];
            } = {
                index = bytestonat32(_token_index);
                canister = _canister;
            };
            return v;
        };

        private func bytestonat32(b : [Nat8]) : Nat32 {
            var index : Nat32 = 0;
            Array.foldRight<Nat8, Nat32>(b, 0, func (u8, accum) {
                index += 1;
                accum + Nat32.fromNat(Nat8.toNat(u8)) << ((index-1) * 8);
            });
        };

        // Retrieve a token.
        public func getToken (
            index : Types.TokenIndex,
        ) : ?Types.Token {
            ledger.get(index);
        };

        // Get all minted tokens.
        public func _getMinted () : [Ext.TokenIndex] {
            let minted = Buffer.Buffer<Ext.TokenIndex>(0);
            var i : Nat32 = 0;
            while (Nat32.toNat(i) < state.supply) {
                if (not Option.isNull(ledger.get(i))) {
                    minted.add(i);
                };
                i += 1;
            };
            return minted.toArray();
        };


        ////////////
        // State //
        //////////


        // Token ownership ledger.
        var ledger = HashMap.HashMap<Types.TokenIndex, Types.Token>(0, Nat32.equal, func (a) { a; });

        // Whitelist for the airdrop (doesn't need to be stable.)
        var whitelist : [Ext.AccountIdentifier] = [];

        // Provision ledger from stable state.
        ledger := HashMap.fromIter<
            Types.TokenIndex,
            Types.Token
        >(
            Iter.fromArray(state.tokens),
            state.tokens.size(),
            Nat32.equal,
            func (a) { a; },
        );

        // Dump module state into a stable format.
        public func toStable () : {
            ledger  : [(Types.TokenIndex, Types.Token)];
        } {
            {
                ledger = Iter.toArray(ledger.entries());
            }
        };


        ////////////////
        // Admin API //
        //////////////


        // Generates the whitelist for the airdrop.
        // We're airdropping this to the owners of The Fool.
        // @auth: admin
        public func buildWhitelist (
            caller : Principal,
        ) : async () {
            assert state.Admins._isAdmin(caller);
            let can : actor {
                readLedger : () -> async [?{
                    createdAt  : Int;
                    owner      : Ext.AccountIdentifier;
                    txId       : Text;
                }];
            } = actor(Principal.toText(state.thefool));
            whitelist := Array.mapFilter<
                ?{
                    createdAt  : Int;
                    owner      : Ext.AccountIdentifier;
                    txId       : Text;
                },
                Ext.AccountIdentifier,
            >(await can.readLedger(), func (a) {
                switch (a) {
                    case (?t) return ?t.owner;
                    case (_) return null;
                };
            });
        };

        // Read the whitelist
        // @auth: admin

        public func readWhitelist (
            caller : Principal,
        ) : [Ext.AccountIdentifier] {
            assert state.Admins._isAdmin(caller);
            whitelist;
        };

        // Use this to airdrop the entire initial supply in one call.
        // @auth: admin
        public func airdrop (
            caller : Principal,
        ) : async () {
            assert state.Admins._isAdmin(caller);
            // We expect there to be a list of 117 ownership principals from the fool.
            assert whitelist.size() == state.supply;
            for (address in whitelist.vals()) {
                await mintRandom(caller, #address(address));
            };
        };

        // TODO: airdrop hackathon deck holders

        // Mint a random deck of cards to the destination.
        // @auth: admin
        public func mintRandom (
            caller  : Principal,
            to      : Ext.User,
        ) : async () {
            await mint(
                caller,
                to,
                await generateDeck(),
            )
        };

        // @auth: admin
        public func mint (
            caller  : Principal,
            to      : Ext.User,
            cards   : [Types.Card],
        ) : async () {
            // Make sure caller is admin.
            assert state.Admins._isAdmin(caller);

            // Make sure deck is a valid tarot deck.
            assert validateDeck(cards);

            // Get the next mint index.
            let index = Nat32.fromNat(ledger.size());

            // Mint a token to the destination address and store the card variants in the metadata.
            // TODO: Fill these fields
            ledger.put(index, {
                owner = Ext.User.toAccountIdentifier(to);
                metadata = {
                    artists = ["Jørgen Builder", "Google Deep Dream", "Pamela Coleman Smith"];
                    description = "A deck based on the original Rider Waite Smith art, parsed by Google deep dream. Each card is randomly selected from 8 different configurations.";
                    image = cards[78].image;
                    name = "Random Chaos #" # Nat32.toText(index + 1);
                    thumbnail = cards[78].image;
                    cards;
                };
            });

            // Log the mint with CAP.
            switch (await state.CAP.insert({
                    operation = "mint";
                    details = [
                        ("token", #Text(tokenId(state.canister, index))),
                        ("to", #Text(Ext.User.toAccountIdentifier(to))),  // This part maybe sucks. Could use Principal here.
                    ];
                    caller;
                })
            ) {
                case (#ok(_)) {};
                case (#err(_)) assert false; // Trap because we can't log the mint with CAP.
            };
        };


        /////////////////
        // Public API //
        ///////////////
        

        // @ext:core

        public func balance(
            canister : Principal,
            request : Ext.Core.BalanceRequest,
        ) : Ext.Core.BalanceResponse {
            let index = switch (Ext.TokenIdentifier.decode(request.token)) {
                case (#err(_)) { return #err(#InvalidToken(request.token)); };
                case (#ok(canisterId, tokenIndex)) {
                    if (canisterId != canister) return #err(#InvalidToken(request.token));
                    tokenIndex;
                };
            };

            let userId = Ext.User.toAccountIdentifier(request.user);
            switch (_getOwner(index)) {
                case (null) { #err(#InvalidToken(request.token)); };
                case (? token) {
                    if (Ext.AccountIdentifier.equal(userId, token.owner)) {
                        #ok(1);
                    } else {
                        #ok(0);
                    };
                };
            };
        };

        public func extensions() : [Ext.Extension] {
            ["@ext/common", "@ext/nonfungible"];
        };

        public func transfer(
            caller : Principal,
            request : Ext.Core.TransferRequest,
        ) : async Ext.Core.TransferResponse {
            let index = switch (Ext.TokenIdentifier.decode(request.token)) {
                case (#err(_)) { return #err(#InvalidToken(request.token)); };
                case (#ok(_, tokenIndex)) tokenIndex;
            };
            let token = switch (_getOwner(index)) {
                case (?t) t;
                case _ return #err(#Other("Token owner doesn't exist."));
            };
            let callerAccount = Text.map(AccountIdentifier.toText(AccountIdentifier.fromPrincipal(caller, request.subaccount)), Prim.charToUpper);
            let from = Text.map(Ext.User.toAccountIdentifier(request.from), Prim.charToUpper);
            let to = Text.map(Ext.User.toAccountIdentifier(request.to), Prim.charToUpper);
            let owner = Text.map(token.owner, Prim.charToUpper);
            if (owner != from) return #err(#Unauthorized("Owner \"" # owner # "\" is not caller \"" # from # "\""));
            if (from != callerAccount) return #err(#Unauthorized("Only the owner can do that."));
            ledger.put(index, {
                owner = to;
                metadata = token.metadata;
            });
            switch (state.CAP.insert({
                    operation = "transfer";
                    details = [
                        ("token", #Text(tokenId(state.canister, index))),
                        ("to", #Text(to)),  // This part maybe sucks. Could use Principal here.
                        ("from", #Text(from)),  // This part maybe sucks. Could use Principal here.
                        ("memo", #Slice(Blob.toArray(request.memo))),
                        ("balance", #U64(1)),
                    ];
                    caller;
                })
            ) {
                case (_) {};
            };
            #ok(Nat32.toNat(index));
        };

        // @ext:common

        public func metadata(
            caller  : Principal,
            tokenId : Ext.TokenIdentifier,
        ) : Ext.Common.MetadataResponse {
            let index = switch (Ext.TokenIdentifier.decode(tokenId)) {
                case (#err(_)) { return #err(#InvalidToken(tokenId)); };
                case (#ok(_, tokenIndex)) { tokenIndex; };
            };
            switch (_getOwner(index)) {
                case (null) { #err(#InvalidToken(tokenId)); };
                case (?token) { #ok(#nonfungible({metadata = ?Text.encodeUtf8("The Fool")})); };
            };
        };

        public func supply(
            tokenId : Ext.TokenIdentifier,
        ) : Ext.Common.SupplyResponse {
            let index = switch (Ext.TokenIdentifier.decode(tokenId)) {
                case (#err(_)) { return #err(#InvalidToken(tokenId)); };
                case (#ok(_, tokenIndex)) { tokenIndex; };
            };
            switch (_getOwner(index)) {
                case (null) { #ok(0); };
                case (? _)  { #ok(1); };
            };
        };

        // @ext:nonfungible

        public func bearer(
            tokenId : Ext.TokenIdentifier,
        ) : Ext.NonFungible.BearerResponse {
            let index = switch (Ext.TokenIdentifier.decode(tokenId)) {
                case (#err(_)) { return #err(#InvalidToken(tokenId)); };
                case (#ok(_, tokenIndex)) { tokenIndex; };
            };
            switch (_getOwner(index)) {
                case (null)    { #err(#InvalidToken(tokenId)); };
                case (? token) { #ok(token.owner); };
            };
        };

        // @ext:allowance

        public func allowance(
            caller  : Principal,
            request : Ext.Allowance.Request,
        ) : Ext.Allowance.Response {
            #err(#Other("disabled"));
        };

        public func approve(
            caller  : Principal,
            request : Ext.Allowance.ApproveRequest,
        ) : () {};

        // @ext:stoic integration

        public func tokens(
            caller  : Principal,
            accountId : Ext.AccountIdentifier
        ) : Result.Result<[Ext.TokenIndex], Ext.CommonError> {
            #ok(
                Array.map<
                    (Types.TokenIndex, Types.Token),
                    Types.TokenIndex
                >(
                    Iter.toArray(ledger.entries()),
                    func ((i, _)) { i },
                )
            );
        };
        
        public func tokens_ext(
            caller  : Principal,
            accountId : Ext.AccountIdentifier,
        ) : Result.Result<[Types.TokenExt], Ext.CommonError> {
            #ok(
                Array.map<
                    (Types.TokenIndex, Types.Token),
                    Types.TokenExt,
                >(
                    Iter.toArray(ledger.entries()),
                    func ((i, token)) {
                        (i, null, null)
                    },
                )
            );
        };

        // Non-standard EXT

        public func tokenId(
            canister : Principal,
            index : Ext.TokenIndex,
        ) : Ext.TokenIdentifier {
            Ext.TokenIdentifier.encode(canister, index);
        };

        public func read (index : ?Nat32) : [?Types.Token] {
            switch (index) {
                case (?i) [ledger.get(i)];
                case _ Array.map<
                    (Types.TokenIndex, Types.Token),
                    ?Types.Token
                >(
                    Iter.toArray(ledger.entries()),
                    func ((_, token)) { ?token },
                )
            };
        };

    };

};