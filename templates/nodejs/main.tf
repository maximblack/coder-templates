terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.13"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "docker" {}

# --- Data Sources ---

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
data "coder_task" "me" {}

data "coder_external_auth" "bitbucket" {
  id       = "bitbucket-cloud"
  optional = true
}

# --- Parameters ---

data "coder_parameter" "system_prompt" {
  name         = "system_prompt"
  display_name = "System Prompt"
  type         = "string"
  form_type    = "textarea"
  description  = "System prompt for the agent with generalized instructions"
  mutable      = false
}

data "coder_parameter" "setup_script" {
  name         = "setup_script"
  display_name = "Setup Script"
  type         = "string"
  form_type    = "textarea"
  description  = "Script to run before running the agent"
  mutable      = false
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  type         = "string"
  default      = "codercom/example-universal:ubuntu"
  mutable      = false
}

data "coder_parameter" "preview_port" {
  name         = "preview_port"
  display_name = "Preview Port"
  description  = "The port the web app is running on to preview"
  type         = "number"
  default      = "3000"
  mutable      = false
}

# --- Preset ---

data "coder_workspace_preset" "default" {
  name    = "Node.js App"
  default = true
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are a helpful assistant for JavaScript and TypeScript development. You work with modern Node.js projects including Express, Fastify, Next.js, Remix, and similar frameworks. Stay focused, debug thoroughly, and don't change architecture without checking the user first.

      -- Tech Stack --
      - Node.js 22 LTS with nvm for version management
      - npm for package management (yarn/pnpm if lockfile present)
      - TypeScript preferred when tsconfig.json exists
      - Common frameworks: Express, Fastify, Next.js, Remix, Hono

      -- Tool Selection --
      - Built-in tools for file operations, git, builds, one-off commands
      - Use `npm test` or `npx jest` to run tests
      - Use `npm run dev` or `npm start` to start the dev server
      - Preview app runs on port 3000

      -- Context --
      Read CLAUDE.md or README.md in the project root for project-specific notes.
      Follow existing code style and linting rules (ESLint/Prettier).
      Dev server typically runs on port 3000.
    EOT

    "setup_script" = <<-EOT
    #!/bin/bash
    set -e

    PROJECT_DIR="/home/coder/projects/app"
    REPO_URL="$${REPO_URL:-}"

    # --- Clone or update repository ---
    mkdir -p /home/coder/projects
    if [ -n "$REPO_URL" ]; then
      if [ ! -d "$PROJECT_DIR/.git" ]; then
        rm -rf "$PROJECT_DIR"
        git clone "$REPO_URL" "$PROJECT_DIR"
      else
        cd "$PROJECT_DIR"
        git fetch
        if git diff-index --quiet HEAD -- && \
          [ -z "$(git status --porcelain --untracked-files=no)" ] && \
          [ -z "$(git log --branches --not --remotes)" ]; then
          echo "Repo is clean. Pulling latest changes..."
          git pull
        else
          echo "Repo has uncommitted or unpushed changes. Skipping pull."
        fi
      fi
    else
      mkdir -p "$PROJECT_DIR"
    fi

    # --- Install nvm + Node.js 22 LTS ---
    export NVM_DIR="$HOME/.nvm"
    if [ ! -d "$NVM_DIR" ]; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    grep -q 'NVM_DIR' ~/.bashrc 2>/dev/null || {
      echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
      echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> ~/.bashrc
    }

    nvm install 22
    nvm alias default 22

    # --- Install dependencies ---
    cd "$PROJECT_DIR"
    if [ -f "package.json" ]; then
      if [ -f "yarn.lock" ]; then
        npm i -g yarn && yarn install
      elif [ -f "pnpm-lock.yaml" ]; then
        npm i -g pnpm && pnpm install
      else
        npm install
      fi
    fi

    echo "========================================"
    echo "  Node.js dev environment ready!"
    echo "========================================"

    # Start dev server if script exists
    if [ -f "package.json" ] && grep -q '"dev"' package.json 2>/dev/null; then
      echo "  Starting dev server..."
      npm run dev > /tmp/dev-server.log 2>&1 &
    fi
    EOT

    "preview_port"    = "3000"
    "container_image" = "codercom/example-universal:ubuntu"
  }
}

data "coder_workspace_preset" "jpu_server" {
  name        = "JPU Server"
  description = "Express/Node.js backend (pente-server)"
  icon        = "/emojis/1f4e1.png"
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are working on the JPU Server — an Express/Node.js backend (pente-server).
      The main command is `npm start`. Focus on API development, Express routes,
      middleware, and backend logic.

      -- Tech Stack --
      - Node.js 22 LTS with Express
      - npm for package management
      - REST API backend

      -- Tool Selection --
      - Use `npm start` to run the server
      - Use `npm test` to run tests
      - Preview app runs on port 3000

      -- Context --
      Read CLAUDE.md or README.md in the project root for project-specific notes.
    EOT

    "setup_script" = <<-EOT
    #!/bin/bash
    set -e

    PROJECT_DIR="/home/coder/projects/app"
    REPO_URL="https://bitbucket.org/jpugit/jpu.git"

    # --- Clone or update repository ---
    mkdir -p /home/coder/projects
    if [ ! -d "$PROJECT_DIR/.git" ]; then
      rm -rf "$PROJECT_DIR"
      git clone "$REPO_URL" "$PROJECT_DIR"
    else
      cd "$PROJECT_DIR"
      git fetch
      if git diff-index --quiet HEAD -- && \
        [ -z "$$(git status --porcelain --untracked-files=no)" ] && \
        [ -z "$$(git log --branches --not --remotes)" ]; then
        echo "Repo is clean. Pulling latest changes..."
        git pull
      else
        echo "Repo has uncommitted or unpushed changes. Skipping pull."
      fi
    fi

    # --- Install nvm + Node.js 22 LTS ---
    export NVM_DIR="$$HOME/.nvm"
    if [ ! -d "$$NVM_DIR" ]; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    [ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"
    grep -q 'NVM_DIR' ~/.bashrc 2>/dev/null || {
      echo 'export NVM_DIR="$$HOME/.nvm"' >> ~/.bashrc
      echo '[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"' >> ~/.bashrc
    }

    nvm install 22
    nvm alias default 22

    # --- Install dependencies and start ---
    cd "$PROJECT_DIR"
    if [ -f "package.json" ]; then
      npm install
    fi

    echo "========================================"
    echo "  JPU Server environment ready!"
    echo "========================================"

    npm start > /tmp/dev-server.log 2>&1 &
    EOT

    "preview_port"    = "3000"
    "container_image" = "codercom/example-universal:ubuntu"
  }
}

data "coder_workspace_preset" "jpu_ui" {
  name        = "JPU UI"
  description = "AngularJS frontend"
  icon        = "/emojis/1f3a8.png"
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are working on the JPU UI — an AngularJS frontend application.
      The dev server runs with `node serve.js`. Focus on AngularJS components,
      directives, services, and UI development.

      -- Tech Stack --
      - Node.js 22 LTS
      - AngularJS
      - npm for package management

      -- Tool Selection --
      - Use `node serve.js` to start the dev server
      - Preview app runs on port 3000

      -- Context --
      Read CLAUDE.md or README.md in the project root for project-specific notes.
    EOT

    "setup_script" = <<-EOT
    #!/bin/bash
    set -e

    PROJECT_DIR="/home/coder/projects/app"
    REPO_URL="https://bitbucket.org/jpugit/jpu_ui.git"

    # --- Clone or update repository ---
    mkdir -p /home/coder/projects
    if [ ! -d "$PROJECT_DIR/.git" ]; then
      rm -rf "$PROJECT_DIR"
      git clone "$REPO_URL" "$PROJECT_DIR"
    else
      cd "$PROJECT_DIR"
      git fetch
      if git diff-index --quiet HEAD -- && \
        [ -z "$$(git status --porcelain --untracked-files=no)" ] && \
        [ -z "$$(git log --branches --not --remotes)" ]; then
        echo "Repo is clean. Pulling latest changes..."
        git pull
      else
        echo "Repo has uncommitted or unpushed changes. Skipping pull."
      fi
    fi

    # --- Install nvm + Node.js 22 LTS ---
    export NVM_DIR="$$HOME/.nvm"
    if [ ! -d "$$NVM_DIR" ]; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    [ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"
    grep -q 'NVM_DIR' ~/.bashrc 2>/dev/null || {
      echo 'export NVM_DIR="$$HOME/.nvm"' >> ~/.bashrc
      echo '[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"' >> ~/.bashrc
    }

    nvm install 22
    nvm alias default 22

    # --- Install dependencies and start ---
    cd "$PROJECT_DIR"
    if [ -f "package.json" ]; then
      npm install
    fi

    echo "========================================"
    echo "  JPU UI environment ready!"
    echo "========================================"

    node serve.js > /tmp/dev-server.log 2>&1 &
    EOT

    "preview_port"    = "3000"
    "container_image" = "codercom/example-universal:ubuntu"
  }
}

data "coder_workspace_preset" "pente_react" {
  name        = "Pente React"
  description = "React/Vite frontend with Radix UI"
  icon        = "/emojis/269b.png"
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are working on Pente React — a React + Vite frontend with Radix UI.
      The dev server runs with `npm run dev` on port 3000. Focus on React components,
      hooks, Vite configuration, and Radix UI patterns.

      -- Tech Stack --
      - Node.js 22 LTS
      - React with Vite
      - Radix UI component library
      - npm for package management

      -- Tool Selection --
      - Use `npm run dev` to start the Vite dev server
      - Use `npm test` to run tests
      - Preview app runs on port 3000

      -- Context --
      Read CLAUDE.md or README.md in the project root for project-specific notes.
    EOT

    "setup_script" = <<-EOT
    #!/bin/bash
    set -e

    PROJECT_DIR="/home/coder/projects/app"
    REPO_URL="https://bitbucket.org/jpugit/pente-react.git"

    # --- Clone or update repository ---
    mkdir -p /home/coder/projects
    if [ ! -d "$PROJECT_DIR/.git" ]; then
      rm -rf "$PROJECT_DIR"
      git clone "$REPO_URL" "$PROJECT_DIR"
    else
      cd "$PROJECT_DIR"
      git fetch
      if git diff-index --quiet HEAD -- && \
        [ -z "$$(git status --porcelain --untracked-files=no)" ] && \
        [ -z "$$(git log --branches --not --remotes)" ]; then
        echo "Repo is clean. Pulling latest changes..."
        git pull
      else
        echo "Repo has uncommitted or unpushed changes. Skipping pull."
      fi
    fi

    # --- Install nvm + Node.js 22 LTS ---
    export NVM_DIR="$$HOME/.nvm"
    if [ ! -d "$$NVM_DIR" ]; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    [ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"
    grep -q 'NVM_DIR' ~/.bashrc 2>/dev/null || {
      echo 'export NVM_DIR="$$HOME/.nvm"' >> ~/.bashrc
      echo '[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"' >> ~/.bashrc
    }

    nvm install 22
    nvm alias default 22

    # --- Install dependencies and start ---
    cd "$PROJECT_DIR"
    if [ -f "package.json" ]; then
      npm install
    fi

    echo "========================================"
    echo "  Pente React environment ready!"
    echo "========================================"

    npm run dev > /tmp/dev-server.log 2>&1 &
    EOT

    "preview_port"    = "3000"
    "container_image" = "codercom/example-universal:ubuntu"
  }
}

data "coder_workspace_preset" "pente_react_tests" {
  name        = "Pente React Tests"
  description = "Playwright E2E tests for pente-react"
  icon        = "/emojis/1f9ea.png"
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are working on Pente React Tests — a Playwright E2E test suite for the
      pente-react frontend. Run tests with `npx playwright test`. View reports on
      port 8080 with `npx playwright show-report --host 0.0.0.0 --port 8080`.

      -- Tech Stack --
      - Node.js 22 LTS
      - Playwright for E2E testing
      - npm for package management

      -- Tool Selection --
      - Use `npx playwright test` to run the test suite
      - Use `npx playwright test --ui` for interactive test runner
      - Use `npx playwright show-report --host 0.0.0.0 --port 8080` to view reports
      - Preview app runs on port 8080 (Playwright report)

      -- Context --
      Read CLAUDE.md or README.md in the project root for project-specific notes.
    EOT

    "setup_script" = <<-EOT
    #!/bin/bash
    set -e

    PROJECT_DIR="/home/coder/projects/app"
    REPO_URL="https://bitbucket.org/jpugit/pente-react-tests.git"

    # --- Clone or update repository ---
    mkdir -p /home/coder/projects
    if [ ! -d "$PROJECT_DIR/.git" ]; then
      rm -rf "$PROJECT_DIR"
      git clone "$REPO_URL" "$PROJECT_DIR"
    else
      cd "$PROJECT_DIR"
      git fetch
      if git diff-index --quiet HEAD -- && \
        [ -z "$$(git status --porcelain --untracked-files=no)" ] && \
        [ -z "$$(git log --branches --not --remotes)" ]; then
        echo "Repo is clean. Pulling latest changes..."
        git pull
      else
        echo "Repo has uncommitted or unpushed changes. Skipping pull."
      fi
    fi

    # --- Install nvm + Node.js 22 LTS ---
    export NVM_DIR="$$HOME/.nvm"
    if [ ! -d "$$NVM_DIR" ]; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    [ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"
    grep -q 'NVM_DIR' ~/.bashrc 2>/dev/null || {
      echo 'export NVM_DIR="$$HOME/.nvm"' >> ~/.bashrc
      echo '[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"' >> ~/.bashrc
    }

    nvm install 22
    nvm alias default 22

    # --- Install dependencies and Playwright browsers ---
    cd "$PROJECT_DIR"
    if [ -f "package.json" ]; then
      npm install
    fi
    npx playwright install --with-deps

    echo "========================================"
    echo "  Pente React Tests environment ready!"
    echo "========================================"
    EOT

    "preview_port"    = "8080"
    "container_image" = "codercom/example-universal:ubuntu"
  }
}

data "coder_workspace_preset" "jpu_tests" {
  name        = "JPU Tests"
  description = "WebdriverIO/Mocha E2E tests for jpu"
  icon        = "/emojis/1f50d.png"
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are working on JPU Tests — a WebdriverIO + Mocha E2E test suite for the
      JPU application. Run tests with `npx wdio run`. Focus on test specifications,
      page objects, and WebdriverIO configuration.

      -- Tech Stack --
      - Node.js 22 LTS
      - WebdriverIO for E2E testing
      - Mocha test framework
      - npm for package management

      -- Tool Selection --
      - Use `npx wdio run` to run the test suite
      - Use `npx wdio run -- --spec <file>` to run specific test files
      - Preview app runs on port 8080

      -- Context --
      Read CLAUDE.md or README.md in the project root for project-specific notes.
    EOT

    "setup_script" = <<-EOT
    #!/bin/bash
    set -e

    PROJECT_DIR="/home/coder/projects/app"
    REPO_URL="https://bitbucket.org/jpugit/jpu-tests.git"

    # --- Clone or update repository ---
    mkdir -p /home/coder/projects
    if [ ! -d "$PROJECT_DIR/.git" ]; then
      rm -rf "$PROJECT_DIR"
      git clone "$REPO_URL" "$PROJECT_DIR"
    else
      cd "$PROJECT_DIR"
      git fetch
      if git diff-index --quiet HEAD -- && \
        [ -z "$$(git status --porcelain --untracked-files=no)" ] && \
        [ -z "$$(git log --branches --not --remotes)" ]; then
        echo "Repo is clean. Pulling latest changes..."
        git pull
      else
        echo "Repo has uncommitted or unpushed changes. Skipping pull."
      fi
    fi

    # --- Install nvm + Node.js 22 LTS ---
    export NVM_DIR="$$HOME/.nvm"
    if [ ! -d "$$NVM_DIR" ]; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    [ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"
    grep -q 'NVM_DIR' ~/.bashrc 2>/dev/null || {
      echo 'export NVM_DIR="$$HOME/.nvm"' >> ~/.bashrc
      echo '[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"' >> ~/.bashrc
    }

    nvm install 22
    nvm alias default 22

    # --- Install dependencies ---
    cd "$PROJECT_DIR"
    if [ -f "package.json" ]; then
      npm install
    fi

    echo "========================================"
    echo "  JPU Tests environment ready!"
    echo "========================================"
    EOT

    "preview_port"    = "8080"
    "container_image" = "codercom/example-universal:ubuntu"
  }
}

# --- Module ---

module "dev-base" {
  source = "../../modules/dev-base"

  arch                  = data.coder_provisioner.me.arch
  workspace_id          = data.coder_workspace.me.id
  workspace_name        = data.coder_workspace.me.name
  workspace_start_count = data.coder_workspace.me.start_count
  owner_name            = data.coder_workspace_owner.me.name
  owner_id              = data.coder_workspace_owner.me.id
  owner_email           = data.coder_workspace_owner.me.email
  owner_full_name       = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  project_dir           = "/home/coder/projects/app"
  container_image       = data.coder_parameter.container_image.value
  setup_script          = data.coder_parameter.setup_script.value
  system_prompt         = data.coder_parameter.system_prompt.value
  ai_prompt             = data.coder_task.me.prompt
  preview_port          = data.coder_parameter.preview_port.value
  preview_display_name  = "Web App"
  preview_icon          = "${data.coder_workspace.me.access_url}/emojis/1f310.png"
}
