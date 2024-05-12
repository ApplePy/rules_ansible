load("@bazel_skylib//lib:paths.bzl", "paths")

visibility(["private"])

def place_ansible_files(
        ctx,
        files,
        *,
        src_root = None,
        dst_folder_relative_root = ".",
        dst_subfolder = ".",
        include_full_path_symlinks = True,
        include_relative_path_symlinks = True):
    """Generates symlinks for the Ansible files to put them in the correct dirs.

    Args:
      ctx: Context of the calling rule.
      files: The files that need to be placed in their correct directories.
      src_root: The files' original root directory - for generating relative symlinks.
      dst_folder_relative_root: Where symlinks should be placed.
      dst_subfolder: A subfolder in the destination folder where these files should be placed (i.e. tasks/).
      include_full_path_symlinks: Should a view of the directory tree be symlinked in.
      include_relative_path_symlinks: Should child files to this package get symlinked into their original locations.

    Returns:
      An array of file actions that create the desired directory structure.
    """
    if src_root == None:
        src_root = ctx.label.package

    outs = []
    for file in files:
        if include_full_path_symlinks:
            # Copy fully-qualified path for fully-qualified accesses.
            sym_path = paths.normalize(
                paths.join(
                    dst_folder_relative_root,
                    dst_subfolder,
                    file.short_path,
                ),
            )
            copied = ctx.actions.declare_file(sym_path)
            outs.append(copied)
            ctx.actions.symlink(output = copied, target_file = file)

        if include_relative_path_symlinks and file.short_path.startswith(src_root):
            raw_relative_path = paths.relativize(file.short_path, src_root)
            filename = paths.normalize(
                paths.join(
                    dst_folder_relative_root,
                    raw_relative_path if raw_relative_path.startswith(dst_subfolder) else paths.join(dst_subfolder, raw_relative_path),
                ),
            )
            symlink = ctx.actions.declare_file(filename)
            outs.append(symlink)
            ctx.actions.symlink(output = symlink, target_file = file)
    return outs
