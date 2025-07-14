# Fork Development Workflow

This document outlines the development workflow for maintaining this fork of VoiceInk with permanent customizations while staying up-to-date with upstream changes.

## Branch Structure

```
upstream-main    # Tracks upstream/main exactly (original repo)
cp-main          # Your customized main branch with permanent changes
feature-branches # Built from cp-main for new features
```

### Branch Purposes

- **`upstream-main`**: Pure tracking branch for the original repository
- **`cp-main`**: Your foundation branch WITH permanent modifications (license removal, etc.)
- **`feature/*`**: Temporary branches for developing new features

## Initial Setup (Already Done)

The repository is already configured with:
- `upstream` remote pointing to `git@github.com:Beingpax/VoiceInk.git`
- `origin` remote pointing to your fork
- Branch structure created and pushed

## Daily Development Workflow

### 1. Creating New Features

```bash
# Always branch from cp-main (your customized version)
git checkout cp-main
git pull origin cp-main
git checkout -b feature/my-new-feature

# Make your changes
# ... code, commit, test ...

# Push feature branch
git push origin feature/my-new-feature
```

### 2. Merging Features Back

```bash
# Switch to cp-main
git checkout cp-main

# Merge your feature
git merge feature/my-new-feature

# Push updated cp-main
git push origin cp-main

# Clean up feature branch
git branch -d feature/my-new-feature
git push origin --delete feature/my-new-feature
```

## Syncing with Upstream

### Weekly/Monthly Sync Process

```bash
# 1. Update upstream tracking branch
git checkout upstream-main
git pull upstream main
git push origin upstream-main

# 2. Rebase your customizations onto latest upstream
git checkout cp-main
git rebase upstream-main
```

### Handling Conflicts During Rebase

When rebasing `cp-main` onto `upstream-main`, you'll likely get conflicts around:
- License-related code
- Any other permanent modifications

**Resolution Strategy:**
1. **Keep your version** for permanent changes (license removal)
2. **Accept upstream changes** for bug fixes and new features
3. **Manually merge** when both need to coexist

```bash
# During rebase conflict resolution
git status                    # See conflicted files
# Edit files to resolve conflicts
git add .                     # Stage resolved files
git rebase --continue         # Continue rebase

# When rebase is complete
git push origin cp-main --force-with-lease
```

## Emergency Procedures

### If Rebase Goes Wrong

```bash
# Abort the rebase
git rebase --abort

# Alternative: merge instead of rebase
git merge upstream-main
# Resolve conflicts and commit the merge
git push origin cp-main
```

### If You Need to Start Over

```bash
# Reset cp-main to upstream and reapply your changes
git checkout cp-main
git reset --hard upstream-main
# Manually reapply your permanent changes
git commit -m "Reapply permanent customizations"
git push origin cp-main --force-with-lease
```

## Best Practices

### ✅ Do:
- Always branch from `cp-main` for new features
- Keep `upstream-main` as a pure tracking branch
- Rebase `cp-main` regularly to stay current
- Use descriptive branch names (`feature/`, `bugfix/`, etc.)
- Test thoroughly before merging to `cp-main`

### ❌ Don't:
- Commit directly to `upstream-main`
- Force push without `--force-with-lease`
- Let `cp-main` get too far behind upstream
- Merge upstream directly into feature branches

## Branch Protection

Consider these GitHub settings for your fork:
- Protect `cp-main` to require pull request reviews
- Protect `upstream-main` to prevent accidental commits
- Set up automated testing on pull requests

## Troubleshooting

### Common Issues:

**"Divergent branches" error:**
```bash
git config pull.rebase true
```

**Large conflicts during rebase:**
- Consider using `git merge` instead of `git rebase`
- Use `git mergetool` for complex conflicts

**Lost commits:**
```bash
git reflog                    # Find lost commits
git cherry-pick <commit-hash> # Recover specific commits
```

## Current Permanent Changes

Document your permanent modifications here:
- [ ] License removal/modification
- [ ] Custom build configurations
- [ ] Personalized features
- [ ] Other structural changes

---

*This workflow ensures you can maintain your customizations while benefiting from upstream improvements and bug fixes.*
