migrate((db) => {
    const dao = new Dao(db);

    const collection = new Collection({
        name: "projects",
        type: "base",
        // Public read, authenticated write
        listRule: "",
        viewRule: "",
        createRule: "@request.auth.id != ''",
        updateRule: "@request.auth.id != ''",
        deleteRule: "@request.auth.id != ''",
        schema: [
            {
                name: "title",
                type: "text",
                required: true,
                options: { min: 1, max: 200 },
            },
            {
                name: "slug",
                type: "text",
                required: true,
                options: { min: 1, max: 100 },
            },
            {
                name: "contributor",
                type: "text",
                required: true,
                options: { min: 1, max: 50 },
            },
            {
                name: "description",
                type: "text",
                options: { max: 500 },
            },
            {
                name: "content",
                type: "text",
            },
            {
                name: "images",
                type: "file",
                options: {
                    maxSelect: 10,
                    maxSize: 10485760, // 10MB per image
                    mimeTypes: ["image/jpeg", "image/png", "image/gif", "image/webp"],
                },
            },
            {
                name: "attachments",
                type: "file",
                options: {
                    maxSelect: 5,
                    maxSize: 52428800, // 50MB per file
                    mimeTypes: ["application/pdf"],
                },
            },
            {
                name: "tags",
                type: "json",
            },
        ],
    });

    return dao.saveCollection(collection);
}, (db) => {
    const dao = new Dao(db);
    const collection = dao.findCollectionByNameOrId("projects");
    return dao.deleteCollection(collection);
});
