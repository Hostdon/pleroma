### Release checklist
* [ ]  Bump version in `mix.exs`
* [ ]  Compile a changelog
* [ ]  Create an MR with an announcement to pleroma.social
* [ ]  Tag the release
* [ ] Merge `stable` into `develop` (in case the fixes are already in develop, use `git merge -s ours --no-commit` and manually merge the changelogs)
