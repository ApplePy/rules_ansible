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
load(":ansible_assembly_tools.bzl", "place_ansible_files")
load(
    ":ansibleinfo.bzl",
    "ANSIBLE_ROLE_TYPES",
    "AnsibleInfo",
    "extract_ansible_info_deps",
    _create_role_struct = "create_role_struct",
    _new_ansibleinfo = "new_ansibleinfo",
)

visibility(["//ansible/..."])

def ansible_role_macro(
        name,
        tasks = [],
        templates = [],
        handlers = [],
        vars = [],
        defaults = [],
        meta = [],
        files = [],
        deps = None,
        visibility = None,
        **kwargs):
    """Wrapping macro for ansible_role to also generate packaging targets.

    Args:
      name: Name of the ansible_role rule.
      tasks: Task files for the role.
      templates: Template files for the role.
      handlers: Handler files for the role.
      vars: Variable files for the role.
      defaults: Default variable files for the role.
      meta: Metadata files for the role.
      files: Arbitrary files for the role.
      deps: Ansible rules that a role depends on (i.e. modules)
      visibility: Visibility of the ansible_role rule and packaging rules.
      **kwargs: Miscellaneous pass-through arguments.
    """
    ansible_role(
        name = name,
        tasks = tasks,
        templates = templates,
        handlers = handlers,
        vars = vars,
        defaults = defaults,
        meta = meta,
        files = files,
        deps = deps,
        visibility = visibility,
        **kwargs
    )

    _ansible_role_files(
        name = "%s_files" % name,
        tasks = tasks,
        templates = templates,
        handlers = handlers,
        vars = vars,
        defaults = defaults,
        meta = meta,
        files = files,
        deps = deps,
        visibility = ["//visibility:private"],
        **kwargs
    )

    pkg_files(
        name = "%s_pkg_files" % name,
        srcs = ["%s_files" % name],
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

def _extract_ansible_role_deps(ctx):
    return extract_ansible_info_deps(
        [info[AnsibleInfo] for info in ctx.attr.deps],
    )

def _assert_main_task_exists(ctx):
    # Assert that this role has a main.yml task file.
    main_yml_found = False
    for task in ctx.files.tasks:
        path = ctx.label.package + "/tasks/main.yml"
        if (task.short_path == path):
            main_yml_found = True
    if not main_yml_found:
        fail("main.yml task file not found.")

def _ansible_role_files_impl(ctx):
    _assert_main_task_exists(ctx)

    deps = _extract_ansible_role_deps(ctx)
    placed_files = []

    for key, value in deps.items():
        # Ignore roles since we're not packaging up roles we depend on.
        if key == "roles":
            continue
        if key == "modules":
            # modules are stored in a 'library' folder instead for roles.
            key = "library"
        placed_files += place_ansible_files(
            ctx,
            depset(transitive = value).to_list(),
            src_root = ctx.label.package,
            dst_folder_relative_root = ".",
            dst_subfolder = key,
        )

    for key in ANSIBLE_ROLE_TYPES:
        placed_files += place_ansible_files(
            ctx,
            getattr(ctx.files, key),
            src_root = ctx.label.package,
            dst_folder_relative_root = ".",
            dst_subfolder = key,
        )

    # Role dependencies are intentionally not added here as they can be built
    # separately. Role deps only tracked for playbook rules.
    return DefaultInfo(files = depset(direct = placed_files))

def _ansible_role_impl(ctx):
    _assert_main_task_exists(ctx)

    deps = _extract_ansible_role_deps(ctx)

    role_struct = _create_role_struct(
        ctx,
        tasks = depset(ctx.files.tasks),
        templates = depset(ctx.files.templates),
        handlers = depset(ctx.files.handlers),
        vars = depset(ctx.files.vars),
        defaults = depset(ctx.files.defaults),
        meta = depset(ctx.files.meta),
        files = depset(ctx.files.files),
        module_utils = depset(transitive = deps["module_utils"]),
        modules = depset(transitive = deps["modules"]),
        action_plugins = depset(transitive = deps["action_plugins"]),
        cache_plugins = depset(transitive = deps["cache_plugins"]),
        callback_plugins = depset(transitive = deps["callback_plugins"]),
        connection_plugins = depset(transitive = deps["connection_plugins"]),
        filter_plugins = depset(transitive = deps["filter_plugins"]),
        inventory_plugins = depset(transitive = deps["inventory_plugins"]),
        lookup_plugins = depset(transitive = deps["lookup_plugins"]),
        test_plugins = depset(transitive = deps["test_plugins"]),
        vars_plugins = depset(transitive = deps["vars_plugins"]),
    )

    ansible_info = _new_ansibleinfo(
        roles = depset(direct = [role_struct], transitive = deps["roles"]),
    )

    return ansible_info

_SHARED_ATTRS = {
    "tasks": attr.label_list(
        doc = "Task files for the role.",
        allow_files = [".yml"],
    ),
    "templates": attr.label_list(
        doc = "Template files for the role.",
        allow_files = [".j2"],
    ),
    "handlers": attr.label_list(
        doc = "Handler files for the role.",
        allow_files = [".yml"],
    ),
    "vars": attr.label_list(
        doc = "Variable files for the role.",
        allow_files = [".yml"],
    ),
    "defaults": attr.label_list(
        doc = "Default variable files for the role.",
        allow_files = [".yml"],
    ),
    "meta": attr.label_list(
        doc = "Metadata files for the role.",
        allow_files = [".yml"],
    ),
    "files": attr.label_list(
        doc = "Arbitrary files for the role.",
        allow_files = True,
    ),
    "deps": attr.label_list(
        doc = "Ansible rules that a role depends on (i.e. modules)",
        providers = [AnsibleInfo],
    ),
}

_ansible_role_files = rule(
    implementation = _ansible_role_files_impl,
    attrs = _SHARED_ATTRS,
    doc = "An auxilary ansbile_role rule to lay out files for packaging as a standalone distributable.",
    provides = [DefaultInfo],
)

ansible_role = rule(
    implementation = _ansible_role_impl,
    attrs = _SHARED_ATTRS,
    doc = "An Ansible role",
    provides = [AnsibleInfo],
)
