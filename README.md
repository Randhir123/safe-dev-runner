# Development Containers with Podman or Docker

This repository contains a reusable development container image (`dev.dockerfile`) and a helper script (`dev.sh`) that launch a fully tooled shell for running arbitrary projects safely in an isolated environment. The script auto-detects [Podman](https://podman.io) or Docker and uses the available runtime.

## Features

- Ubuntu-based [VS Code devcontainers](https://github.com/devcontainers) base image with common CLI tools (curl, sqlite, ffmpeg, etc.).
- [Mise](https://mise.jdx.dev/) bootstraps Node.js, uv, ripgrep, fd, duckdb, codex CLI, pandoc, rclone, csvq, and GitHub CLI.
- Runs as non-root user (UID/GID 1000) while preserving host file ownership.
- Mounts your project directory and developer caches (`pip`, `uv`, `npm`, etc.) for faster installs.
- Works with Podman on macOS/Linux (rootless VM) or Docker if available.

## Prerequisites

1. **Podman or Docker**
   - macOS: `brew install podman`, then `podman machine init` & `podman machine start`.
   - Linux: install via your package manager (e.g. `dnf install podman`).
   - Windows (WSL2): install Podman/Docker inside the Linux distribution.
2. (Optional) Configure a GitHub remote to push this repo to your account.

## Building the Image

```bash
./dev.sh --build
```

This pulls `mcr.microsoft.com/devcontainers/base:ubuntu`, installs packages, and tags the result as `dev:latest`. Re-run whenever you modify `dev.dockerfile`.

## Launching the Dev Shell

From any project directory:

```bash
/path/to/dev.sh
```

The script mounts the current directory and caches into the container. You drop into `/bin/bash` as user `vscode` (UID 1000). Install dependencies and run commands there—your working tree stays on the host.

### Exposing Ports to the Host

If you need to reach services from the host (e.g., Uvicorn on 9999), publish the port:

```bash
/path/to/dev.sh -p 9999:9999
```

You can add any `podman run`/`docker run` flag after `dev.sh` (e.g., `--env`, `--device`).

### Running Commands Non-Interactively

To execute a single command:

```bash
/path/to/dev.sh -c "pytest"
```

Podman/Docker run the command and exit afterwards.

## Common Workflows

### Clone and Work on a GitHub Project

```bash
cd ~/code
git clone https://github.com/someone/sample-project.git
cd sample-project
~/pers/dev_containers/dev.sh
```

Once inside the container you can run `uv run .` (Python app), `npm install`, `pytest`, etc. Install whatever additional tools you need.

### Server and Client in the Same Container

To develop safely with both server and client inside the container:

```bash
# terminal 1 inside container
uv run .  # starts server on 0.0.0.0:9999

# terminal 2 inside same container (use `podman exec`, `tmux`, or a second `dev.sh` shell)
uv run test_client.py  # hits http://localhost:9999
```

Because both processes live in the same container, no extra port publishing is required.

## Environment Variables and Mounts

- Override runtime explicitly: `CONTAINER_RUNTIME=podman ./dev.sh` or `CONTAINER_RUNTIME=docker ./dev.sh`.
- The script attempts to mount:
  - `$HOME/.codex → /home/vscode/.codex`
  - `$HOME/.config/gh → /home/vscode/.config/gh`
  - `$HOME/.cache/{pip,uv} → /home/vscode/.cache/{pip,uv}`
  - `$HOME/.npm → /home/vscode/.npm`
  - `$HOME/.local/share/uv → /home/vscode/.local/share/uv`
  - Current working directory → same path in container
- Missing host paths are skipped with a warning.

For SELinux hosts append `:z` or `:Z` labels in `dev.sh` to the `-v` flags.

## Publishing to GitHub

```bash
git remote add origin git@github.com:<username>/<repo>.git
git push -u origin main
```

Adjust remote URL/branch to match your workflow.

## Troubleshooting

- **Podman DNS issues (macOS)**: Restart the Podman machine, set DNS via `nmcli`, and ensure `resolvectl dns enp0s1` shows working nameservers.
- **Mount warnings**: Create the missing host directory or accept the warning; functionality continues without that mount.
- **Hardlink warnings from `uv`**: Set `UV_LINK_MODE=copy` if host/project directories reside on different filesystems.
- **Networking**: `localhost` inside the container refers to the container. Use `host.containers.internal` to reach host services from the container.

## License

MIT (update to match your preferred license).
