"""Rules to define and package an Ansible role."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    "@rules_pkg//:mappings.bzl",
    "pkg_files",
    "strip_prefix",
)
load(
    "@rules_pkg//pkg:pkg.bzl",
    "pkg_tar",
    "pkg_zip",
)
load(":ansible_assembly_tools.bzl", "place_ansible_files")
load(
    ":ansibleinfo.bzl",
    "ANSIBLE_ROLE_STRUCT_INTERNAL_KEYS",
    "ANSIBLE_ROLE_TYPES",
    "AnsibleInfo",
    "extract_ansible_info_deps",
    "extract_ansible_role_structs",
    _create_role_struct = "create_role_struct",
    _new_ansibleinfo = "new_ansibleinfo",
)

visibility(["//ansible/..."])

def ansible_playbook_macro(
        *,
        name,
        src,
        files = [],
        deps = [],
        visibility = None,
        **kwargs):
    ansible_playbook(
        name = name,
        src = src,
        files = files,
        deps = deps,
        visibility = visibility,
        **kwargs
    )

    pkg_files(
        name = "%s_pkg_files" % name,
        srcs = [":%s" % name],
        strip_prefix = strip_prefix.from_pkg(),
        visibility = ["//visibility:private"],
        **kwargs
    )

    pkg_zip(
        name = "{}_archive".format(name),
        srcs = [
            "%s_pkg_files" % name,
        ],
        package_file_name = "{}.zip".format(name),
        stamp = -1,
        visibility = visibility,
        **kwargs
    )

    pkg_tar(
        name = "%s_tarball" % name,
        srcs = [
            "%s_pkg_files" % name,
        ],
        package_file_name = "{}.tar".format(name),
        stamp = -1,
        visibility = visibility,
        **kwargs
    )

def _place_ansible_roles(ctx, role_depsets):
    flattened_roles = depset(transitive = role_depsets).to_list()
    deps = extract_ansible_role_structs(flattened_roles)
    placed_files = []

    for path, struct in deps.items():
        for key, value in struct.items():
            if key in ANSIBLE_ROLE_STRUCT_INTERNAL_KEYS:
                continue
            name = struct["name"]

            # Supports relative roles
            placed_files += place_ansible_files(
                ctx,
                value.to_list(),
                src_root = path,
                dst_folder_relative_root = paths.join("roles", name),
                dst_subfolder = key,
            )

            # Supports roles called by absolute-ish path
            placed_files += place_ansible_files(
                ctx,
                value.to_list(),
                src_root = path,
                dst_folder_relative_root = paths.join("roles", path),
                dst_subfolder = key,
            )
    return placed_files

def _ansible_package_impl(ctx):
    fail("Not implemented!")

def _ansible_playbook_impl(ctx):
    deps = extract_ansible_info_deps(
        [info[AnsibleInfo] for info in ctx.attr.deps],
    )

    placed_files = []
    for key, value in deps.items():
        if key == "roles":
            placed_files += _place_ansible_roles(ctx, value)
        else:
            placed_files += place_ansible_files(
                ctx,
                depset(transitive = value).to_list(),
                src_root = ctx.label.package,
                dst_subfolder = key,
            )

    placed_files += place_ansible_files(
        ctx,
        ctx.files.src,
        include_full_path_symlinks = False,
    )

    placed_files += place_ansible_files(
        ctx,
        ctx.files.files,
    )

    runfiles = ctx.runfiles(files = placed_files)
    substitutions = {
        "{{playbook_file_name}}": ctx.file.src.short_path,
    }
    exec_file = ctx.actions.declare_file("playbook_exec.sh")
    ctx.actions.expand_template(
        template = ctx.file._exec_template,
        output = exec_file,
        substitutions = substitutions,
        is_executable = True,
    )
    return [DefaultInfo(executable = exec_file, runfiles = runfiles, files = depset(direct = placed_files)), _new_ansibleinfo()]

ansible_playbook = rule(
    implementation = _ansible_playbook_impl,
    doc = "Assembles an Ansible Playbook.",
    executable = True,
    attrs = {
        "src": attr.label(
            doc = "Ansible playbook",
            allow_single_file = [".yml"],
        ),
        "_exec_template": attr.label(
            doc = "Template for generating the executable playbook script.",
            default = Label(":ansible-playbook.sh.template"),
            allow_single_file = True,
        ),
        "files": attr.label_list(
            doc = "Additional data files to include with the playbook.",
            allow_files = True,
        ),
        "deps": attr.label_list(
            doc = "Ansible resources that these playbooks depend on.",
            providers = [AnsibleInfo],
        ),
    },
    provides = [DefaultInfo, AnsibleInfo],
)
