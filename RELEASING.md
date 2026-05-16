# Release Checklist

This project is not expected to publish releases at this early stage.
This checklist exists so the release process is defined early and to be used with tag milestones.

## Before Tagging

- Verify the project builds.
- Verify the expected examples still work.
- Verify there are no uncommitted files with `git status`.
- Verify the last commits are the intended release sequence with `git log --oneline --decorate -n 10`.
- Update [CHANGELOG.md](CHANGELOG.md) to record the release before creating the tag.

## Tag

Create an annotated tag with a release message:

```powershell
git tag -a v0.0.1 -m "Release v0.0.1"
```

Push the branch and the tag:

```powershell
git push origin main
git push origin v0.0.1
```
