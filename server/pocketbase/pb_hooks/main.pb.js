/// <reference path="../pb_data/types.d.ts" />

// Trigger a site rebuild whenever a project is created, updated, or deleted.
// Rebuild runs synchronously — for a small site this is typically < 2 seconds.

function triggerRebuild(label) {
    try {
        $os.exec("bash", ["-c", "/home/garden/scripts/rebuild.sh >> /home/garden/logs/rebuild.log 2>&1"]);
        console.log("[garden] Rebuild triggered by:", label);
    } catch (err) {
        console.error("[garden] Rebuild failed:", err);
    }
}

onRecordAfterCreateRequest((e) => {
    triggerRebuild("create:" + e.record.id);
}, "projects");

onRecordAfterUpdateRequest((e) => {
    triggerRebuild("update:" + e.record.id);
}, "projects");

onRecordAfterDeleteRequest((e) => {
    triggerRebuild("delete:" + e.record.id);
}, "projects");
