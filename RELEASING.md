# Release Checklist

This project is not expected to publish releases at this early stage.
This checklist exists so the release process is defined early and to be used with tag milestones.

## Last Feature Before Tagging

- Finish the last feature or fix change.
- Verify the project builds.
- Verify the expected examples still work.
- Verify there are no uncommitted files with `git status`.
- Then commit the changes normally.

## Release Commit

- Update [CHANGELOG.md](CHANGELOG.md) to record the release before creating the tag.
- Change from `## [Unreleased]` to `## [v0.0.1] - YYYY-MM-DD`.
- Commit only this change with message `"Release v0.0.1"` and push it to main.

## Tag

- Create an annotated tag with a release message:

```powershell
git tag -a v0.0.1 -m "Release v0.0.1"
```

- Push the tag:

```powershell
git push origin v0.0.1
```
