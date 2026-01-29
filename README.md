# AgentsOfAction 🛡️

A curated collection of Claude agents/skills for day-to-day productivity and workflow automation.

## What is this?

AgentsOfAction is a personal repository containing custom Claude agents (also known as "skills") that extend Claude's capabilities for various tasks and workflows. Each agent is designed to help with specific use cases and can be easily installed into your Claude Desktop or Claude Code environment.

## Installation

To use any agent from this collection:

### Method 1: Manual Installation

1. **Download the agent** you want to use from this repository
2. **Locate or create your skills directory**:
   - For global installation (all projects): `~/.claude/skills/`
   - For project-specific installation: `.claude/skills/` in your project root

3. **Copy the agent folder** into the skills directory:
   ```bash
   # For global installation
   cp -r /path/to/agent ~/.claude/skills/
   
   # For project-specific installation
   cp -r /path/to/agent ./.claude/skills/
   ```

4. **Create the directory if it doesn't exist**:
   ```bash
   mkdir -p ~/.claude/skills/
   ```

### Method 2: Clone Directly

```bash
# Clone the entire repository into your skills directory
git clone https://github.com/asbassan/AgentsOfAction.git ~/.claude/skills/
```

## Verification

After installation:

1. **Restart Claude Desktop or Claude Code**
2. Claude will automatically scan the `.claude/skills/` directories and load available agents
3. You can verify installation by running:
   ```bash
   claude doctor
   ```
   This should list your installed skills with a green checkmark.

## Usage

Once installed, Claude will:
- **Automatically detect** when an agent is relevant to your request based on the agent's description
- **Prompt you** to use the appropriate skill when applicable
- Some platforms support **direct invocation** via slash commands (e.g., `/agent-name`)

## Repository Structure

```
AgentsOfAction/
├── README.md
└── [agent-folders]/
    ├── SKILL.md          # Agent definition and instructions
    └── [supporting files]
```

Each agent is self-contained in its own folder with at minimum a `SKILL.md` file that defines:
- Agent name and description
- Usage instructions
- Any required dependencies or configurations

## Contributing

This is a personal collection, but feel free to:
- Fork this repository and create your own agent collections
- Suggest improvements via issues
- Share your own agents with the community

## Security Note

⚠️ **Important**: Only install agents from trusted sources. Agents can execute code and access your system, so review the contents before installation.

## License

This repository contains personal productivity agents. Use at your own discretion.

---

**Repository**: [asbassan/AgentsOfAction](https://github.com/asbassan/AgentsOfAction)  
**Maintained by**: @asbassan