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

Coder's tar upload does not support subdirectories. To deploy a template, flatten all files into a single directory:

```bash
# Combine dev-base module + template into flat structure
cp modules/dev-base/*.tf /tmp/upload/
cp templates/elixir/main.tf /tmp/upload/

# Fix module source path (from relative to local)
sed -i 's|source.*=.*"../../modules/dev-base"|source = "./"|' /tmp/upload/main.tf

# Upload via MCP or CLI
```

The `source = "../../modules/dev-base"` path is for local development. When uploading to Coder, it must be rewritten to `"./"` since all files are in one directory.

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

## Conventions

- One preset per template (set `default = true`)
- Setup scripts are idempotent — safe to re-run on workspace restart
- Setup scripts check for existing installations before re-installing
- Clone logic: skip `git pull` if there are uncommitted or unpushed changes
- Container user is always `coder` (not root)
- IDE order: preview=0, code-server=1, Claude Code=999
