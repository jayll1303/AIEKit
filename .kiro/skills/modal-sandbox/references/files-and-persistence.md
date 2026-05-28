# Files And Persistence

Use this reference when the task moves files into or out of a sandbox, or when sandbox data must survive restarts.

## Build-Time Inputs

- Use `Image.add_local_file(...)` when one local file should be present when the sandbox starts.
- Use `Image.add_local_dir(...)` when a local directory should be baked into the image.
- Use build-time image inputs when the files are static and known before sandbox creation.

## Runtime File Access — New Filesystem API (SDK 1.4.0+)

The new `sb.filesystem.*` API replaces the deprecated `sandbox.open()`, `sandbox.ls()`, `sandbox.mkdir()`, `sandbox.rm()` methods.

### Text and Binary IO

- `sb.filesystem.write_text(path, content)` — write text to a file on the sandbox.
- `sb.filesystem.read_text(path)` — read text from a file on the sandbox.
- `sb.filesystem.write_bytes(path, data)` — write binary data.
- `sb.filesystem.read_bytes(path)` — read binary data.

### File Transfers

- `sb.filesystem.copy_from_local(local_path, remote_path)` — upload a local file to the sandbox.
- `sb.filesystem.copy_to_local(remote_path, local_path)` — download a file from the sandbox.

### Directory Operations (SDK 1.4.2+)

- `sb.filesystem.make_directory(path)` — create a directory on the sandbox filesystem.
- `sb.filesystem.remove(path)` — delete a file or directory from the sandbox filesystem.

### Listing and Metadata (SDK 1.4.3+)

- `sb.filesystem.list_files(path)` — list entries with metadata in a directory.
- `sb.filesystem.stat(path)` — get metadata for a specific file/symlink/directory.

### Deprecated Methods (DO NOT USE)

- `sandbox.open(path, mode)` — replaced by `sb.filesystem.write_text/read_text/write_bytes/read_bytes`.
- `sandbox.ls(path)` — replaced by `sb.filesystem.list_files(path)`.
- `sandbox.mkdir(path)` — replaced by `sb.filesystem.make_directory(path)`.
- `sandbox.rm(path)` — replaced by `sb.filesystem.remove(path)`.

## Persistent Storage

- Use a Volume when files must persist across sandbox restarts or be shared with later sandboxes.
- Use a CloudBucketMount when the workload is already organized around object storage.
- Prefer Volumes for agent workspaces, code interpreter state, and user project files.
- Use `sb.reload_volumes()` to trigger a reload of all mounted Volumes inside a running sandbox.

## Image Mounting

- Use `sb.mount_image(path, image)` to mount a snapshot or image at a specific path.
- Use `sb.unmount_image(path)` to remove a previously mounted image and reveal the underlying filesystem (SDK 1.4.2+).
- Use `modal.Image.from_scratch()` to create an empty image for lightweight filesystem mounts.

## Sync Tradeoffs

- Expect Volume writes to sync back on termination unless the task explicitly uses the relevant sync path.
- Expect CloudBucketMount updates to sync automatically.
- Use snapshots when the task wants a restorable filesystem image rather than a shared writable store.
