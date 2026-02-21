# Antigravity Quota Checker

A fast, lightweight, and dependency-free bash script to check your Google Antigravity AI quota and available models status. It queries the local Antigravity Language Server directly.

## Features

- **Blazing Fast**: Uses pure POSIX `awk` avoiding Python startup overhead.
- **Zero Configuration**: Automatically discovers the Language Server process, API port, and CSRF token.
- **Color-Coded Status**: Quickly visually identify low quota remaining thresholds (Green > 50%, Yellow > 25%, Red < 25%).
- **Timezone Aware**: Quota reset times are displayed locally relative to your host machine's timezone.
- **JSON Dump**: Easily dump the raw API response for debugging or downstream pipeline consumption.

## Usage

Make sure the script is executable, then run it:

```bash
chmod +x anti_quota.sh
./anti_quota.sh
```

### Alias Suggestion

You can make it even easier to run from anywhere by adding an alias to your `~/.bash_aliases` (or `~/.bashrc`):

```bash
alias aq='~/truburt/tools/anti_quota.sh'
```

Now you can simply type `aq` in your terminal to check your quota!

### Options

| Flag | Name | Description |
| ---- | ---- | ----------- |
| `-h` | `--help` | Show the help message and exit. |
| `-j` | `--json`, `--raw` | Dump raw JSON response instead of the formatted summary. Formats using `jq` or `python3` if available. |

### Antigravity AI Slash Command

You can use the built-in AI workflow by typing `/quota` inside the Antigravity chat to automatically run the script and check your quota.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
