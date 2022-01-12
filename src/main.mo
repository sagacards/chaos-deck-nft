import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Prelude "mo:base/Prelude";
import Principal "mo:base/Principal";
import Result "mo:base/Result";

import Cap "mo:cap/Cap";
import CapRouter "mo:cap/Router";
import Ext "mo:ext/Ext";

import AdminsFactory "Admins";
import AssetsFactory "Assets";
import AssetsTypes "Assets/types";
import TokensFactory "Tokens";
import TokensTypes "Tokens/types";
import HttpFactory "Http";
import HttpFactoryTypes "Http/types";

shared ({ caller = creator }) actor class InternetComputerNFTCanister (
    actorSelf       : Text,
    actorTheFool    : Text,
    actorCapRouter  : Text,
) = {


    ///////////////////
    // Stable State //
    /////////////////
    // All stable memory is defined here, then passed to independent modules.


    // Assets

    private stable var stableAssets : [AssetsTypes.Record] = [];

    // Admins

    private stable var stableAdmins : [Principal] = [creator];

    // Tokens

    private stable var stableTokens : [(TokensTypes.TokenIndex, TokensTypes.Token)] = [];

    // Upgrades

    system func preupgrade() {

        // Preserve assets
        stableAssets := Assets.toStable();

        // Preserve admins
        stableAdmins := Admins.toStable();

        // Preserve ledger
        let { ledger; } = Tokens.toStable();
        stableTokens := ledger;

    };

    system func postupgrade() {
        // Yeet
    };


    /////////////
    // Admins //
    ///////////


    let Admins = AdminsFactory.make({
        admins = stableAdmins;
    });

    public shared ({ caller }) func addAdmin (
        p : Principal,
    ) : async () {
        Admins.addAdmin(caller, p);
    };

    public query ({ caller }) func isAdmin (
        p : Principal,
    ) : async Bool {
        Admins.isAdmin(caller, p);
    };

    public shared ({ caller }) func removeAdmin (
        p : Principal,
    ) : async () {
        Admins.removeAdmin(caller, p);
    };

    public query func getAdmins () : async [Principal] {
        Admins.getAdmins();
    };


    /////////////
    // Assets //
    ///////////


    let Assets = AssetsFactory.make({
        Admins;
        assets = stableAssets;
    });

    // Admin API

    public shared ({ caller }) func upload (
        bytes : [Blob],
    ) : async () {
        Assets.upload(caller, bytes);
    };

    public shared ({ caller }) func uploadFinalize (
        contentType : Text,
        meta        : AssetsTypes.Meta,
    ) : async Result.Result<(), Text> {
        Assets.uploadFinalize(
            caller,
            contentType,
            meta,
        );
    };

    public shared ({ caller }) func uploadClear () : async () {
        Assets.uploadClear(caller);
    };

    public shared ({ caller }) func purgeAssets (
        confirm : Text,
        tag     : ?Text,
    ) : async Result.Result<(), Text> {
        Assets.purge(caller, confirm, tag);
    };


    //////////////////////////
    // Transaction History //
    ////////////////////////


    // CAP (Certified Asset Provenance) adds a transaction history layer to your tokens.
    // Under the hood, a central hub canister will spawn a companion canister dedicated
    // to this token canister's transaction history. We simply use `cap.insert` to log all
    // transactions.
    let CAP = Cap.Cap(?actorCapRouter);
    let CAPRouter : CapRouter.Self = actor(actorCapRouter);

    public shared func installCap () : async () {

        await CAP.handshake(
            actorSelf,
            1_000_000_000_000,
        );

    };


    /////////////
    // Tokens //
    ///////////


    let Tokens = TokensFactory.make({
        Admins;
        CAP;
        canister = Principal.fromText(actorSelf);
        thefool = Principal.fromText(actorTheFool);
        tokens = stableTokens;
    });

    public shared ({ caller }) func allowance(
        request : Ext.Allowance.Request,
    ) : async Ext.Allowance.Response {
        Tokens.allowance(caller, request);
    };
    
    public query ({ caller }) func metadata(
        tokenId : Ext.TokenIdentifier,
    ) : async Ext.Common.MetadataResponse {
        Tokens.metadata(caller, tokenId);
    };

    public shared ({ caller }) func approve(
        request : Ext.Allowance.ApproveRequest,
    ) : async () {
        Tokens.approve(caller, request);
    };

    public shared ({ caller }) func transfer(
        request : Ext.Core.TransferRequest,
    ) : async Ext.Core.TransferResponse {
        await Tokens.transfer(caller, request);
    };

    public query ({ caller }) func tokens(
        accountId : Ext.AccountIdentifier
    ) : async Result.Result<[Ext.TokenIndex], Ext.CommonError> {
        Tokens.tokens(caller, accountId);
    };
    
    public query ({ caller }) func tokens_ext(
        accountId : Ext.AccountIdentifier
    ) : async Result.Result<[TokensTypes.TokenExt], Ext.CommonError> {
        Tokens.tokens_ext(caller, accountId)
    };

    public query func tokenId(
        index : Ext.TokenIndex,
    ) : async Ext.TokenIdentifier {
        Tokens.tokenId(Principal.fromText(actorSelf), index);
    };

    public query ({ caller }) func readWhitelist () : async [Ext.TokenIdentifier] {
        Tokens.readWhitelist(caller);
    };

    public shared ({ caller }) func buildWhitelist () : async () {
        await Tokens.buildWhitelist(caller);
    };

    public shared ({ caller }) func airdrop () : async () {
        await Tokens.airdrop(caller);
    };

    public shared ({ caller }) func mintRandom (
        to  : Principal,
    ) : async () {
        await Tokens.mintRandom(caller, #principal(to));
    };

    public query func readLedger () : async [?TokensTypes.Token] {
        Tokens.read(null);
    };


    ///////////
    // HTTP //
    /////////


    let HTTP = HttpFactory.make({
        Assets;
        Admins;
        Tokens;
    });

    public query func http_request(request : HttpFactoryTypes.Request) : async HttpFactoryTypes.Response {
        HTTP.request(request);
    };

};