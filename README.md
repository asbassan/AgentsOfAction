# AgentsOfAction 🛡️

A curated collection of Claude agents/skills for day-to-day productivity and workflow automation.

## What is this?

AgentsOfShield is a personal repository containing custom Claude agents (also known as "skills") that extend Claude's capabilities for various tasks and workflows. Each agent is designed to help with specific use cases and can be easily installed into your Claude Desktop or Claude Code environment.

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
