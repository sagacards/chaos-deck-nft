import AdminsFactory "../Admins";


module Assets {

    public type Tag = Text;
    
    public type FilePath = Text;

    public type Color = Text;

    public type State = {
        Admins : AdminsFactory.make;
        assets : [Record];
    };

    public type Asset = {
        contentType : Text;
        payload     : [Blob];
    };

    public type Record = {
        asset   : Asset;
        meta    : Meta;
    };

    public type Meta = {
        tags        : [Tag];
        filename    : FilePath;
        name        : Text;
        description : Text;
    };

    public type AssetManifest = [{}];

}