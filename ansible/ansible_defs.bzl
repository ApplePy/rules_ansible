load(
    "//ansible/private:ansible_module.bzl",
    _ansible_module = "ansible_module",
    _ansible_module_util = "ansible_module_util",
    _ansible_plugin = "ansible_plugin",
)
load("//ansible/private:ansible_playbook.bzl", _ansible_playbook = "ansible_playbook_macro")
load("//ansible/private:ansible_role.bzl", _ansible_role = "ansible_role_macro")

ansible_module = _ansible_module

ansible_module_util = _ansible_module_util

ansible_plugin = _ansible_plugin

ansible_role = _ansible_role

ansible_playbook = _ansible_playbook
