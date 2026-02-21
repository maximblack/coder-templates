# coder-templates

Coder workspace templates with a shared module architecture.

## Directory Structure

```
modules/
  dev-base/           Shared infrastructure: agent, container, IDEs, Claude Code
  playwright-mcp/     Config-only module: outputs MCP JSON for Playwright
templates/
  elixir/             Pente 5G core (Elixir/OTP + Phoenix)
  nodejs/             Node.js / TypeScript projects
  godot/              Godot 4.x game development
  template-creator/   Meta-template for creating/deploying Coder templates
```

## Two-Layer Architecture

**Modules** provide reusable infrastructure. **Templates** define presets and wire modules together.

- `dev-base` creates the Docker container, agent, volume, IDEs (code-server, Windsurf, Cursor, JetBrains), Claude Code, preview app, and AI task resource. Every template uses it.
- `playwright-mcp` is a config-only module (no resources). It computes MCP JSON that can be passed to dev-base's `mcp` variable.

Templates consist of a single `main.tf` that declares 4 parameters, a preset with defaults, and a `module "dev-base"` call.

## Standard Parameters

Every template defines these 4 `coder_parameter` data sources:

| Parameter | Type | Description |
|-----------|------|-------------|
| `system_prompt` | string/textarea | Claude Code system prompt |
| `setup_script` | string/textarea | Post-install script (runs once) |
| `container_image` | string | Docker image |
| `preview_port` | number | Port for the preview app |

Parameters MUST be in the root template (Coder validates presets before `terraform init`, so module-level parameters are not supported).

## Adding a New Template

1. Create `templates/<name>/main.tf`
2. Copy the boilerplate from an existing template (e.g., `nodejs/main.tf`)
3. Customize the `coder_workspace_preset` block:
   - `name`: preset display name
   - `system_prompt`: language/framework-specific guidance
   - `setup_script`: toolchain installation, repo clone, dev server start
   - `preview_port`: the port your dev server runs on
   - `container_image`: base Docker image
4. Customize the `module "dev-base"` call:
   - `project_dir`: working directory
   - `preview_display_name`: label in the Coder UI
   - `preview_icon`: emoji URL (`${data.coder_workspace.me.access_url}/emojis/<code>.png`)

## Coder Deployment

Coder's tar upload does not support subdirectories. To deploy a template, you must **inline** the dev-base resources into a single monolithic `main.tf`.

**CRITICAL**: You cannot use `source = "./"` — this causes infinite recursion because the module references itself. Instead, inline the dev-base resources directly.

The inlining process:
1. Start with the template's `main.tf` (parameters, preset, data sources)
2. Remove the `module "dev-base" { ... }` block entirely
3. Add a `locals` block mapping variable references to data source values
4. Paste the dev-base resources (agent, volume, container) using `local.*` and `data.*` references instead of `var.*`
5. Paste the apps, IDEs, and Claude Code blocks using the same approach
6. Upload the single `main.tf` via `coder_upload_tar_file` MCP tool or `coder templates push`

The `module "dev-base"` source path in the repo (`../../modules/dev-base`) is for local development only — it is never used in Coder deployment.

See the `template-creator` template's deployed version for a working example of the inlined approach.

## MCP Integration

To add Playwright MCP to a template:

```hcl
module "playwright" {
  source = "../../modules/playwright-mcp"
  # Optional overrides:
  # headless = false
  # browser  = "firefox"
}

module "dev-base" {
  source = "../../modules/dev-base"
  # ... other variables ...
  mcp = module.playwright.mcp_config
}
```

The `mcp` variable accepts any JSON string matching the claude-code module's MCP format:

```json
{"mcpServers": {"name": {"command": "...", "args": ["..."]}}}
```

## External Auth

Bitbucket Cloud is configured as an external auth provider (`bitbucket-cloud`). Templates that clone from Bitbucket reference it with:

```hcl
data "coder_external_auth" "bitbucket" {
  id       = "bitbucket-cloud"
  optional = true
}
```

`optional = true` allows the template to work without Bitbucket auth (e.g., the generic "Node.js App" preset). Presets that clone BB repos will prompt the user to authenticate on first use.

HTTPS clone URLs (`https://bitbucket.org/...`) work automatically — Coder's `GIT_ASKPASS` injects the OAuth token. No SSH keys or manual token management needed.

**Server-side setup** (Coder control plane env vars):
```
CODER_EXTERNAL_AUTH_<N>_ID=bitbucket-cloud
CODER_EXTERNAL_AUTH_<N>_TYPE=bitbucket-cloud
CODER_EXTERNAL_AUTH_<N>_CLIENT_ID=<OAuth consumer key>
CODER_EXTERNAL_AUTH_<N>_CLIENT_SECRET=<OAuth consumer secret>
```

The OAuth consumer is created in Bitbucket Cloud → Workspace settings → OAuth consumers. Required permissions: **Repository: Read**, **Account: Read**. Callback URL: `https://<coder-url>/external-auth/bitbucket-cloud/callback`.

## Conventions

- Default preset per template uses `default = true`; additional presets omit it
- Setup scripts are idempotent — safe to re-run on workspace restart
- Setup scripts check for existing installations before re-installing
- Clone logic: skip `git pull` if there are uncommitted or unpushed changes
- Container user is always `coder` (not root)
- IDE order: preview=0, code-server=1, Claude Code=999
