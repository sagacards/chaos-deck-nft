// 3rd Party Imports

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Ext "mo:ext/Ext";
import Float "mo:base/Float";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

// Project Imports

import AssetTypes "../Assets/types";
import TarotData "../Tarot/data";

// Module Imports

import Types "types";


module {

    public class make (state : Types.State) {


        ////////////////////////
        // Internals / Utils //
        //////////////////////


        // Attempts to parse a nat from a path string.
        private func natFromText (
            text : Text
        ) : ?Nat {
            var match : ?Nat = null;
            let supply = state.Tokens._getMinted().size();
            for (i in Iter.range(0, supply - 1)) {
                if (Nat.toText(i) == text) {
                    match := ?i;
                };
            };
            match;
        };


        // Returns a 404 if given token isn't minted yet.
        private func mintedOr404 (
            index : Nat
        ) : ?Types.Response {
            switch (state.Tokens._getOwner(Nat32.fromNat(index))) {
                case (?_) null;
                case _ ?http404(?"Token not yet minted.");
            };
        };


        ////////////////
        // Renderers //
        //////////////


        // Craft an HTTP response from an Asset Record.
        private func renderAsset (
            asset : AssetTypes.Record,
        ) : Types.Response {
            {
                body = state.Assets._flattenPayload(asset.asset.payload);
                headers = [
                    ("Content-Type", asset.asset.contentType),
                    ("Access-Control-Allow-Origin", "*"),
                    ("Cache-Control", "max-age=31536000"), // Cache one year
                ];
                status_code = 200;
                streaming_strategy = null;
            }
        };


        // Renders an asset based with the given tags or 404.
        private func renderAssetWithTags (
            tags : [Text]
        ) : Types.Response {
            switch (state.Assets._findTags(tags)) {
                case (?asset) renderAsset(asset);
                case null http404(?"Missing preview asset.");
            };
        };

        // Renders the deck explorer threejs app with the given token index.
        private func renderDeckExplorerApp (
            index : Nat
        ) : Types.Response {
            switch (mintedOr404(index)) {
                case (?err) return err;
                case _ ();
            };
            let app = switch (state.Assets._findTag("preview-app")) {
                case (?a) {
                    switch (Text.decodeUtf8(state.Assets._flattenPayload(a.asset.payload))) {
                        case (?t) t;
                        case _ "";
                    }
                };
                case _ return http404(?"Missing preview app.");
            };
            // TODO: Update the app stuff
            return {
                body = Text.encodeUtf8(
                    "<!doctype html>" #
                    "<html>" #
                        app #
                        "<script>" #
                        "const token = window.token = " # Nat.toText(index) # ";" #
                        "const canister = window.canister = \"6e6eb-piaaa-aaaaj-qal6a-cai\";" #
                        "</script>" #
                    "</html>"
                );
                headers = [
                    ("Content-Type", "text/html"),
                    ("Cache-Control", "max-age=31536000"), // Cache one year
                ];
                status_code = 200;
                streaming_strategy = null;
            };
        };


        ////////////////////
        // Path Handlers //
        //////////////////


        // @path: /asset/<text>/
        // @path: /assets/<text>/
        // Serves an asset based on filename.
        private func httpAssetFilename (path : ?Text) : Types.Response {
            switch (path) {
                case (?path) {
                    switch (state.Assets.getAssetByName(path)) {
                        case (?asset) renderAsset(asset);
                        case _ http404(?"Asset not found.");
                    };
                };
                case _ return httpAssetManifest(path);
            };
        };


        // @path: /asset-manifest
        // Serves a JSON list of all assets in the canister.
        private func httpAssetManifest (path : ?Text) : Types.Response {
            {
                body = Text.encodeUtf8(
                    "[\n" #
                    Array.foldLeft<AssetTypes.Record, Text>(state.Assets.getManifest(), "", func (a, b) {
                        let comma = switch (a == "") {
                            case true "\t";
                            case false ", ";
                        };
                        a # comma # "{\n" #
                            "\t\t\"filename\": \"" # b.meta.filename # "\",\n" #
                            "\t\t\"url\": \"/assets/" # b.meta.filename # "\",\n" #
                            "\t\t\"description\": \"" # b.meta.description # "\",\n" #
                            "\t\t\"tags\": [" # Array.foldLeft<Text, Text>(b.meta.tags, "", func (a, b) {
                                let comma = switch (a == "") {
                                    case true "";
                                    case false ", ";
                                };
                                a # comma # "\"" # b # "\""
                            }) # "]\n" #
                        "\t}";
                    }) #
                    "\n]"
                );
                headers = [
                    ("Content-Type", "application/json"),
                ];
                status_code = 200;
                streaming_strategy = null;
            }
        };


        // @path: /
        private func httpIndex () : Types.Response {
            let supply = state.Tokens._getMinted().size();
            // TODO
            let (
                totalVolume,
                highestPriceSale,
                lowestPriceSale,
                currentFloorPrice,
                listingsCount,
                _,
                transactionsCount,
            ) = (
                0 : Nat64,
                0 : Nat64,
                0 : Nat64,
                0 : Nat64,
                0,
                0,
                0,
            );
            {
                body = Text.encodeUtf8("Chaos Tarot Decks\n"
                    # "---\n"
                    # "# Minted NFTs: " # Nat.toText(supply) # "\n"
                    # "Cycle Balance: " # Nat.toText(Cycles.balance() / 1_000_000_000_000) # "T\n"
                    # "---\n"
                    # "# Marketplace Listings: " # Nat.toText(listingsCount) # "\n"
                    # "# Marketplace Sales: " # Nat.toText(transactionsCount) # "\n"
                    # "Marketplace Sale Volume: " # Nat64.toText(totalVolume) # "\n"
                    # "Marketplace Largest Sale: " # Nat64.toText(highestPriceSale) # "\n"
                    # "Marketplace Smallest Sale: " # Nat64.toText(lowestPriceSale) # "\n"
                    # "Marketplace Floor Price: " # Nat64.toText(currentFloorPrice) # "\n");
                headers = [
                    ("Content-Type", "text/plain"),
                ];
                status_code = 200;
                streaming_strategy = null;
            };
        };


        // @path: *?tokenid
        // This is kinda the main view for NFTs. Built to integrate well with Stoic and Entrepot.
        public func httpEXT(request : Types.Request) : Types.Response {
            let tokenId = Iter.toArray(Text.tokens(request.url, #text("tokenid=")))[1];
            let { index } = state.Tokens.decodeToken(tokenId);
            switch (mintedOr404(Nat32.toNat(index))) {
                case (?err) return err;
                case _ ();
            };
            if (not Text.contains(request.url, #text("type=thumbnail"))) {
                return renderDeckExplorerApp(Nat32.toNat(index));
            };
            switch (state.Tokens.getToken(index)) {
                case (?token) {
                    let chaos = token.metadata.cards[78].chaos;
                    renderAssetWithTags([
                        "chaos-" # Nat8.toText(chaos),
                        "card-" # Nat8.toText(78),
                    ]);
                };
                case (_) http404(null);
            };
        };

        // @path: *?tokenindex=<nat>
        private func httpTokenIndex (request : Types.Request) : Types.Response {
            let index = Iter.toArray(Text.tokens(request.url, #text("tokenindex=")))[1];
            switch (natFromText(index)) {
                case (?i) {
                    if (not Text.contains(request.url, #text("type=thumbnail"))) {
                        return renderDeckExplorerApp(i);
                    };
                    switch (state.Tokens.getToken(Nat32.fromNat(i))) {
                        case (?token) {
                            let chaos = token.metadata.cards[78].chaos;
                            renderAssetWithTags([
                                "chaos-" # Nat8.toText(chaos),
                                "card-" # Nat8.toText(78),
                            ]);
                        };
                        case (_) http404(null);
                    };
                };
                case _ http404(?"No token at that index.");
            };
        };

        // @path: /<nat>(.web(p|m))?
        private func httpTokenRootView (
            tokens : [Text],
        ) : Types.Response {
            switch (natFromText(tokens[0])) {
                case (?index) {
                    // TODO: Render the card back for the given deck.
                    // TODO: Render the deck explorer view.
                    switch (state.Tokens.getToken(Nat32.fromNat(index))) {
                        case (?token) {
                            if (tokens.size() == 1) {
                                return renderDeckExplorerApp(index)
                            } else {
                                let chaos = token.metadata.cards[78].chaos;
                                return renderAssetWithTags([
                                    "chaos-" # Nat8.toText(chaos),
                                    "card-" # Nat8.toText(78),
                                ]);
                            };
                        };
                        case (_) return http404(null);
                    };
                };
                case _ ();
            };
            http404(null);
        };


        // @path: /manifest/<nat>
        private func httpDeckInfo (path : ?Text) : Types.Response {
            let index = switch (path) {
                case (?p) natFromText(p);
                case _ null;
            };
            switch (index) {
                case (?i) {
                    switch (mintedOr404(i)) {
                        case (?err) return err;
                        case _ ();
                    };
                    switch (state.Tokens.getToken(Nat32.fromNat(i))) {
                        case (?token) {
                            var response = "";
                            var j = 0;
                            while (j < 79) {
                                let info = TarotData.Cards[j];
                                response := response #
                                        (switch (response == "") {
                                            case true "";
                                            case false ",\n"
                                        })
                                        # "\t{\n"
                                        # "\n\t\t\"index\":" # Nat.toText(info.index) # ","
                                        # "\n\t\t\"number\":" # Nat.toText(info.number) # ","
                                        # "\n\t\t\"suit\": \"" # (switch (info.suit) {
                                            case (#wands) "wands";
                                            case (#trump) "trump";
                                            case (#swords) "swords";
                                            case (#cups) "cups";
                                            case (#pentacles) "pentacles";
                                        }) # "\","
                                        # "\n\t\t\"name\": \"" # info.name # "\","
                                        # "\n\t\t\"image\": \"/assets/" # token.metadata.cards[j].image # "\""
                                        # "\n\t\n}";
                                    j += 1;
                            };
                            return {
                                body = Text.encodeUtf8("[\n" # response # "\n]");
                                headers = [
                                    ("Content-Type", "application/json"),
                                    ("Access-Control-Allow-Origin", "*"),
                                ];
                                status_code = 200;
                                streaming_strategy = null;
                            };
                        };
                        case (_) return http404(null);
                    };
                };
                case null http404(?"Invalid index.");
            }
        };


        // A 404 response with an optional error message.
        private func http404(msg : ?Text) : Types.Response {
            {
                body = Text.encodeUtf8(
                    switch (msg) {
                        case (?msg) msg;
                        case null "Not found.";
                    }
                );
                headers = [
                    ("Content-Type", "text/plain"),
                ];
                status_code = 404;
                streaming_strategy = null;
            };
        };


        // A 400 response with an optional error message.
        private func http400(msg : ?Text) : Types.Response {
            {
                body = Text.encodeUtf8(
                    switch (msg) {
                        case (?msg) msg;
                        case null "Bad request.";
                    }
                );
                headers = [
                    ("Content-Type", "text/plain"),
                ];
                status_code = 400;
                streaming_strategy = null;
            };
        };


        //////////////////
        // Path Config //
        ////////////////


        let paths : [(Text, (path: ?Text) -> Types.Response)] = [
            ("asset", httpAssetFilename),
            ("assets", httpAssetFilename),
            ("asset-manifest", httpAssetManifest),
            ("manifest", httpDeckInfo),
        ];


        /////////////////////
        // Request Router //
        ///////////////////


        // This method is magically built into every canister on the IC
        // The request/response types used here are manually configured to mirror how that method works.
        public func request(request : Types.Request) : Types.Response {
            
            // Stoic wallet preview

            if (Text.contains(request.url, #text("tokenid"))) {
                return httpEXT(request);
            };

            if (Text.contains(request.url, #text("tokenindex"))) {
                return httpTokenIndex(request);
            };

            // Paths

            let path = Iter.toArray(Text.tokens(request.url, #text("/")));

            switch (path.size()) {
                case 0 return httpIndex();
                case 1 {
                    for ((key, handler) in Iter.fromArray(paths)) {
                    if (path[0] == key) return handler(null);
                    };
                    return httpTokenRootView(Iter.toArray(Text.tokens(path[0], #text("."))));
                };
                case 2 for ((key, handler) in Iter.fromArray(paths)) {
                    if (path[0] == key) return handler(?path[1]);
                };
                case _ for ((key, handler) in Iter.fromArray(paths)) {
                    if (path[0] == key) return handler(?path[1]);
                };
            };
            
            for ((key, handler) in Iter.fromArray(paths)) {
                if (path[0] == key) return handler(?path[1])
            };

            // 404

            return http404(?"Path not found.");
        };
    };
};
