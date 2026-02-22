#!/usr/bin/env python3
"""
Inline dev-base module into a single main.tf for Coder deployment.

Coder's tar upload doesn't support subdirectories. This script:
1. Reads the template's main.tf and dev-base module files
2. Replaces module "dev-base" block with inlined resources
3. Maps var.* -> local.* in module code
4. Outputs a single deployable main.tf

Usage:
    python3 scripts/deploy.py <template-name>              # stdout
    python3 scripts/deploy.py <template-name> -o out.tf    # file
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MODULES = REPO / "modules" / "dev-base"

# Module files to inline (variables.tf and outputs.tf are interface-only)
MODULE_FILES = ["main.tf", "apps.tf", "ide.tf", "claude.tf"]


def find_matching_brace(text, start):
    """Find the position after the closing brace matching the opening brace at start."""
    depth = 1
    pos = start + 1
    while pos < len(text) and depth > 0:
        if text[pos] == "{":
            depth += 1
        elif text[pos] == "}":
            depth -= 1
        pos += 1
    return pos


def extract_module_block(text):
    """Extract module "dev-base" { ... } and parse its assignments.

    Returns (text_before, assignments_dict, text_after).
    """
    start_match = re.search(r'^module\s+"dev-base"\s*\{', text, re.MULTILINE)
    if not start_match:
        sys.exit('ERROR: module "dev-base" block not found')

    brace_pos = text.index("{", start_match.start())
    end_pos = find_matching_brace(text, brace_pos)

    block_text = text[start_match.start() : end_pos]
    before = text[: start_match.start()].rstrip("\n")
    after = text[end_pos:].lstrip("\n")

    assignments = parse_assignments(block_text)
    return before, assignments, after


def parse_assignments(block):
    """Parse key = value from an HCL module block, handling multi-line values."""
    lines = block.split("\n")[1:-1]  # strip module { and }
    assignments = {}
    i = 0

    while i < len(lines):
        line = lines[i].strip()
        if not line or line.startswith("#") or line.startswith("source"):
            i += 1
            continue

        m = re.match(r"(\w+)\s*=\s*(.*)", line)
        if not m:
            i += 1
            continue

        key = m.group(1)
        value_start = m.group(2).strip()
        depth = value_start.count("{") - value_start.count("}")

        if depth > 0:
            value_lines = [value_start]
            i += 1
            while i < len(lines) and depth > 0:
                vline = lines[i].rstrip()
                depth += vline.count("{") - vline.count("}")
                value_lines.append(vline)
                i += 1
            assignments[key] = "\n".join(value_lines)
        else:
            assignments[key] = value_start
            i += 1

    return assignments


def strip_terraform_block(text):
    """Remove the terraform { required_providers { ... } } block."""
    m = re.search(r"^terraform\s*\{", text, re.MULTILINE)
    if not m:
        return text
    brace_pos = text.index("{", m.start())
    end_pos = find_matching_brace(text, brace_pos)
    return (text[: m.start()].lstrip("\n") + text[end_pos:].lstrip("\n")).lstrip("\n")


def parse_variable_defaults(variables_tf_path):
    """Parse variables.tf to extract default values for optional variables.

    Returns dict of {var_name: default_value_string} for variables that have defaults.
    """
    if not variables_tf_path.exists():
        return {}

    text = variables_tf_path.read_text()
    defaults = {}

    # Find each variable block
    for m in re.finditer(r'^variable\s+"(\w+)"\s*\{', text, re.MULTILINE):
        var_name = m.group(1)
        brace_pos = text.index("{", m.start())
        end_pos = find_matching_brace(text, brace_pos)
        block = text[brace_pos + 1 : end_pos - 1]

        # Look for default = ... line
        default_match = re.search(r"^\s*default\s*=\s*(.*)", block, re.MULTILINE)
        if default_match:
            value = default_match.group(1).strip()
            # Handle multi-line defaults (e.g., default = {})
            depth = value.count("{") - value.count("}")
            if depth > 0:
                # Collect remaining lines until braces balance
                lines_after = block[default_match.end() :].split("\n")
                value_lines = [value]
                for line in lines_after:
                    depth += line.count("{") - line.count("}")
                    value_lines.append(line.rstrip())
                    if depth <= 0:
                        break
                value = "\n".join(value_lines)
            defaults[var_name] = value

    return defaults


def build_locals_block(assignments, variable_defaults):
    """Generate a locals { ... } block from module assignments + defaults for unpassed vars."""
    # Add defaults for any variable not explicitly passed
    merged = dict(assignments)
    for var_name, default_val in variable_defaults.items():
        if var_name not in merged:
            merged[var_name] = default_val

    lines = ["# --- Locals (module variable mappings) ---", "", "locals {"]
    for key, value in merged.items():
        if "\n" in value:
            lines.append(f"  {key} = {value}")
        else:
            lines.append(f"  {key:<23} = {value}")
    lines.append("}")
    return "\n".join(lines)


def inline_module_file(filepath):
    """Read a module file and replace var.* with local.*"""
    text = filepath.read_text()
    if filepath.name == "main.tf":
        text = strip_terraform_block(text)
    return re.sub(r"\bvar\.", "local.", text)


def main():
    if len(sys.argv) < 2:
        print("Usage: deploy.py <template-name> [-o output-file]", file=sys.stderr)
        sys.exit(1)

    template_name = sys.argv[1]
    output_file = None
    if "-o" in sys.argv:
        idx = sys.argv.index("-o")
        if idx + 1 >= len(sys.argv):
            sys.exit("ERROR: -o requires an output file path")
        output_file = sys.argv[idx + 1]

    template_tf = REPO / "templates" / template_name / "main.tf"
    if not template_tf.exists():
        sys.exit(f"ERROR: {template_tf} not found")

    # Step 1: Parse template — extract module block
    template_text = template_tf.read_text()
    before, assignments, after = extract_module_block(template_text)

    # Step 2: Build locals block (explicit assignments + defaults for unpassed vars)
    variable_defaults = parse_variable_defaults(MODULES / "variables.tf")
    locals_block = build_locals_block(assignments, variable_defaults)

    # Step 3: Inline module files with var.* -> local.*
    module_sections = []
    for fname in MODULE_FILES:
        fpath = MODULES / fname
        if fpath.exists():
            module_sections.append(inline_module_file(fpath))

    # Step 4: Combine
    parts = [before, "", locals_block]
    for section in module_sections:
        parts.append("")
        parts.append(section.strip())
    if after.strip():
        parts.append("")
        parts.append(after.strip())
    result = "\n".join(parts) + "\n"

    if output_file:
        Path(output_file).write_text(result)
        print(f"Written to {output_file}", file=sys.stderr)
    else:
        print(result)


if __name__ == "__main__":
    main()
