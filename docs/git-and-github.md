# Git and GitHub

You sign in to GitHub with Google, so there is no GitHub password to type into git. The
workstation uses the **GitHub CLI** (`gh`) instead: you sign in once in the browser, and git asks
`gh` for access whenever it talks to `https://github.com`. You don't need an SSH key.

## Sign in once

```bash
github-login
```

1. It prints a one-time code (8 characters) and opens GitHub in Firefox. In the text console,
   open `https://github.com/login/device` on your phone instead.
2. Sign in the way you always do (**Continue with Google**), then enter the code and approve
   *GitHub CLI*.
3. Back in the terminal it sets up git and checks that it can reach your private repository.

If your commit name and e-mail aren't set yet, it sets them from your GitHub profile. The e-mail
is GitHub's private **noreply** address (`12345+you@users.noreply.github.com`), so your real
address doesn't end up in public commit history. Change them with:

```bash
git config --global user.name "Your Name"
```
```bash
git config --global user.email "you@example.com"
```

This sign-in is what `nullptr-update`, `nullptr-iso` and your own projects use. Sign out with
`gh auth logout`. An old clone that uses an SSH address (`git@github.com:…`) is switched to
`https://` by `nullptr-update` automatically.

## Put a project on GitHub

`new-c`, `new-raylib` and `new-gameboy` already ran `git init`. Commit your work, then:

```bash
gh repo create pong --private --source . --push
```

That creates `github.com/<you>/pong` (private), links it and uploads your commits. After that,
`git push` (or `P` in LazyGit) uploads new commits.

Get a project onto another computer:

```bash
gh repo clone <you>/pong ~/Projects/pong
```

Then use `projects adopt` inside it if it has no `.nullptr-project` file.

## Everyday git

| | Terminal | LazyGit (`Ctrl+b 3` or `Space g g`) |
|---|---|---|
| see what changed | `git status`, `git diff` | the *Files* panel |
| stage + commit | `git add -A && git commit -m "Add paddles"` | `Space` stages a file, `a` stages all, `c` commits |
| upload | `git push` | `P` |
| download | `git pull` | `p` |
| history | `git log --oneline` | the *Commits* panel |

Commit small and often ("Add ball movement", "Fix paddle collision"). Every commit is a point
you can go back to.

The project templates include a `.gitignore` that leaves out `build/`, so compiled files never
end up in the repository.
