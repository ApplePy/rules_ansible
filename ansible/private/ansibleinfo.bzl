"""Contains the AnsibleInfo provider and helpers for constructing them."""
visibility(["//ansible/..."])

ANSIBLE_INFO_TYPES = [
    "roles",
    "module_utils",
    "modules",
    "action_plugins",
    "cache_plugins",
    "callback_plugins",
    "connection_plugins",
    "filter_plugins",
    "inventory_plugins",
    "lookup_plugins",
    "test_plugins",
    "vars_plugins",
]

ANSIBLE_ROLE_TYPES = [
    "tasks",
    "templates",
    "handlers",
    "vars",
    "defaults",
    "meta",
    "files",
]

ANSIBLE_ROLE_STRUCT_INTERNAL_KEYS = [
    "name",
    "path",
]

def extract_ansible_role_structs(ansible_role_structs):
    # Role structs do not have nested roles.
    keys = [x for x in ANSIBLE_INFO_TYPES + ANSIBLE_ROLE_TYPES + ANSIBLE_ROLE_STRUCT_INTERNAL_KEYS if x != "roles"]

    return {
        role_struct.path: {
            key: getattr(role_struct, key) if getattr(role_struct, key) != None else []
            for key in keys
        }
        for role_struct in ansible_role_structs
    }

def extract_ansible_info_deps(ansible_infos):
    return {
        key: [
            getattr(info, key) if getattr(info, key) != None else []
            for info in ansible_infos
        ]
        for key in ANSIBLE_INFO_TYPES
    }

def merge_ansibleinfo(
        *,
        base_ansible_infos = [],
        roles = [],
        module_utils = [],
        modules = [],
        action_plugins = [],
        cache_plugins = [],
        callback_plugins = [],
        connection_plugins = [],
        filter_plugins = [],
        inventory_plugins = [],
        lookup_plugins = [],
        test_plugins = [],
        vars_plugins = []):
    """Creates a new AnsibleInfo from other instances.

    This function merges in the transitive dependencies from each other
    AnsibleInfo passed in as a base along with explicitly-provided values here
    to generate a merged AnsibleInfo for consumption.

    Args:
      base_ansible_infos: AnsibleInfos that this instance should depend on. The
        values get merged into a new AnsibleInfo along with the other args.
      roles: The role structs that this AnsibleInfo needs during complilation.
      module_utils: The module_utils that this AnsibleInfo needs during
        complilation.
      modules: The modules that this AnsibleInfo needs during complilation.
      action_plugins: The action_plugins that this AnsibleInfo needs during
        complilation.
      cache_plugins: The cache_plugins that this AnsibleInfo needs during
        complilation.
      callback_plugins: The callback_plugins that this AnsibleInfo needs during
        complilation.
      connection_plugins: The connection_plugins that this AnsibleInfo needs
        during complilation.
      filter_plugins: The filter_plugins that this AnsibleInfo needs during
        complilation.
      inventory_plugins: The inventory_plugins that this AnsibleInfo needs
        during complilation.
      lookup_plugins: The lookup_plugins that this AnsibleInfo needs during
        complilation.
      test_plugins: The test_plugins that this AnsibleInfo needs during
        complilation.
      vars_plugins: The vars_plugins that this AnsibleInfo needs during
        complilation.

    Returns:
      An AnsibleInfo instance containing the provided values merged with the
      base instances.
    """

    deps = extract_ansible_info_deps(base_ansible_infos)

    return new_ansibleinfo(
        roles = depset(roles, transitive = deps["roles"]),
        module_utils = depset(module_utils, transitive = deps["module_utils"]),
        modules = depset(modules, transitive = deps["modules"]),
        action_plugins = depset(
            action_plugins,
            transitive = deps["action_plugins"],
        ),
        cache_plugins = depset(
            cache_plugins,
            transitive = deps["cache_plugins"],
        ),
        callback_plugins = depset(
            callback_plugins,
            transitive = deps["callback_plugins"],
        ),
        connection_plugins = depset(
            connection_plugins,
            transitive = deps["connection_plugins"],
        ),
        filter_plugins = depset(
            filter_plugins,
            transitive = deps["filter_plugins"],
        ),
        inventory_plugins = depset(
            inventory_plugins,
            transitive = deps["inventory_plugins"],
        ),
        lookup_plugins = depset(
            lookup_plugins,
            transitive = deps["lookup_plugins"],
        ),
        test_plugins = depset(test_plugins, transitive = deps["test_plugins"]),
        vars_plugins = depset(vars_plugins, transitive = deps["vars_plugins"]),
    )

def new_ansibleinfo(
        *,
        roles = depset(),
        module_utils = depset(),
        modules = depset(),
        action_plugins = depset(),
        cache_plugins = depset(),
        callback_plugins = depset(),
        connection_plugins = depset(),
        filter_plugins = depset(),
        inventory_plugins = depset(),
        lookup_plugins = depset(),
        test_plugins = depset(),
        vars_plugins = depset()):
    return _new_ansibleinfo_raw(
        roles = roles,
        module_utils = module_utils,
        modules = modules,
        action_plugins = action_plugins,
        cache_plugins = cache_plugins,
        callback_plugins = callback_plugins,
        connection_plugins = connection_plugins,
        filter_plugins = filter_plugins,
        inventory_plugins = inventory_plugins,
        lookup_plugins = lookup_plugins,
        test_plugins = test_plugins,
        vars_plugins = vars_plugins,
    )

# buildifier: disable=unused-variable
def _ansibleinfo_init_banned(*args, **kwargs):
    fail("Do not call AnsibleInfo(). Use _new_ansibleinfo() instead.")

AnsibleInfo, _new_ansibleinfo_raw = provider(
    doc = "Directory structure data for base Ansible types.",
    fields = {
        "roles": "A depset of structs representing the files in roles.",
        "module_utils": "Files that should be stored in 'module_utils' directory.",
        "modules": "Files that should be stored in the 'modules' directory.",
        "action_plugins": "Action plugin files",
        "cache_plugins": "Cache plugin files",
        "callback_plugins": "Callback plugin files",
        "connection_plugins": "Connection plugin files",
        "filter_plugins": "Filter plugin files",
        "inventory_plugins": "Inventory plugin files",
        "lookup_plugins": "Lookup plugin files",
        "test_plugins": "Test plugin files",
        "vars_plugins": "Vars plugin files",
    },
    init = _ansibleinfo_init_banned,
)

def create_role_struct(
        ctx,
        *,
        tasks = depset(),
        templates = depset(),
        handlers = depset(),
        vars = depset(),
        defaults = depset(),
        meta = depset(),
        files = depset(),
        module_utils = depset(),
        modules = depset(),
        action_plugins = depset(),
        cache_plugins = depset(),
        callback_plugins = depset(),
        connection_plugins = depset(),
        filter_plugins = depset(),
        inventory_plugins = depset(),
        lookup_plugins = depset(),
        test_plugins = depset(),
        vars_plugins = depset()):
    """Creates a role struct for AnsibleInfo that defines what makes up a role.

    Note: the role's dependencies on other roles is not captured here. Role
    dependencies are aggregated at the AnsibleInfo level.

    Args:
      ctx: The context of the current rule being executed.
      tasks: The task files that are part of this role.
      templates: The template files that are part of this role.
      handlers: The handlers files that are part of this role.
      vars: The vars files that are part of this role.
      defaults: The defaults files that are part of this role.
      meta: The meta files that are part of this role.
      files: The generic files that are part of this role.
      module_utils: The module_utils that this AnsibleInfo needs during
        complilation.
      modules: The modules that that are part of this role.
      action_plugins: The action_plugins that are part of this role.
      cache_plugins: The cache_plugins that are part of this role.
      callback_plugins: The callback_plugins that are part of this role.
      connection_plugins: The connection_plugins that are part of this role.
      filter_plugins: The filter_plugins that are part of this role.
      inventory_plugins: The inventory_plugins that are part of this role.
      lookup_plugins: The lookup_plugins that are part of this role.
      test_plugins: The test_plugins that are part of this role.
      vars_plugins: The vars_plugins that are part of this role.

    Returns:
      A struct storing the depsets of all the files needed to build this role.
    """
    return struct(
        name = ctx.label.name,
        path = ctx.label.package,
        tasks = tasks,
        templates = templates,
        handlers = handlers,
        vars = vars,
        defaults = defaults,
        meta = meta,
        files = files,
        module_utils = module_utils,
        modules = modules,
        action_plugins = action_plugins,
        cache_plugins = cache_plugins,
        callback_plugins = callback_plugins,
        connection_plugins = connection_plugins,
        filter_plugins = filter_plugins,
        inventory_plugins = inventory_plugins,
        lookup_plugins = lookup_plugins,
        test_plugins = test_plugins,
        vars_plugins = vars_plugins,
    )
