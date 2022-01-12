import Ext "mo:ext/Ext";
import Cap "mo:cap/Cap";

import AdminsFactory "../Admins";
import AssetsFactory "../Assets";


module Tokens {

    public type State = {
        Admins  : AdminsFactory.make;
        CAP     : Cap.Cap;
        canister: Principal;
        thefool : Principal;
        tokens  : [(TokenIndex, Token)];
    };

    public type TokenIndex = Nat32;

    public type Token = {
        owner       : Ext.AccountIdentifier;
        metadata    : MetaData;
    };

    public type Listing = {
        locked : ?Int;
        seller : Principal;
        price  : Nat64;
    };

    public type TokenExt = (TokenIndex, ?[Listing], ?[Nat8]);

    public type MetaData = {
        name        : Text;
        description : Text;
        image       : Text;
        thumbnail   : Text;
        artists     : [Text];
        cards       : [Card];
    };

    public type Card = {
        index   : Nat8;
        chaos   : Nat8;
        image   : Text;
    };

    public type Suit = {
        #Major;
        #Wands;
        #Pentacles;
        #Swords;
        #Cups;
    };

};