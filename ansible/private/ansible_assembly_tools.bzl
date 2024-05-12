"""A collection of reusable functions to help build Ansible outputs."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    ":ansibleinfo.bzl",
    "ANSIBLE_ROLE_STRUCT_INTERNAL_KEYS",
    "extract_ansible_role_structs",
)

visibility(["private"])

def place_ansible_roles(ctx, role_depsets):
    """Generates symlinks for Ansible roles for packaging.

    Args:
        ctx: Context of the calling rule.
        role_depsets: a list of depsets containing role structs.

    Returns:
      An array of file actions that create the desired directory structure.
    """
    flattened_roles = depset(transitive = role_depsets).to_list()
    deps = extract_ansible_role_structs(flattened_roles)
    placed_files = []

    for path, struct in deps.items():
        for key, value in struct.items():
            if key in ANSIBLE_ROLE_STRUCT_INTERNAL_KEYS:
                continue
            name = struct["name"]
            placed_files += place_ansible_files(
                ctx,
                value.to_list(),
                src_root = path,
                dst_folder_relative_root = paths.join("roles", name),
                dst_subfolder = key,
                # Add to the rule top collection instead of in a subdirectory.
                full_path_symlinks_root = ".",
                include_full_path_symlinks = True,
            )
    return placed_files

def place_ansible_files(
        ctx,
        files,
        *,
        src_root = None,
        dst_folder_relative_root = ".",
        dst_subfolder = ".",
        include_full_path_symlinks = True,
        full_path_symlinks_root = None,
        include_relative_path_symlinks = True):
    """Generates symlinks for the Ansible files to put them in the correct dirs.

    Args:
      ctx: Context of the calling rule.
      files: The files that need to be placed in their correct directories.
      src_root: The files' original root directory - for generating relative symlinks.
      dst_folder_relative_root: Where symlinks should be placed. Defaults to the current package.
      dst_subfolder: A subfolder in the destination folder where these files should be placed (i.e. tasks/). Defaults to the current package.
      include_full_path_symlinks: Should a view of the source directory tree be symlinked in.
      full_path_symlinks_root: The directory where full-path symlinks should be placed. Defaults to dst_folder_relative_root.
      include_relative_path_symlinks: Should child files to this package get symlinked into their original locations.

    Returns:
      An array of file actions that create the desired directory structure.
    """
    if src_root == None:
        src_root = ctx.label.package

    if full_path_symlinks_root == None:
        full_path_symlinks_root = dst_folder_relative_root

    outs = []
    for file in files:
        if include_full_path_symlinks:
            # Copy fully-qualified path for fully-qualified accesses.
            sym_path = paths.normalize(
                paths.join(
                    full_path_symlinks_root,
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
