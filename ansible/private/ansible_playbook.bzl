"""Rules to define and package an Ansible role."""

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
load(
    ":ansible_assembly_tools.bzl",
    "place_ansible_files",
    "place_ansible_roles",
)
load(
    ":ansibleinfo.bzl",
    "AnsibleInfo",
    "extract_ansible_info_deps",
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

def _ansible_package_impl(ctx):
    fail("Not implemented!")

def _ansible_playbook_impl(ctx):
    deps = extract_ansible_info_deps(
        [info[AnsibleInfo] for info in ctx.attr.deps],
    )

    placed_files = []
    for key, value in deps.items():
        if key == "roles":
            placed_files += place_ansible_roles(ctx, value)
        else:
            if key == "modules":
                # modules are stored in a 'library' folder instead.
                key = "library"
            placed_files += place_ansible_files(
                ctx,
                depset(transitive = value).to_list(),
                src_root = ctx.label.package,
                dst_subfolder = key,
            )

    placed_files += place_ansible_files(
        ctx,
        ctx.files.src,
        # Don't need to symlink this into the full path directory - it shouldn't
        # be called from there.
        include_full_path_symlinks = False,
    )

    placed_files += place_ansible_files(
        ctx,
        ctx.files.files,
        include_full_path_symlinks = True,
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
    return [DefaultInfo(
        executable = exec_file,
        runfiles = runfiles,
        files = depset(direct = placed_files),
    ), _new_ansibleinfo()]

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
