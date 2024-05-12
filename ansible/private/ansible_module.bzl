"""Defines the module and plugin rules of Ansible."""

load(
    ":ansibleinfo.bzl",
    "AnsibleInfo",
    _merge_ansibleinfo = "merge_ansibleinfo",
)

visibility(["//ansible/..."])

def _ban_role_deps(ansible_infos):
    if True in [len(info.roles.to_list()) > 0 for info in ansible_infos]:
        fail("Cannot depend on a role.")

def _ansible_module_impl(ctx):
    transitive_ansibleinfos = [dep[AnsibleInfo] for dep in ctx.attr.deps if dep[AnsibleInfo] != None]

    _ban_role_deps(transitive_ansibleinfos)

    return [
        _merge_ansibleinfo(
            base_ansible_infos = transitive_ansibleinfos,
            modules = [ctx.file.src],
        ),
    ]

ansible_module = rule(
    implementation = _ansible_module_impl,
    attrs = {
        "src": attr.label(
            doc = "File that is the entrypoint for the module.",
            allow_single_file = True,
        ),
        "deps": attr.label_list(
            doc = "Module utils that provide code that the src uses.",
            providers = [AnsibleInfo],
        ),
    },
    doc = "Declares a module for use by other Ansible constructs.",
    provides = [AnsibleInfo],
)

def _ansible_module_util_impl(ctx):
    transitive_ansibleinfos = [dep[AnsibleInfo] for dep in ctx.attr.deps if dep[AnsibleInfo] != None]
    _ban_role_deps(transitive_ansibleinfos)
    return [
        _merge_ansibleinfo(base_ansible_infos = transitive_ansibleinfos, module_utils = ctx.files.srcs),
    ]

ansible_module_util = rule(
    implementation = _ansible_module_util_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "A collection of files that can be used by Ansible modules.",
            allow_files = True,
        ),
        "deps": attr.label_list(
            doc = "Module util dependencies - i.e. plugins",
            providers = [AnsibleInfo],
        ),
    },
    doc = "Bundles together files for use by Ansible Modules.",
    provides = [AnsibleInfo],
)

def _ansible_plugin_impl(ctx):
    transitive_ansibleinfos = [dep[AnsibleInfo] for dep in ctx.attr.deps if dep[AnsibleInfo] != None]
    _ban_role_deps(transitive_ansibleinfos)
    return [
        _merge_ansibleinfo(
            base_ansible_infos = transitive_ansibleinfos,
            action_plugins = [file for file in ctx.files.srcs if ctx.attr.type == "action"],
            cache_plugins = [file for file in ctx.files.srcs if ctx.attr.type == "cache"],
            callback_plugins = [file for file in ctx.files.srcs if ctx.attr.type == "callback"],
            connection_plugins = [file for file in ctx.files.srcs if ctx.attr.type == "connection"],
            filter_plugins = [file for file in ctx.files.srcs if ctx.attr.type == "filter"],
            inventory_plugins = [file for file in ctx.files.srcs if ctx.attr.type == "inventory"],
            lookup_plugins = [file for file in ctx.files.srcs if ctx.attr.type == "lookup"],
            test_plugins = [file for file in ctx.files.srcs if ctx.attr.type == "test"],
            vars_plugins = [file for file in ctx.files.srcs if ctx.attr.type == "vars"],
        ),
    ]

ansible_plugin = rule(
    implementation = _ansible_plugin_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "Plugin files",
            allow_files = [".py", ".par"],
        ),
        "type": attr.string(
            doc = "Type of Ansible plugin",
            mandatory = True,
            values = [
                "action",
                "cache",
                "callback",
                "connection",
                "filter",
                "inventory",
                "lookup",
                "test",
                "vars",
            ],
        ),
        "deps": attr.label_list(
            doc = "Plugin dependencies - i.e. module utils",
            providers = [AnsibleInfo],
        ),
    },
    doc = "Bundles together plugins for use by Ansible.",
    provides = [AnsibleInfo],
)
